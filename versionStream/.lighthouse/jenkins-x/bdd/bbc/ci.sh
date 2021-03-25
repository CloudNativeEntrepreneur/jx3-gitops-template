#!/usr/bin/env bash
set -e
set -x

# BDD test specific part
export BDD_NAME="bbc"

export GIT_USERNAME="jenkins-x-bot-bitbucket"
export GH_OWNER="jenkins-x-bot-bitbucket"

export GH_HOST="https://bitbucket.org/"

export GIT_KIND="bitbucketcloud"
export GIT_SERVER_HOST="bitbucket.org"
export GIT_NAME="bbc"


export GIT_SERVER="https://${GIT_SERVER_HOST}"
export GIT_TOKEN="${GH_ACCESS_TOKEN}"

# the gitops repository template to use
export GITOPS_TEMPLATE_PROJECT="jx3-gitops-repositories/jx3-gke-gsm"

# enable the terraform gsm config
export TF_VAR_gsm=true

# scm changes
export JX_SCM="jx-scm"
echo "downloading the jx-scm binary to the PATH"

curl -L https://github.com/jenkins-x-plugins/jx-scm/releases/download/v0.0.24/jx-scm-linux-amd64.tar.gz | tar xzv
mv jx-scm /usr/local/bin

$JX_SCM repo help

export JX_TEST_COMMAND="jx test create -f /workspace/source/.lighthouse/jenkins-x/bdd/terraform-bbc.yaml.gotmpl --verify-result -e JX_SCM=jx-scm -e GIT_KIND=$GIT_KIND -e GIT_PROVIDER_URL=$GIT_SERVER -e GIT_ORGANISATION=$GH_OWNER"

`dirname "$0"`/../terraform-ci.sh

## cleanup secrets in google secrets manager if it was enabled
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"
export PROJECT_ID=jenkins-x-labs-bdd1
gcloud secrets list --project $PROJECT_ID --format='get(NAME)' --limit=unlimited --filter=$CLUSTER_NAME | xargs -I {arg} gcloud secrets delete  "{arg}" --quiet

