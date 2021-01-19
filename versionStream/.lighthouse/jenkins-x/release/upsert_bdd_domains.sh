#!/usr/bin/env bash

BDD_PROJECT="jenkins-x-bdd3"
PARENT_PROJECT="jenkins-x-rocks"
PREFIXES=("boot1" "boot2" "boot3" "boot4" "boot5" "boot6" "boot7" "boot8" "boot9" "boot10" "boot11" "boot12" 
    "boot13" "boot14" "boot15" "boot16" "boot17" "boot18" "boot19" "boot20" "boot21" "boot22" "boot23" "boot24")
SUBDOMAIN="bdd.jenkins-x.rocks"

function does_subdomain_exist()
{
  local domain=$1
  gcloud dns managed-zones --project=$BDD_PROJECT list --filter=$domain --format=json | jq length
}

function get_domain_nameservers()
{
  local domain=$1
  local project=$2
  gcloud dns managed-zones --project=$project list --filter=$domain --format=json | jq .[].nameServers
}

function create_subdomain()
{
  local domain=$1
  gcloud dns managed-zones --project=$BDD_PROJECT create "${domain//\./-}" --dns-name "${domain}." --description="managed-zone for bdd tests"
}

for prefix in "${PREFIXES[@]}"
do
  domain="${prefix}.${SUBDOMAIN}"
  exists=$(does_subdomain_exist "${domain}")

  if [[ $exists -eq 0 ]]
  then
    create_subdomain "${domain}"
    echo "$domain created"
    child_nameservers="$(get_domain_nameservers "${domain}" "${BDD_PROJECT}")"
    echo "${child_nameservers}"
  else
    echo "$domain exists"
    child_nameservers="$(get_domain_nameservers "${domain}" "${BDD_PROJECT}")"
    echo "${child_nameservers}"
  fi
done

