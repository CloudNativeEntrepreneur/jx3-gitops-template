#!/usr/bin/env bash
set -e
set -x

export OVERLAY="$SOURCE_DIR/.lighthouse/jenkins-x/bdd/gsm-kapp/job-overlay.yaml"

echo "applying the kapp overlay at $OVERLAY"

mkdir -p .jx/git-operator
cp $OVERLAY .jx/git-operator

echo "now has overlay files at .jx/git-operator"
ls -al .jx/git-operator

git add .jx/git-operator/*.yaml
