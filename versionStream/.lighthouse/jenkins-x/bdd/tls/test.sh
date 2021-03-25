#!/usr/bin/env bash
set -e
set -x

echo PATH=$PATH
echo HOME=$HOME

export PATH=$PATH:/usr/local/bin

# verify that we have a stagin certificate from LetsEncrypt
kubectl get clusterissuer letsencrypt-staging -ojsonpath='{.status.conditions[0].status}'
kubectl get clusterissuer letsencrypt-staging -ojsonpath='{.status.conditions[0].message}'

jx verify tls hook-jx.$CLUSTER_NAME.jenkinsxlabs.com  --production=false --timeout 20m --issuer "(STAGING) Artificial Apricot R3"
