#!/bin/bash

set -x
set -e

echo "recreating the version streams in the https://github.com/jx3-gitops-repositories repositories"


declare -a xrepos=(
  # GKE
  "jx3-gke-gsm" "jx3-gke-vault" "jx3-gke-gcloud-vault"
  # EKS
  "jx3-eks-terraform-vault"
  # local
  "jx3-kind-vault" "jx3-minikube-vault" "jx3-docker-vault"
)

declare -a repos=(
  "jx3-docker-vault"
)

export TMPDIR=/tmp/jx3-gitops-promote
rm -rf $TMPDIR
mkdir -p $TMPDIR


for r in "${repos[@]}"
do
  echo "recreating version stream in repository https://github.com/jx3-gitops-repositories/$r"

  cd $TMPDIR
  git clone https://github.com/jx3-gitops-repositories/$r.git
  cd "$r"

  rm -rf .jx/git-operator .lighthouse/jenkins-x src versionStream

  kpt pkg get https://github.com/jenkins-x/jx3-pipeline-catalog.git/.lighthouse/jenkins-x .lighthouse/jenkins-x
  kpt pkg get https://github.com/jenkins-x/jxr-versions.git/ versionStream
  git add * .lighthouse || true
  git commit -a -m "chore: upgrade version stream" || true
  git push || true
done

