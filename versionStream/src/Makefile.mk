FETCH_DIR := build/base
TMP_TEMPLATE_DIR := build/tmp
OUTPUT_DIR := config-root
KUBEAPPLY ?= kubectl-apply
HELM_TMP_GENERATE ?= /tmp/generate
HELM_TMP_SECRETS ?= /tmp/secrets/jx-helm

# lets you define a post apply hook such as to run custom validation
POST_APPLY_HOOK ?=

# this target is only needed for development clusters
# for remote staging/production clusters try:
#
#     export COPY_SOURCE=no-copy-source
COPY_SOURCE ?= copy-source

# this target is only needed for development clusters
# for remote staging/production clusters try:
#
#     export GENERATE_SCHEDULER=no-gitops-scheduler
GENERATE_SCHEDULER ?= gitops-scheduler

# this target is only needed for development clusters
# for remote staging/production clusters try:
#
#     export REPOSITORY_RESOLVE=no-repository-resolve
REPOSITORY_RESOLVE ?= repository-resolve

# this target is only needed for development clusters
# for remote staging/production clusters try:
#
#     export GITOPS_WEBHOOK_UPDATE=no-gitops-webhook-update
GITOPS_WEBHOOK_UPDATE ?= gitops-webhook-update

# these values are only required for vault - you can ignore if you are using a cloud secret store
VAULT_ADDR ?= https://vault.jx-vault:8200
VAULT_NAMESPACE ?= jx-vault
VAULT_ROLE ?= jx-vault

GIT_SHA ?= $(shell git rev-parse HEAD)

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
	@rm -rf build $(OUTPUT_DIR) $(HELM_TMP_SECRETS) $(HELM_TMP_GENERATE)

.PHONY: setup
setup:

.PHONY: copy-source
copy-source:
	@cp -r versionStream/src/* build

.PHONY: no-copy-source
no-copy-source:
	@echo "disabled the copy source as we are not a development cluster"

.PHONY: init
init: setup
	@mkdir -p $(FETCH_DIR)
	@mkdir -p $(TMP_TEMPLATE_DIR)
	@mkdir -p $(OUTPUT_DIR)/namespaces/jx
	@mkdir -p $(FETCH_DIR)/cluster/crds



.PHONY: repository-resolve
repository-resolve:
# lets create any missing SourceRepository defined in .jx/gitops/source-config.yaml which are not in: versionStream/src/base/namespaces/jx/source-repositories
	jx gitops repository create

# lets configure the cluster gitops repository URL on the requirements if its missing
	jx gitops repository resolve --source-dir $(OUTPUT_DIR)/namespaces

# lets generate any jenkins job-values.yaml files to import projects into Jenkins
	jx gitops jenkins jobs


.PHONY: no-repository-resolve
no-repository-resolve:
	@echo "disabled the repository resolve as we are not a development cluster"

.PHONY: gitops-scheduler
gitops-scheduler:
# lets generate the lighthouse configuration as we are in a development cluster
	jx gitops scheduler

# lets force a rolling upgrade of lighthouse pods whenever we update the lighthouse config...
	jx gitops hash --pod-spec --kind Deployment -s config-root/namespaces/jx/lighthouse-config/config-cm.yaml -s config-root/namespaces/jx/lighthouse-config/plugins-cm.yaml -d config-root/namespaces/jx/lighthouse


.PHONY: no-gitops-scheduler
no-gitops-scheduler:
	@echo "disabled the lighthouse scheduler generation as we are not a development cluster"

.PHONY: fetch
fetch: init $(COPY_SOURCE) $(REPOSITORY_RESOLVE)
# set any missing defaults in the secrets mapping file
	jx secret convert edit

# lets resolve chart versions and values from the version stream
	jx gitops helmfile resolve

# lets make sure we are using the latest jx-cli in the git operator Job
	jx gitops image -s .jx/git-operator

# generate the yaml from the charts in helmfile.yaml and moves them to the right directory tree (cluster or namespaces/foo)
	helmfile --file helmfile.yaml template --validate --include-crds --output-dir-template /tmp/generate/{{.Release.Namespace}}/{{.Release.Name}}

	jx gitops split --dir /tmp/generate
	jx gitops rename --dir /tmp/generate
	jx gitops helmfile move --output-dir config-root --dir /tmp/generate --dir-includes-release-name

# convert k8s Secrets => ExternalSecret resources using secret mapping + schemas
# see: https://github.com/jenkins-x/jx-secret#mappings
	jx secret convert --source-dir $(OUTPUT_DIR) -r $(VAULT_ROLE)

# replicate secrets to local staging/production namespaces
	jx secret replicate --selector secret.jenkins-x.io/replica-source=true

# populate secrets from filesystem definitions
	-VAULT_ADDR=$(VAULT_ADDR) VAULT_NAMESPACE=$(VAULT_NAMESPACE) jx secret populate --source filesystem --secret-namespace $(VAULT_NAMESPACE)

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
post-build: $(GENERATE_SCHEDULER)

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

.PHONY: kustomize
kustomize: pre-build
	kustomize build ./build  -o $(OUTPUT_DIR)/namespaces

.PHONY: copy-resources
copy-resources: pre-build
	@cp -r ./build/base/* $(OUTPUT_DIR)
	@rm -rf $(OUTPUT_DIR)/kustomization.yaml

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
verify: dev-ns verify-ingress $(GITOPS_WEBHOOK_UPDATE)
	jx health status -A


.PHONY: gitops-webhook-update
gitops-webhook-update:
	jx gitops webhook update --warn-on-fail

.PHONY: no-gitops-webhook-update
no-gitops-webhook-update:
	@echo "disabled 'jx gitops webhook update' as we are not a development cluster"


.PHONY: dev-ns verify-ignore
verify-ignore: verify-ingress-ignore

.PHONY: secrets-populate
secrets-populate:
# lets populate any missing secrets we have a generator in `charts/repoName/chartName/secret-schema.yaml`
# they can be modified/regenerated at any time via `jx secret edit`
	-VAULT_ADDR=$(VAULT_ADDR) VAULT_NAMESPACE=$(VAULT_NAMESPACE) jx secret populate --secret-namespace $(VAULT_NAMESPACE)

.PHONY: secrets-wait
secrets-wait:
# lets wait for the ExternalSecrets service to populate the mandatory Secret resources
	VAULT_ADDR=$(VAULT_ADDR) jx secret wait -n jx

.PHONY: git-setup
git-setup:
	jx gitops git setup
	@git pull

.PHONY: regen-check
regen-check:
	jx gitops git setup
	jx gitops apply

.PHONY: regen-phase-1
regen-phase-1: git-setup resolve-metadata all $(KUBEAPPLY) verify-ingress-ignore commit

.PHONY: regen-phase-2
regen-phase-2: verify-ingress-ignore all verify-ignore commit

.PHONY: regen-phase-3
regen-phase-3: push secrets-wait

.PHONY: regen-none
regen-none:
# we just merged a PR so lets perform any extra checks after the merge but before the kubectl apply

.PHONY: apply
apply: regen-check $(KUBEAPPLY) secrets-populate verify annotate-resources apply-completed status

.PHONY: report
report:
# lets generate the markdown and yaml reports in the docs dir
	jx gitops helmfile report


.PHONY: status
status:

# lets update the deployment status to your git repository (e.g. https://github.com)
	jx gitops helmfile status

.PHONY: apply-completed
apply-completed: $(POST_APPLY_HOOK)
# copy any git operator secrets to the jx namespace
	jx secret copy --ns jx-git-operator --ignore-missing-to --to jx --selector git-operator.jenkins.io/kind=git-operator
	jx secret copy --ns jx-git-operator --ignore-missing-to --to tekton-pipelines --selector git-operator.jenkins.io/kind=git-operator

	@echo "completed the boot Job"

.PHONY: failed
failed: apply-completed
	@echo "boot Job failed"
	exit 1

.PHONY: kubectl-apply
kubectl-apply:
	@echo "using kubectl to apply resources"

# NOTE be very careful about these 2 labels as getting them wrong can remove stuff in you cluster!
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=customresourcedefinitions -R -f $(OUTPUT_DIR)/customresourcedefinitions
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=cluster                   -R -f $(OUTPUT_DIR)/cluster
	kubectl apply $(KUBECTL_APPLY_FLAGS) --prune -l=gitops.jenkins-x.io/pipeline=namespaces                -R -f $(OUTPUT_DIR)/namespaces

# lets apply any infrastructure specific labels or annotations to enable IAM roles on ServiceAccounts etc
	jx gitops postprocess

.PHONY: kapp-apply
kapp-apply:
	@echo "using kapp to apply resources"

	kapp deploy -a jx -f $(OUTPUT_DIR) -y

# lets apply any infrastructure specific labels or annotations to enable IAM roles on ServiceAccounts etc
	jx gitops postprocess

.PHONY: annotate-resources
annotate-resources:
	@echo "annotating some deployments with the latest git SHA: $(GIT_SHA)"
	jx gitops patch --selector git.jenkins-x.io/sha=annotate  --data '{"spec":{"template":{"metadata":{"annotations":{"git.jenkins-x.io/sha": "$(GIT_SHA)"}}}}}'

.PHONY: resolve-metadata
resolve-metadata:
# lets merge in any output from Terraform in the ConfigMap default/terraform-jx-requirements if it exists
	jx gitops requirements merge

# lets resolve any requirements
	jx gitops requirements resolve -n

.PHONY: commit
commit:
# lets make sure the git user name and email are setup for the commit to ensure we don't attribute this commit to random user
	jx gitops git setup
	-git add --all
# lets ignore commit errors in case there's no changes and to stop pipelines failing
	-git commit -m "chore: regenerated" -m "/pipeline cancel"

.PHONY: all
all: clean fetch report build lint


.PHONY: pr
pr:
	jx gitops apply --pull-request

.PHONY: pr-regen
pr-regen: all commit push-pr-branch

.PHONY: push-pr-branch
push-pr-branch:
# lets push changes to the Pull Request branch
# we need to force push due to rebasing of PRs after new commits merge to the main branch after the PR is created
	jx gitops pr push --ignore-no-pr --force

# now lets label the Pull Request so that lighthouse keeper can auto merge it
	jx gitops pr label --name updatebot --matches "env/.*" --ignore-no-pr

.PHONY: push
push:
	@git pull
	@git push -f

.PHONY: release
release: lint

.PHONY: dev-ns
dev-ns:
	@echo changing to the jx namespace to verify
	jx ns jx --quiet
