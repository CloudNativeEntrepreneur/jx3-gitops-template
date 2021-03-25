#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="eks-vault"

# the gitops repository template to use
export GITOPS_INFRA_PROJECT="jx3-gitops-repositories/jx3-terraform-eks"
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-eks-vault"

export TF_VAR_region="us-east-1"
export TERRAFORM_FILE="terraform-eks.yaml.gotmpl"

`dirname "$0"`/../terraform-ci.sh
