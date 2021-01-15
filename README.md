# jx3-gitops-template

Jenkins X 3.x GitOps repository for a Kubernetes cluster with all the things you'll need preconfigured.

This is a work in progress... There are still some pending features:

1. Istio/Keycloak integration for SSO
  * Dev Realm
  * Dev tooling auth'd via Keycloak Dev Realm
1. Postgres instance to back Keycloak
1. SQL backups for Keycloak DB
1. Keycloak Backup
1. Velero/Velero Backups
1. Strimzi Kafka Operator
1. Strimzi Kafka cluster to back knative-eventing

** After forking, do a global search for "example.com" - making these variables is another todo :)

# What this template comes with

## helmfiles/auth

Keycloak operator for creating Keycloak and configuring Keycloak instances, and a Keycloak instance configured with a postgres-operator backed DB. Exposed via Istio.

## helmfiles/cert-manager

Automatically provision TLS certificates from LetsEncrypt.

## helmfiles/istio-operator

The istio operator chart installs the Istio operator, which allows you to configure Istio declaratively

## helmfiles/istio-system

Istio configuration and Certificates that will be used by Istio (most likely all of them, except those managed by Knative Serving)

## helmfiles/jx

JX3 with custom values for istio integration

## helmfiles/knative-eventing

Configure Knative Eventing via the Knative operator

## helmfiles/knative-operator

Install and configure the Knative operator

## helmfiles/knative-serving

Configure Knative Serving via the Knative operator

## helmfiles/monitor

Install and configure Prometheus Stack for monitoring/alerting, and Loki for Centralized Logging, and Grafana as a dashboard.

## helmfiles/olm

Install OLM which is used to install the Keycloak Operator. If there were a good chart for Keycloak operator I probably wouldn't use this, but it's the recommended way.

## helmfiles/postgres-operator

Installs the Postgres Operator which allows you to declaratively create Postgres instances.

## helmfiles/rbac-manager

CRDs for declaratively controlling RBAC for your cluster.

## helmfiles/secret-infra

Vault to store secrets, Kubernetes External Secrets to use them, and Pusher Wave for secret rotation.

## tekton-pipelines

Tekton, which JX uses to run pipelines.

# Secrets

## Decrypt Existing Secrets

```
make decrypt-secrets
```

To Decrypt only a subset of secrets, use `SECRET_DIR`

```
SECRET_DIR=secret-encrypted/monitor make decrypt-secrets
```

## Encrypt Existing Secrets

```
make encrypt-secrets
```

To Encrypt only a subset of secrets, use `SECRET_DIR`

```
SECRET_DIR=secret/monitor make encrypt-secrets
```


## Sync Existing Secrets

```
make sync-secrets
```

To Sync only a subset of secrets, use `SECRET_DIR`

```
SECRET_DIR=secret/monitor make sync-secrets
```

TODO: In a future version syncing will be done in the pipeline automatically

## Connecting to Vault

From https://jenkins-x.io/v3/admin/guides/secrets/vault/

In a terminal, run:

```bash
jx secret vault portforward
```

Then, in a second terminal

```bash
export VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys  -n secret-infra -o jsonpath={.data.vault-root} | base64 --decode)

# Tell the CLI that the Vault Cert is signed by a custom CA
kubectl get secret vault-tls -n secret-infra -o jsonpath="{.data.ca\.crt}" | base64 --decode > $PWD/secret/vault/vault-ca.crt
export VAULT_CACERT=$PWD/secret/vault/vault-ca.crt

# Tell the CLI where Vault is listening (the certificate has 127.0.0.1 as well as alternate names)
export VAULT_ADDR=https://127.0.0.1:8200
```

You can now use the Vault CLI or Safe:

Vault CLI:

```bash
# Now we can use the vault CLI to list/read/write secrets...
                                           
# List all the current secrets
vault kv list secret

# Lets store a secert
vault kv put secret/mything foo=bar whatnot=cheese
```

Safe:

```bash
safe ls
safe ls secret

safe get secret/jx/adminUser:password
```
