# jx3-gitops-template

Jenkins X 3.x GitOps repository for a Kubernetes cluster with all the things you'll need preconfigured.

This is a work in progress... There are still some pending features:

1. Keycloak instance
1. Istio/Keycloak integration for SSO
1. Postgres instance to back Keycloak
1. SQL backups
1. Velero Backups
1. Strimzi Kafka Operator
1. Strimzi Kafka cluster to back knative-eventing

** After forking, do a global search for "example.com" - making these variables is another todo :)

# What this template comes with

## helmfiles/cert-manager

Automatically provision TLS certificates from LetsEncrypt.

## helmfiles/istio-operator

The istio operator chart installs the istio operator, which allows you to configure Istio declarivitely

## helmfiles/istio-system

Istio configuration and Certificates that will be used by istio (most likely all of them, except those managed by Knative Serving)

## helmfiles/jx

JX3 with custom values for istio integration

## helmfiles/keycloak-operator

An operator for creating Keycloak and configuring Keycloak instances - this allows you to do things like declaratively create new clients with Preview environments 

## helmfiles/knative-eventing

Configure Knative Eventing via the Knative operator

## helmfiles/knative-operator

Install and configure the knative operator

## helmfiles/knative-serving

Configure Knative Serving via the Knative operator

## helmfiles/monitor

Install and configure Prometheus Stack for monitoring/alerting, and Loki for Centralized Logging, and Grafana as a dashboard.

## helmfiles/olm

Install OLM which is used to install the Keycloak Operator. If there were a good chart for keycloak operator I probably wouldn't use this, but it's the recommended way.

## helmfiles/postgres-operator

Installs the Postgres Operator which allows you to declaritively create postgres instances.

## helmfiles/rbac-manager

CRDs for declaratively controlling RBAC for your cluster.

## helmfiles/secret-infra

Vault to store secrets, Kubernetes External Secrets to use them, and Pusher Wave for secret rotation.

## tekton-pipelines

Tekton, which JX uses to run pipelines.