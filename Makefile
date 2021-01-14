include versionStream/src/Makefile.mk

AWS_PROFILE?=
SECRET_DIR?=secret

encrypt-secrets:
	AWS_PROFILE=$(AWS_PROFILE) \
	SECRET_DIR=$(SECRET_DIR) \
	./scripts/secrets/encrypt.sh

decrypt-secrets:
	AWS_PROFILE=$(AWS_PROFILE) \
	SECRET_DIR=$(SECRET_DIR) \
	./scripts/secrets/decrypt.sh

sync-secrets:
	AWS_PROFILE=$(AWS_PROFILE) \
	SECRET_DIR=$(SECRET_DIR) \
	./scripts/secrets/sync.sh

download-olm:
	mkdir -p .tmp && cd .tmp && curl -L https://github.com/operator-framework/operator-lifecycle-manager/archive/v0.17.0.tar.gz | tar zx
	mv .tmp/operator-lifecycle-manager-0.17.0/deploy/chart/* helmfiles/olm/charts/olm

download-postgres-operator:
	git clone git@github.com:CrunchyData/postgres-operator.git .tmp/postgres-operator
	cd .tmp/postgres-operator && \
		pwd && \
		git fetch --all && \
		git checkout tags/v4.5.1
	cp -a .tmp/postgres-operator/installers/helm/. helmfiles/postgres-operator/charts/postgres-operator/

download-keycloak-operator:
	curl -L https://operatorhub.io/install/keycloak-operator.yaml > helmfiles/keycloak-operator/charts/keycloak-operator/templates/keycloak-operator.yaml

download-knative-operator:
	curl -L https://github.com/knative/operator/releases/download/v0.19.2/operator.yaml > helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml
	sed -i .bak 's/  namespace: default/  namespace: knative-operator/g' helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml
	rm helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml.bak

download-knative-serving:
	curl -L https://github.com/knative-sandbox/net-certmanager/releases/download/v0.19.0/release.yaml > helmfiles/knative-serving/charts/knative-serving/templates/knative-networking-certmanager.yaml

download-grafana-istio-dashboards:
	./scripts/grafana/find-istio-dashboards.sh

verify: dev-ns verify-ingress
	jx gitops webhook update --endpoint=https://$(kubectl get virtualservice hook -o json | jq -r ".spec.hosts[0]")/hook --warn-on-fail
