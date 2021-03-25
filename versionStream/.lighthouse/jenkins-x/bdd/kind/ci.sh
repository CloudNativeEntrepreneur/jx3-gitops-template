#!/usr/bin/env bash
set -e
set -x

pwd

if [ -z "$GH_ACCESS_TOKEN" ]
then
      echo "ERROR: no GH_ACCESS_TOKEN env var defined for kind/ci.sh"
else
      echo "has valid git token for kind/ci.sh"
fi

export WORKING_DIR=/home/runner/work/jx3-versions


export JX_KUBERNETES="true"

export NO_JX_TEST="true"
export KIND_VERSION=0.9.0

export JX_VERSION=$(grep 'version: ' packages/jx-cli.yml | awk '{ print $2}')

echo "using working dir: ${WORKING_DIR}"
echo "using jx version:  ${JX_VERSION}"

mkdir $HOME/bin
export PATH=$PATH:$HOME/bin

# setup git credential store
export XDG_CONFIG_HOME=/home/.config
git config credential.helper store

# use a sub dir for downloading to avoid clashing with the jx dir etc
mkdir downloads
cd downloads

curl -L https://github.com/jenkins-x/jx-cli/releases/download/v${JX_VERSION}/jx-cli-linux-amd64.tar.gz | tar xzv
sudo mv jx /usr/local/bin

curl -L https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64 > kind
chmod +x kind
sudo mv kind /usr/local/bin/kind

cd ..

echo "now testing the binaries..."
jx version
kind version

# TODO replace this some day with using a container image?
# download all the plugins
export JX3_HOME=/home/.jx
export JX_HOME=/home/.jx
sudo mkdir -p $JX3_HOME
jx upgrade plugins --boot --path /usr/bin

# BDD test specific part
export BDD_NAME="bdd-kind"

# lets default env vars that don't get populated if not running in jx
export BRANCH_NAME="${BRANCH_NAME:-pr-${GITHUB_RUN_ID}-${GITHUB_RUN_NUMBER}}"
export BUILD_NUMBER="${GITHUB_RUN_NUMBER}"

# the gitops repository template to use
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-kind-vault"

mkdir -p /builder/home

export RUN_TEST=".lighthouse/jenkins-x/bdd/kind/test.sh"

.lighthouse/jenkins-x/bdd/ci.sh