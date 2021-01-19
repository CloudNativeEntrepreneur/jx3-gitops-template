#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail


echo "rebasing master of the fork in jenkins-x-labs-bot/jxr-versions"

git clone https://github.com/jenkins-x-labs-bot/jxr-versions.git jenkins-x-labs-bot-versions
cd jenkins-x-labs-bot-versions
git remote add upstream https://github.com/jenkins-x/jxr-versions.git
git pull -r upstream master
git push origin master

echo "done rebasing the jenkins-x-labs-bot fork"