#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="gke-tls"
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"

# the gitops repository template to use
# TODO add proper repos back after testing
export GITOPS_INFRA_PROJECT="jx3-gitops-repositories/jx3-terraform-gke"
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-gsm"

export JX_TEST_COMMAND="jx test create -f /workspace/source/.lighthouse/jenkins-x/bdd/terraform-tls.yaml.gotmpl"

# enable the terraform gsm config
export TF_VAR_gsm=true
export TF_VAR_apex_domain=jenkinsxlabs.com
export TF_VAR_subdomain=$CLUSTER_NAME
export TF_VAR_lets_encrypt_production=false
export TF_VAR_tls_email=jenkins-x-admin@googlegroups.com

export RUN_TEST="`dirname "$0"`/test.sh"


`dirname "$0"`/../terraform-ci.sh

## cleanup secrets in google secrets manager if it was enabled
export PROJECT_ID=jenkins-x-labs-bdd1
gcloud secrets list --project $PROJECT_ID --format='get(NAME)' --limit=unlimited --filter=$CLUSTER_NAME | xargs -I {arg} gcloud secrets delete  "{arg}" --quiet