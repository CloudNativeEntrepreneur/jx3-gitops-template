#!/usr/bin/env bash
set -e

echo "****************************************"
echo "**                                    **"
echo "**           CI Job setup             **"
echo "**                                    **"
echo "****************************************"


echo PATH=$PATH
echo HOME=$HOME

export PATH=$PATH:/usr/local/bin

# generic stuff...

# setup environment
KUBECONFIG="/tmp/jxhome/config"

#export XDG_CONFIG_HOME="/builder/home/.config"
mkdir -p /builder/home
mkdir -p /home/.config
cp -r /home/.config /builder/home/.config

jx version

if [ -z "$GIT_USERNAME" ]
then
    export GIT_USERNAME="jenkins-x-bot-bdd"
fi

if [ -z "$GIT_SERVER_HOST" ]
then
    export GIT_SERVER_HOST="github.com"
fi

if [ -z "$GH_OWNER" ]
then
    export GH_OWNER="jenkins-x-bdd"
fi

export GIT_USER_EMAIL="jenkins-x@googlegroups.com"
export GIT_TOKEN="${GH_ACCESS_TOKEN//[[:space:]]}"
export GITHUB_TOKEN="${GH_ACCESS_TOKEN//[[:space:]]}"
export GIT_PROVIDER_URL="https://${GIT_SERVER_HOST}"


if [ -z "$GIT_TOKEN" ]
then
      echo "ERROR: no GIT_TOKEN env var defined for bdd/ci.sh"
else
      echo "has valid git token in bdd/ci.sh"
fi

# batch mode for terraform
export TERRAFORM_APPROVE="-auto-approve"
export TERRAFORM_INPUT="-input=false"
# ensure buckets are cleaned up for CI
export TF_VAR_force_destroy=true

export PROJECT_ID=jenkins-x-labs-bdd
export CREATED_TIME=$(date '+%a-%b-%d-%Ybin/ main.tf values.auto.tfvars terraform.tfstate variables.tf-%H-%M-%S')
export CLUSTER_NAME="${BRANCH_NAME,,}-$BUILD_NUMBER-$BDD_NAME"
export ZONE=europe-west1-c
export LABELS="branch=${BRANCH_NAME,,},cluster=$BDD_NAME,create-time=${CREATED_TIME,,}"

# lets setup git
git config --global --add user.name JenkinsXBot
git config --global --add user.email jenkins-x@googlegroups.com

echo "running the BDD test with JX_HOME = $JX_HOME"

mkdir -p $XDG_CONFIG_HOME/git
# replace the credentials file with a single user entry
echo "https://${GIT_USERNAME//[[:space:]]}:${GIT_TOKEN}@${GIT_SERVER_HOST}" > $XDG_CONFIG_HOME/git/credentials

echo "using git credentials: $XDG_CONFIG_HOME/git/credentials"
ls -al $XDG_CONFIG_HOME/git/credentials

echo "creating cluster $CLUSTER_NAME in project $PROJECT_ID with labels $LABELS"

echo "lets get the PR head clone URL"
export PR_SOURCE_URL=$(jx gitops pr get --git-token=$GIT_TOKEN --head-url)

echo "using the version stream url $PR_SOURCE_URL ref: $PULL_PULL_SHA"


# avoid cloning cluster repo into the working CI folder
export SOURCE_DIR=`pwd`
cd ..

# lets git clone the pipeline catalog so we can upgrade to the latest pipelines for the environment...
#git clone -b beta https://github.com/jstrachan/jx3-pipeline-catalog

echo "********************************************************"
echo "**                                                    **"
echo "**  create cluster git repo from template and update  **"
echo "**  version stream with contents of this pull request **"
echo "**                                                    **"
echo "********************************************************"



if [ -z "$GH_HOST" ]
then
      echo "no need to gh auth as using github.com"
else
      echo "echo lets auth with the git server $GIT_SERVER_HOST"
      gh auth login --hostname $GIT_SERVER_HOST --with-token $GH_ACCESS_TOKEN
fi


gh repo create ${GH_HOST}${GH_OWNER}/cluster-$CLUSTER_NAME-dev --template $GIT_PROVIDER_URL/${GITOPS_TEMPLATE_PROJECT} --private --confirm
sleep 15
gh repo clone ${GH_HOST}${GH_OWNER}/cluster-$CLUSTER_NAME-dev

pushd `pwd`/cluster-${CLUSTER_NAME}-dev

      git pull origin master
      # use the changes from this PR in the version stream for the cluster repo when resolving the helmfile
      rm -rf versionStream
      cp -R $SOURCE_DIR versionStream
      rm -rf versionStream/.git versionStream/.github
      git add versionStream/

      # lets add some testing charts....
      jx gitops helmfile add --chart jx3/jx-test-collector

      # lets upgrade any versions in helmfile.yaml
      jx gitops helmfile resolve --update

      # lets add a custom pipeline catalog for the test...
      #cp $SOURCE_DIR/.lighthouse/jenkins-x/bdd/pipeline-catalog.yaml extensions
      #cp -r $SOURCE_DIR/../jx3-pipeline-catalog/environment/.lighthouse .

      # lets add / commit any cloud resource specific changes
      git add * || true
      git commit -a -m "chore: cluster changes" || true
      git push
popd

echo "*****************************************************"
echo "**                                                 **"
echo "**  create infrastructure git repo from template,  **"
echo "**  clone and create cloud resources               **"
echo "**                                                 **"
echo "*****************************************************"

gh repo create ${GH_HOST}${GH_OWNER}/infra-$CLUSTER_NAME-dev --template $GIT_PROVIDER_URL/${GITOPS_INFRA_PROJECT} --private --confirm
sleep 5
gh repo clone ${GH_HOST}${GH_OWNER}/infra-$CLUSTER_NAME-dev

########
# setting up test resources and garbage collect previous runs
########
export GITOPS_REPO=https://${GIT_USERNAME//[[:space:]]}:${GIT_TOKEN}@${GIT_SERVER_HOST}/${GH_OWNER}/infra-${CLUSTER_NAME}-dev.git

# lets garbage collect any old tests or previous failed tests of this repo/PR/context...
echo "for cleaning up cloud resources"
jx test create --test-url $GITOPS_REPO

# create the cluster
pushd `pwd`/infra-${CLUSTER_NAME}-dev
      git pull origin master
      export GITOPS_DIR=`pwd`
      export GITOPS_BIN=$GITOPS_DIR/bin

      # lets configure the cluster
      source $GITOPS_BIN/configure.sh

      # lets create the cluster
      $GITOPS_BIN/create.sh

      # push state to git repo so we can destroy later
      # move to a bucket maybe? for now we need to -f to override the .gitignore which isn't good
      git add terraform.tfstate -f
      git commit -a -m "chore: terraform destroy details"
      git fetch origin
      git rebase origin/master
      git push

      $(terraform output -raw connect)

      $(terraform output -raw follow_install_logs)
popd

echo "*********************"
echo "**                 **"
echo "**  Run BDD tests  **"
echo "**                 **"
echo "*********************"

# # diagnostic commands to test the image's kubectl
# kubectl version

# # for some reason we need to use the full name once for the second command to work!
kubectl get environments
kubectl get env dev -oyaml
kubectl get cm config -oyaml

export JX_DISABLE_DELETE_APP="true"
export JX_DISABLE_DELETE_REPO="true"

# increase the timeout for complete PipelineActivity
export BDD_TIMEOUT_PIPELINE_ACTIVITY_COMPLETE="60"

# we don't yet update the PipelineActivity.spec.pullTitle on previews....
export BDD_DISABLE_PIPELINEACTIVITY_CHECK="true"

# define variables for the BDD tests
export GIT_ORGANISATION="$GH_OWNER"
export GH_USERNAME="$GIT_USERNAME"

# lets turn off color output
export TERM=dumb

echo "about to run the bdd tests...."

# run the BDD tests
if [ -z "$RUN_TEST" ]
then
      bddjx -ginkgo.focus=golang -test.v
else
      $RUN_TEST
fi

echo "completed the bdd tests"

echo "*******************•**"
echo "**                  **"
echo "**  Update jx test  **"
echo "**                  **"
echo "********************•*"

echo "switching context back to the infra cluster"

# lets connect back to the infra cluster so we can find the TestRun CRDs
gcloud container clusters get-credentials tf-jx-gentle-titmouse --zone us-central1-a --project jx-labs-infra

jx ns jx

echo "*****************************************************"
echo "**                                                 **"
echo "**  setting up test resources and garbage collect  **"
echo "**                                                 **"
echo "*****************************************************"

jx test delete --test-url $GITOPS_REPO --dir=$GITOPS_DIR --script=$GITOPS_BIN/destroy.sh
