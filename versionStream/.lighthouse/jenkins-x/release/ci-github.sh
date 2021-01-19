#!/usr/bin/env bash
set -e
set -x

export GH_USERNAME="jenkins-x-versions-bot-test"
export GH_OWNER="jenkins-x-bdd"

# fix broken `BUILD_NUMBER` env var
export BUILD_NUMBER="$BUILD_ID"

JX_HOME="/tmp/jxhome"
KUBECONFIG="/tmp/jxhome/config"

mkdir -p $JX_HOME

jx --version
jx step git credentials

gcloud auth activate-service-account --key-file $GKE_SA

# lets setup git 
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD tests with JX_HOME = $JX_HOME"

# TODO replace with a simple step instead
echo "lets copy over the local jenkins-x-versions repo for now"
mkdir -p ~/.jx
pushd ~/.jx
git clone https://github.com/jenkins-x/jenkins-x-versions.git
popd
cp -r * ~/.jx/jenkins-x-versions

jx step bdd --dir . --config jx/bdd/staticjenkins.yaml --gopath /tmp --git-provider=github --git-username $GH_USERNAME --git-owner $GH_OWNER --git-api-token $GH_ACCESS_TOKEN --default-admin-password $JENKINS_PASSWORD --no-delete-app --no-delete-repo --tests install --tests test-create-spring
