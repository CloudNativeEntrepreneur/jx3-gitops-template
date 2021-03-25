#!/usr/bin/env bash
set -e

# BDD test specific part
export BDD_NAME="bdd-gitea"

# the gitops repository template to use
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-kubernetes"

export TERRAFORM_FILE="terraform-gitea.yaml.gotmpl"

export PROJECT_ID=jenkins-x-labs-bdd1
export TF_VAR_project_id=$PROJECT_ID

export PATH=$PATH:/usr/local/bin

# setup environment
KUBECONFIG="/tmp/jxhome/config"

#export XDG_CONFIG_HOME="/builder/home/.config"
mkdir -p /builder/home
mkdir -p /home/.config
cp -r /home/.config /builder/home/.config

jx version

# batch mode for terraform
export TERRAFORM_APPROVE="-auto-approve"
export TERRAFORM_INPUT="-input=false"
# ensure buckets are cleaned up for CI
export TF_VAR_force_destroy=true

export PROJECT_ID=jenkins-x-labs-bdd1
export CREATED_TIME=$(date '+%a-%b-%d-%Ybin/ main.tf values.auto.tfvars terraform.tfstate variables.tf-%H-%M-%S')
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"
export ZONE=europe-west1-c
export LABELS="branch=${BRANCH_NAME,,},cluster=$BDD_NAME,create-time=${CREATED_TIME,,}"

# lets setup git
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD test with JX_HOME = $JX_HOME"

echo "testing terraform with: $JX_TEST_COMMAND"

export TF_VAR_gcp_project=$PROJECT_ID
export TF_VAR_cluster_name=$CLUSTER_NAME

jx test create -f /workspace/source/.lighthouse/jenkins-x/bdd/terraform-gitea.yaml.gotmpl --verify-result