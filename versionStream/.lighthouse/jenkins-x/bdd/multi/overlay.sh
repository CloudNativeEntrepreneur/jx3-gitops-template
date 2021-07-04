#!/usr/bin/env bash
set -e
set -x


export PROD_CLUSTER_NAME=cluster-${CLUSTER_NAME%-dev}-prod-dev

echo "importing the remote production repository for cluster ${PROD_CLUSTER_NAME}"

yq e '.spec.environments[1].namespace = "myapps"' -i jx-requirements.yml
yq e '.spec.environments[1].owner = "jenkins-x-bdd"' -i jx-requirements.yml
yq e '.spec.environments[1].promotionStrategy = "Auto"' -i jx-requirements.yml
yq e '.spec.environments[1].remoteCluster = true' -i jx-requirements.yml
yq e ".spec.environments[1].repository = \"$PROD_CLUSTER_NAME\"" -i jx-requirements.yml
#yq e '.spec.environments[2].promotionStrategy = "Never"' -i jx-requirements.yml

