#!/bin/bash

if [[ -z "$SECRET_DIR" ]]; then
    SECRET_DIR=secret
fi

mkdir -p secret
mkdir -p secret-encrypted

for f in $(find $SECRET_DIR -type f)
do
  dest=$(echo $f |  sed -e 's/secret/secret-encrypted/g')
  echo "Encrypting $f to $dest"

  dir=$(dirname -- "$dest")
  mkdir -p $dir  

  sops --encrypt $f > $dest
done
