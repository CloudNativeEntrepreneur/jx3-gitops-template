#!/bin/sh
if [ -x "$(command -v safe)" ]; then
    echo "Safe is installed... continuing..."
else
    echo "safe must be installed: https://github.com/starkandwayne/safe"
    exit 1
fi

VAULT_TOKEN=$(kubectl get secrets vault-unseal-keys  -n jx-vault -o jsonpath={.data.vault-root} | base64 --decode)
VAULT_CACERT=$PWD/secret/vault/vault-ca.crt
VAULT_ADDR=https://127.0.0.1:8200

if [[ -z "$SECRET_DIR" ]]; then
    SECRET_DIR=secret
fi

echo "Syncing directory: ${SECRET_DIR}"

for envFile in $(find ${SECRET_DIR} -type f -name "*.env")
do
  # same path without .env
  vaultpath=${envFile//\.env/}
  echo "Syncing $vaultpath"

  # reduce lines into a string separated by " "
  envVars=""
  IFS=$'\n'       # make newlines the only separator
  set -f          # disable globbing
  for line in $(cat < "$envFile"); do
    envVars="$envVars\"$line\" "
  done

  # echo "Running \"safe set $vaultpath ${envVars}\"\n"
  eval "safe set $vaultpath ${envVars}"
done

for yamlFile in $(find ${SECRET_DIR} -type f -name "*.yaml")
do
  # same path without .env
  vaultpath=`dirname $yamlFile`
  filename=`basename $yamlFile`
  echo "Syncing $vaultpath"

  # echo "Running \"safe set $vaultpath $filename@/$yamlFile\"\n"
  eval "safe set ${vaultpath} ${filename}@${yamlFile}"
done

for jsonFile in $(find ${SECRET_DIR} -type f -name "*.json")
do
  # same path without .env
  vaultpath=`dirname $jsonFile`
  filename=`basename $jsonFile`
  echo "Syncing $vaultpath"

  # echo "Running \"safe set $vaultpath $filename@/$jsonFile\"\n"
  eval "safe set ${vaultpath} ${filename}@${jsonFile}"
done