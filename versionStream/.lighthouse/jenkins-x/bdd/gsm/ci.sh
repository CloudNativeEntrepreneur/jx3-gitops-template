#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="gke-gsm"

# the gitops repository template to use
export GITOPS_INFRA_PROJECT="jx3-gitops-repositories/jx3-terraform-gke"
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-gsm"

# enable the terraform gsm config
export TF_VAR_gsm=true

`dirname "$0"`/../terraform-ci.sh

## cleanup secrets in google secrets manager if it was enabled
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"
export PROJECT_ID=jenkins-x-labs-bdd
gcloud secrets list --project $PROJECT_ID --format='get(NAME)' --limit=unlimited --filter=$CLUSTER_NAME | xargs -I {arg} gcloud secrets delete  "{arg}" --quiet