#!/usr/bin/env bash
set -e
set -x

# setup environment
KUBECONFIG="/tmp/jxhome/config"

export XDG_CONFIG_HOME="/builder/home/.config"
mkdir -p $XDG_CONFIG_HOME/git

jx --version

export GH_USERNAME="jenkins-x-labs-bot"
export GH_EMAIL="jenkins-x@googlegroups.com"
export GH_USERNAME="jenkins-x-labs-bot"
export GH_EMAIL="jenkins-x@googlegroups.com"
export GH_OWNER="jenkins-x-bdd"

export CREATED_TIME=$(date '+%a-%b-%d-%Y-%H-%M-%S')
export PROJECT_ID=jenkins-x-labs-bdd1
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-bdd-mc"
export ZONE=europe-west1-c
export LABELS="branch=${BRANCH_NAME,,},cluster=bdd-mc,create-time=${CREATED_TIME,,}"

# lets setup git
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD tests with JX_HOME = $JX_HOME"

# replace the credentials file with a single user entry
echo "https://${GH_USERNAME//[[:space:]]}:${GH_ACCESS_TOKEN//[[:space:]]}@github.com" > $XDG_CONFIG_HOME/git/credentials

echo "using git credentials: $XDG_CONFIG_HOME/git/credentials"
ls -al $XDG_CONFIG_HOME/git/credentials

echo "creating cluster $CLUSTER_NAME in project $PROJECT_ID with labels $LABELS"

# lets find the current cloud resources version
export CLOUD_RESOURCES_VERSION=$(grep  'version: ' /workspace/source/git/github.com/jenkins-x-labs/cloud-resources.yml | awk '{ print $2}')
echo "found cloud-resources version $CLOUD_RESOURCES_VERSION"

git clone -b v${CLOUD_RESOURCES_VERSION} https://github.com/jenkins-x-labs/cloud-resources.git
cloud-resources/gcloud/create_cluster.sh

# TODO remove once we remove the code from the multicluster branch of jx:
export JX_SECRETS_YAML=/tmp/secrets.yaml

echo "using the version stream ref: $PULL_PULL_SHA"

# create the boot git repository
jxl boot create -b --env dev --env-remote --provider=gke --version-stream-ref=$PULL_PULL_SHA --env-git-owner=$GH_OWNER --project=$PROJECT_ID --cluster=$CLUSTER_NAME --zone=$ZONE

# import secrets...
echo "secrets:
  adminUser:
    username: admin
    password: $JENKINS_PASSWORD
  hmacToken: $GH_ACCESS_TOKEN
  pipelineUser:
    username: $GH_USERNAME
    token: $GH_ACCESS_TOKEN
    email: $GH_EMAIL" > /tmp/secrets.yaml

jxl boot secrets import -f /tmp/secrets.yaml --git-url https://github.com/${GH_OWNER}/environment-${CLUSTER_NAME}-dev.git

jxl boot run -b --job


# now lets create the staging cluster
export DEV_CLUSTER_NAME="$CLUSTER_NAME"
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-mc-staging"
export STAGING_CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-mc-staging"
export STAGING_GIT_URL="https://github.com/${GH_OWNER}/environment-${DEV_CLUSTER_NAME}-staging.git"
export NAMESPACE=jx-staging

echo "CREATE: staging cluster $CLUSTER_NAME with namespace $NAMESPACE with labels $LABELS"

cloud-resources/gcloud/create_cluster.sh



mkdir staging
cd staging

echo "SWITCH: to staging cluster: $STAGING_CLUSTER_NAME to setup staging"
gcloud container clusters get-credentials $STAGING_CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
jx ns jx-staging
jx ctx -b

jxl boot verify requirements -b --version-stream-ref=$PULL_PULL_SHA --env-git-owner=$GH_OWNER --project=$PROJECT_ID --cluster=$CLUSTER_NAME --zone=$ZONE --git-url=$STAGING_GIT_URL

# TODO should not be needed but just in case
jx ns jx-staging

jxl boot secrets import -f /tmp/secrets.yaml --git-url=$STAGING_GIT_URL

# TODO should not be needed but just in case
jx ns jx-staging

jxl boot run -b --job


echo "SWITCH: to dev cluster: $STAGING_CLUSTER_NAME to start BDD tests"
gcloud container clusters get-credentials $DEV_CLUSTER_NAME --zone $ZONE --project $PROJECT_ID
jx ns jx
jx ctx -b

# for some reason we need to use the full name once for the second command to work!
kubectl get environments

# TODO not sure we need this?

helm repo add jenkins-x https://storage.googleapis.com/chartmuseum.jenkins-x.io


export JX_DISABLE_DELETE_APP="true"

# run the BDD tests
bddjx -ginkgo.focus=golang -test.v

echo cleaning up cloud resources
curl https://raw.githubusercontent.com/jenkins-x-labs/cloud-resources/v$CLOUD_RESOURCES_VERSION/gcloud/cleanup-cloud-resurces.sh | bash
gcloud container clusters delete $CLUSTER_NAME --zone $ZONE --quiet