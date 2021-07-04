# jx3-gitops-template

Jenkins X 3.x GitOps repository for a Kubernetes cluster with all the things you'll need preconfigured, and probably some you don't.

Meant to be a reference - start with an official jx3-gitops-repo, then come here and grab the extra helmfiles you need!

This is a work in progress... There are still some pending features:

1. SQL backups for Keycloak DB
1. Keycloak Backup CRD
1. Strimzi Kafka Operator
1. Strimzi Kafka cluster to back knative-eventing

** After forking, do a global search for "example.com" - making these variables is another todo :)

## Creating/upgrading cloud resources

Modify the `jx-requirements.yml` file

Now git commit and push any changes...

```bash 
git add *
git commit -a -m "chore: Jenkins X changes"
```

## System Components

### helmfiles/auth

An operator for creating Keycloak and configuring Keycloak instances - this allows you to do things like declaratively create new clients with Preview environments.

Oauth2Proxy for use with Istio EnvoyFilters and Keycloak

Redis session store

### helmfiles/cert-manager

Automatically provision TLS certificates from LetsEncrypt.

### helmfiles/istio-operator

The istio operator chart installs the istio operator, which allows you to configure Istio declarivitely

### helmfiles/istio-system

Istio configuration and Certificates that will be used by istio (most likely all of them, except those managed by Knative Serving)

### helmfiles/jx

JX3 with custom values for istio integration

### helmfiles/knative-eventing

Configure Knative Eventing via the Knative operator

### helmfiles/knative-operator

Install and configure the knative operator

### helmfiles/knative-serving

Configure Knative Serving via the Knative operator

### helmfiles/monitor

Install and configure Prometheus Stack for monitoring/alerting, and Loki for Centralized Logging, and Grafana as a dashboard.

### helmfiles/olm

Install OLM which is used to install the Keycloak Operator. If there were a good chart for keycloak operator I probably wouldn't use this, but it's the recommended way.

### helmfiles/postgres-operator

Installs the Postgres Operator which allows you to declaritively create postgres instances.

### helmfiles/rbac-manager

CRDs for declaratively controlling RBAC for your cluster.

### helmfiles/secret-infra

Kubernetes External Secrets, and Pusher Wave for secret rotation.

## tekton-pipelines

Tekton, which JX uses to run pipelines.
