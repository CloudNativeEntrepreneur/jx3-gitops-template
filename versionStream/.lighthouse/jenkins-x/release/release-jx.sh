#!/usr/bin/env bash
set -e
set -x

export GH_OWNER="jenkins-x"
export GH_REPO="jx"
export JX_VERSION=$(sed "s:^.*jenkins-x\/jx.*\[\([0-9.]*\)\].*$:\1:;t;d" ./dependency-matrix/matrix.md)

if [[ $JX_VERSION =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
then
  jx step update release-status github --owner $GH_OWNER --repository $GH_REPO --version $JX_VERSION --prerelease=false
fi
