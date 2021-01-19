#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="gke-vault"

# the gitops repository template to use
export GITOPS_INFRA_PROJECT="jx3-gitops-repositories/jx3-terraform-gke"
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-vault"

`dirname "$0"`/../terraform-ci.sh