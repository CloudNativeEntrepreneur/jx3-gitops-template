#!/usr/bin/env bash
set -e
set -x

echo "installing jx-bdd test chart"

helm install jx-bdd jx3/jx-bdd --set bdd.owner=jenkins-x-bdd


echo "now tailing the jx-bdd job logs"

kubectl logs -f job/jx-bdd
