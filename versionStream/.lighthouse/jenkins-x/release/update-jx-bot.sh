#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if $(cat ${IS_JX_PRERELEASE})
then
  JX_VERSION=$(sed "s:^.*jenkins-x\/jx.*\[\([0-9.]*\)\].*$:\1:;t;d" ./dependency-matrix/matrix.md)

  if [[ $JX_VERSION =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
  then
    CHECKSUMS="https://github.com/jenkins-x/jx/releases/download/v${JX_VERSION}/jx-checksums.txt"
    SHA256=$(curl -Ls ${CHECKSUMS} | grep 'darwin' | cut -d' ' -f1)
    if [ ! -z $SHA256 ]
    then
      jx step create pr brew --version $JX_VERSION --sha $SHA256 --repo https://github.com/jenkins-x/homebrew-jx.git --src-repo https://github.com/jenkins-x/jx.git
    fi
    jx step create pr docker --name JX_VERSION --version $JX_VERSION --repo https://github.com/jenkins-x/dev-env-base.git
    jx step create pr regex --regex "\s*release = \"(.*)\"" --version $JX_VERSION --files config.toml --repo https://github.com/jenkins-x/jx-docs.git
    jx step create pr regex --regex "JX_VERSION=(.*)" --version $JX_VERSION --files install-jx.sh --repo https://github.com/jenkins-x/jx-tutorial.git
  fi
fi

