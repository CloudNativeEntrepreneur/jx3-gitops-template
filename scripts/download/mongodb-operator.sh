#!/bin/bash

CHART_DIR=helmfiles/mongodb-operator/charts/mongodb-kubernetes-operator
OP_DIR=.tmp/mongodb-kubernetes-operator

mkdir -p ${CHART_DIR}/templates
git clone https://github.com/mongodb/mongodb-kubernetes-operator.git ${OP_DIR}
cp ${OP_DIR}/deploy/crds/mongodb.com_mongodb_crd.yaml ${CHART_DIR}/templates
cp ${OP_DIR}/deploy/operator/* ${CHART_DIR}/templates