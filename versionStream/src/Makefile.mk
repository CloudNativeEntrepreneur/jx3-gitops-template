FETCH_DIR := build/base
TMP_TEMPLATE_DIR := build/tmp
OUTPUT_DIR := config-root
KUBEAPPLY ?= kubectl-apply
VAULT_ADDR ?= https://vault.secret-infra:8200

# You can disable force mode on kubectl apply by modifying this line:
KUBECTL_APPLY_FLAGS ?= --force

SOURCE_DIR ?= /workspace/source


# NOTE to enable debug logging of 'helmfile template' to diagnose any issues with values.yaml templating
# you can run:
#
#     export HELMFILE_TEMPLATE_FLAGS="--debug"
#
# or change the next line to:
# HELMFILE_TEMPLATE_FLAGS ?= --debug
HELMFILE_TEMPLATE_FLAGS ?=

.PHONY: clean
clean:
	rm -rf build $(OUTPUT_DIR)

.PHONY: setup
setup:
	# lets create any missing SourceRepository defined in .jx/gitops/source-config.yaml which are not in: versionStream/src/base/namespaces/jx/source-repositories
	jx gitops repository create

.PHONY: init
init: setup
	mkdir -p $(FETCH_DIR)
	mkdir -p $(TMP_TEMPLATE_DIR)
	mkdir -p $(OUTPUT_DIR)/namespaces/jx
	cp -r versionStream/src/* build
	mkdir -p $(FETCH_DIR)/cluster/crds


.PHONY: fetch
fetch: init
	# lets configure the cluster gitops repository URL on the requirements if its missing
	jx gitops repository resolve --source-dir $(OUTPUT_DIR)/namespaces

	# lets generate any jenkins job-values.yaml files to import projects into Jenkins
	jx gitops jenkins jobs

	# set any missing defaults in the secrets mapping file
	jx secret convert edit

	# lets resolve chart versions and values from the version stream
	jx gitops helmfile resolve

	# lets make sure we are using the latest jx-cli in the git operator Job
	jx gitops image -s .jx/git-operator

	# this line avoids the next helmfile command failing...
	helm repo add jx http://chartmuseum.jenkins-x.io

	# generate the yaml from the charts in helmfile.yaml and moves them to the right directory tree (cluster or namespaces/foo)
	helmfile --file helmfile.yaml template --include-crds --output-dir-template /tmp/generate/{{.Release.Namespace}}/{{.Release.Name}}

	jx gitops split --dir /tmp/generate
	jx gitops rename --dir /tmp/generate
	jx gitops helmfile move --output-dir config-root --dir /tmp/generate --dir-includes-release-name

	# convert k8s Secrets => ExternalSecret resources using secret mapping + schemas
	# see: https://github.com/jenkins-x/jx-secret#mappings
	jx secret convert --source-dir $(OUTPUT_DIR)

	# replicate secrets to local staging/production namespaces
	jx secret replicate --selector secret.jenkins-x.io/replica-source=true

	# lets make sure all the namespaces exist for environments of the replicated secrets
	jx gitops namespace --dir-mode --dir $(OUTPUT_DIR)/namespaces

.PHONY: build
# uncomment this line to enable kustomize
#build: build-kustomise
build: build-nokustomise

.PHONY: build-kustomise
build-kustomise: kustomize post-build

.PHONY: build-nokustomise
build-nokustomise: copy-resources post-build


.PHONY: pre-build
pre-build:

.PHONY: post-build
post-build:
	# lets generate the lighthouse configuration
	jx gitops scheduler

	# lets add the kubectl-apply prune annotations
	#
	# NOTE be very careful about these 3 labels as getting them wrong can remove stuff in you cluster!
	jx gitops label --dir $(OUTPUT_DIR)/cluster                   gitops.jenkins-x.io/pipeline=cluster
	jx gitops label --dir $(OUTPUT_DIR)/customresourcedefinitions gitops.jenkins-x.io/pipeline=customresourcedefinitions
	jx gitops label --dir $(OUTPUT_DIR)/namespaces                gitops.jenkins-x.io/pipeline=namespaces

	# lets add kapp friendly change group identifiers to nginx-ingress and pusher-wave so we can write rules against them
	jx gitops annotate --dir $(OUTPUT_DIR) --selector app=pusher-wave kapp.k14s.io/change-group=apps.jenkins-x.io/pusher-wave
	jx gitops annotate --dir $(OUTPUT_DIR) --selector app.kubernetes.io/name=ingress-nginx kapp.k14s.io/change-group=apps.jenkins-x.io/ingress-nginx

	# lets label all Namespace resources with the main namespace which creates them and contains the Environment resources
	jx gitops label --dir $(OUTPUT_DIR)/cluster --kind=Namespace team=jx

	# lets enable pusher-wave to perform rolling updates of any Deployment when its underlying Secrets get modified
	# by modifying the underlying secret store (e.g. vault / GSM / ASM) which then causes External Secrets to modify the k8s Secrets
	jx gitops annotate --dir  $(OUTPUT_DIR)/namespaces --kind Deployment --selector app=pusher-wave --invert-selector wave.pusher.com/update-on-config-change=true

	# lets force a rolling upgrade of lighthouse pods whenever we update the lighthouse config...
	jx gitops hash -s config-root/namespaces/jx/lighthouse-config/config-cm.yaml -s config-root/namespaces/jx/lighthouse-config/plugins-cm.yaml -d config-root/namespaces/jx/lighthouse

.PHONY: kustomize
kustomize: pre-build
	kustomize build ./build  -o $(OUTPUT_DIR)/namespaces

.PHONY: copy-resources
copy-resources: pre-build
	cp -r ./build/base/* $(OUTPUT_DIR)
	rm $(OUTPUT_DIR)/kustomization.yaml

.PHONY: lint
lint:

.PHONY: dev-ns verify-ingress
verify-ingress:
	jx verify ingress --ingress-service ingress-nginx-controller

.PHONY: dev-ns verify-ingress-ignore
verify-ingress-ignore:
	-jx verify ingress --ingress-service ingress-nginx-controller

.PHONY: dev-ns verify-install
verify-install:
	# TODO lets disable errors for now
	# as some pods stick around even though they are failed causing errors
	-jx verify install --pod-wait-time=2m

.PHONY: verify
verify: dev-ns verify-ingress
	jx gitops webhook update --warn-on-fail

.PHONY: dev-ns verify-ignore
verify-ignore: verify-ingress-ignore

.PHONY: secrets-populate
secrets-populate:
	# lets populate any missing secrets we have a generator in `charts/repoName/chartName/secret-schema.yaml`
	# they can be modified/regenerated at any time via `jx secret edit`
	-VAULT_ADDR=$(VAULT_ADDR) jx secret populate

.PHONY: secrets-wait
secrets-wait:
	# lets wait for the ExternalSecrets service to populate the mandatory Secret resources
	VAULT_ADDR=$(VAULT_ADDR) jx secret wait -n jx

.PHONY: git-setup
git-setup:
	jx gitops git setup
	git pull

.PHONY: regen-check
regen-check:
	jx gitops git setup
	jx gitops apply

.PHONY: regen-phase-1
regen-phase-1: git-setup resolve-metadata all $(KUBEAPPLY) verify-ingress-ignore commit

.PHONY: regen-phase-2
regen-phase-2: verify-ingress-ignore all verify-ignore secrets-populate report commit

.PHONY: regen-phase-3
regen-phase-3: push secrets-wait

.PHONY: regen-none
regen-none:
	# we just merged a PR so lets perform any extra checks after the merge but before the kubectl apply

.PHONY: apply
apply: regen-check kubectl-apply secrets-populate verify write-completed
	
.PHONY: report
report:
	jx gitops helmfile report

.PHONY: write-completed
write-completed:
	echo completed > jx-boot-completed.txt
	echo wrote completed file

.PHONY: failed
failed: write-completed
	exit 1

.PHONY: kubectl-apply
kubectl-apply:
	# NOTE be very careful about these 2 labels as getting them wrong can remove stuff in you cluster!
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=customresourcedefinitions -R -f $(OUTPUT_DIR)/customresourcedefinitions
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=cluster                   -R -f $(OUTPUT_DIR)/cluster
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=namespaces                -R -f $(OUTPUT_DIR)/namespaces

	# lets apply any infrastructure specific labels or annotations to enable IAM roles on ServiceAccounts etc
	jx gitops postprocess

.PHONY: kapp-apply
kapp-apply:

	kapp deploy -a jx -f $(OUTPUT_DIR) -y

	# lets apply any infrastructure specific labels or annotations to enable IAM roles on ServiceAccounts etc
	jx gitops postprocess

.PHONY: resolve-metadata
resolve-metadata:
	# lets merge in any output from Terraform in the ConfigMap default/terraform-jx-requirements if it exists
	jx gitops requirements merge

	# lets resolve any requirements
	jx gitops requirements resolve -n

.PHONY: commit
commit:
	-git add --all
	-git status
	# lets ignore commit errors in case there's no changes and to stop pipelines failing
	-git commit -m "chore: regenerated" -m "/pipeline cancel"

.PHONY: all
all: clean fetch build lint


.PHONY: pr
pr:
	jx gitops apply --pull-request

.PHONY: pr-regen
pr-regen: all commit push-pr-branch

.PHONY: push-pr-branch
push-pr-branch:
	# lets push changes to the Pull Request branch
	jx gitops pr push --ignore-no-pr

	# now lets label the Pull Request so that lighthouse keeper can auto merge it
	jx gitops pr label --name updatebot --matches "env/.*" --ignore-no-pr

.PHONY: push
push:
	git pull
	git push -f

.PHONY: release
release: lint

.PHONY: dev-ns
dev-ns:
	@echo changing to the jx namespace to verify
	jx ns jx --quiet
