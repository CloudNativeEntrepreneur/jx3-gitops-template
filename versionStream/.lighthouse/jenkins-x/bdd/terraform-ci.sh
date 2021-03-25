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

if [ -z "$JX_SCM" ]
then
    export JX_SCM="gh"
fi

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

if [ -z "$GIT_PROVIDER_URL" ]
then
    export GIT_PROVIDER_URL="https://${GIT_SERVER_HOST}"
fi

if [ -z "$GIT_TEMPLATE_SERVER_URLL" ]
then
    export GIT_TEMPLATE_SERVER_URL="https://github.com"
fi

if [ -z "$GIT_SERVER" ]
then
    export GIT_SERVER="https://github.com"
fi

if [ -z "$GIT_KIND" ]
then
    export GIT_KIND="github"
fi

if [ -z "$GIT_NAME" ]
then
    export GIT_NAME="github"
fi



export GIT_USER_EMAIL="jenkins-x@googlegroups.com"
export GIT_TOKEN="${GH_ACCESS_TOKEN//[[:space:]]}"
export GITHUB_TOKEN="${GH_ACCESS_TOKEN//[[:space:]]}"



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

export PROJECT_ID=jenkins-x-labs-bdd1
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
      echo "not using gh auth for now"
      #echo "echo lets auth with the git server $GIT_SERVER_HOST"
      #gh auth login --hostname $GIT_SERVER_HOST --with-token $GH_ACCESS_TOKEN
fi

if [ -z "$GH_CLONE_HOST" ]
then
      export GH_CLONE_HOST=${GH_HOST}
fi


$JX_SCM repo create ${GH_HOST}${GH_OWNER}/cluster-$CLUSTER_NAME-dev --template $GIT_TEMPLATE_SERVER_URL/${GITOPS_TEMPLATE_PROJECT} --private --confirm
sleep 15
$JX_SCM repo clone ${GH_CLONE_HOST}${GH_OWNER}/cluster-$CLUSTER_NAME-dev

pushd `pwd`/cluster-${CLUSTER_NAME}-dev

      git pull origin master
      # use the changes from this PR in the version stream for the cluster repo when resolving the helmfile
      rm -rf versionStream
      cp -R $SOURCE_DIR versionStream
      rm -rf versionStream/.git versionStream/.github
      git add versionStream/

      # lets remove the old files...
      rm -rf .jx/git-operator/filename.txt

      # lets add some testing charts....
      jx gitops helmfile add --chart jx3/jx-test-collector

      # configure the git server
      jx gitops requirements edit --git-server $GIT_SERVER --git-kind $GIT_KIND --git-name $GIT_NAME

      # lets upgrade any versions in helmfile.yaml
      jx gitops helmfile resolve --update

      # any git repo overrides...
      if [ -z "$JX_GIT_OVERRIDES" ]
      then
          export JX_GIT_OVERRIDES="echo no git overrides"
      else
          echo "invoking: ${SOURCE_DIR}/${JX_GIT_OVERRIDES}"
          ${SOURCE_DIR}/${JX_GIT_OVERRIDES}
      fi

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


if [ -z "$GITOPS_INFRA_PROJECT" ]
then
      echo "no custom gitops infra repository to be created for this test"
else
      $JX_SCM repo create ${GH_HOST}${GH_OWNER}/infra-$CLUSTER_NAME-dev --template $GIT_TEMPLATE_SERVER_URL/${GITOPS_INFRA_PROJECT} --private --confirm
      sleep 15
fi

if [ -z "$TERRAFORM_FILE" ]
then
    export TERRAFORM_FILE="terraform.yaml.gotmpl"
fi

if [ -z "$JX_TEST_COMMAND" ]
then
  export JX_TEST_COMMAND="jx test create -f /workspace/source/.lighthouse/jenkins-x/bdd/$TERRAFORM_FILE --verify-result"
fi

echo "testing terraform with: $JX_TEST_COMMAND"

export TF_VAR_gcp_project=$PROJECT_ID
export TF_VAR_cluster_name=$CLUSTER_NAME

$JX_TEST_COMMAND
