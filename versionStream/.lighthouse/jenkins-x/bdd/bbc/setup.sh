#!/usr/bin/env bash
set -e
set -x


echo "creating jx namespace"

kubectl create namespace jx

export REGISTRY_URL="ghcr.io"
export REGISTRY_USER="jenkins-x-bot-bdd"

echo "creating secret for registry $REGISTRY_URL and user $REGISTRY_USER"

kubectl create secret generic container-registry-auth --namespace jx --from-literal=url=$REGISTRY_URL --from-literal=username=$REGISTRY_USER --from-literal=password=$REGISTRY_TOKEN

echo "setup the kubernetes cluster custom secrets"