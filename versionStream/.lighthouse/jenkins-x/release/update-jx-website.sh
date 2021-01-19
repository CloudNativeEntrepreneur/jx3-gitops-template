#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if $(cat ${IS_JX_PRERELEASE})
then
  JX_VERSION=$(sed "s:^.*jenkins-x\/jx.*\[\([0-9.]*\)\].*$:\1:;t;d" ./dependency-matrix/matrix.md)
  LOCAL_BRANCH_NAME="jx_cli_$VERSION"
  if [[ $JX_VERSION =~ ^[0-9]*\.[0-9]*\.[0-9]*$ ]]
  then
    echo "updating the CLI reference"

    pushd $(mktemp -d)
      git clone https://github.com/jenkins-x/jx-docs.git

      pushd jx-docs
        git checkout -b $LOCAL_BRANCH_NAME
      popd

      pushd jx-docs/content/en/docs/reference/commands
        # Cleanup the commands directory before generating new docs to avoid keeping the 
        # deprecated commands of which doc is not anymore generated.
        # lets preserve the index file
        mv _index.md _index.md.backup
        rm -rf *.md
        mv _index.md.backup _index.md
        jx create docs
        git config credential.helper store
        git add *
        git commit --allow-empty -a -m "updated jx commands & API docs from $JX_VERSION"
        
        # Note that when doing a rebase theirs and ours are swapped so -X theirs actually automatically accepts our changes in case of conflict
        git fetch origin && git rebase -X theirs origin/master
      popd

      echo "Updating the JSON Schema"
      pushd jx-docs/static
        mkdir -p schemas
        cd schemas
        jx step syntax schema -o jx-schema.json
        jx step syntax schema --requirements -o jx-requirements.json
        git add *
        git commit --allow-empty -a -m "updated jx Json Schema from $JX_VERSION"
        
        # Note that when doing a rebase theirs and ours are swapped so -X theirs actually automatically accepts our changes in case of conflict
        git fetch origin && git rebase -X theirs origin/master
      popd

      echo "Updating the JX CLI & API reference docs"

      mkdir -p ${GOPATH}/src/github.com/jenkins-x
      pushd ${GOPATH}/src/github.com/jenkins-x
        git clone https://github.com/jenkins-x/jx.git
        pushd jx
          git fetch --tags
          git checkout v${JX_VERSION}
          # make generate-refdocs needs go modules enabled. The long term solution is probably to turn it on in jx's makefile, but for the moment...
          GO111MODULE=on make generate-refdocs
        popd
      popd
      cp ${GOPATH}/src/github.com/jenkins-x/jx/docs/apidocs.md jx-docs/content/en/docs/reference/api.md
      cp ${GOPATH}/src/github.com/jenkins-x/jx/docs/config.md jx-docs/content/en/docs/reference/config

      MESSAGE="chore: updated jx API docs from $JX_VERSION"

      pushd jx-docs/content/en/docs/reference
        git add *
        git commit --allow-empty -a -m "$MESSAGE"

        # Note that when doing a rebase theirs and ours are swapped so -X theirs actually automatically accepts our changes in case of conflict
        git fetch origin && git rebase -X theirs origin/master
      popd

      pushd jx-docs
        git push origin $LOCAL_BRANCH_NAME
        jx create pullrequest -t "$MESSAGE" -l updatebot
      popd
    popd
  fi
fi
