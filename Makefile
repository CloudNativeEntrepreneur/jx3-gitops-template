include versionStream/src/Makefile.mk

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
	curl -L https://github.com/knative/operator/releases/download/v0.23.0/operator.yaml > helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml
	sed -i .bak 's/  namespace: default/  namespace: knative-operator/g' helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml
	rm helmfiles/knative-operator/charts/knative-operator/templates/knative-operator.yaml.bak

download-knative-serving:
	curl -L https://github.com/knative-sandbox/net-certmanager/releases/download/v0.23.0/release.yaml > helmfiles/knative-serving/charts/knative-serving/templates/knative-networking-certmanager.yaml
	curl -L https://github.com/knative/serving/releases/download/v0.23.0/serving-nscert.yaml > helmfiles/knative-serving/charts/knative-serving/templates/serving-nscert.yaml
	echo "Make sure to check the diff of config-certmanager in knative-networking-certmanager.yaml - the clusterIssuer ref needs to stay"

# if using istio webhook can not be found automatically, provide the url here instead
gitops-webhook-update:
	jx gitops webhook update --endpoint=https://$(kubectl get virtualservice hook -o json | jq -r ".spec.hosts[0]")/hook --warn-on-fail
