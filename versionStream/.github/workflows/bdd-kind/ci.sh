#!/usr/bin/env bash

set -o errexit

reg_name='kind-registry'
reg_port='5000'

NAME=${NAME:-"kind"}
DOCKER_NETWORK_NAME=${DOCKER_NETWORK_NAME:-"${reg_name}"}
KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-"${NAME}"}

# create registry container unless it already exists
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:${reg_port}"]
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

# connect the registry to the cluster network
# (the network may already be connected)
docker network connect "kind" "${reg_name}" || true

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

IP="127.0.0.1"

GIT_SCHEME="http"
GIT_HOST=${GIT_HOST:-"gitea.${IP}.nip.io"}
GIT_URL="${GIT_SCHEME}://${GIT_HOST}"


# write message to console and log
info() {
  prefix=""
  if [[ "${LOG_TIMESTAMPS}" == "true" ]]; then
    prefix="$(date '+%Y-%m-%d %H:%M:%S') "
  fi
  if [[ "${LOG}" == "file" ]]; then
    echo -e "${prefix}$@" >&3
    echo -e "${prefix}$@"
  else
    echo -e "${prefix}$@"
  fi
}

# write to console and store some information for error reporting
STEP=""
SUB_STEP=""
step() {
  STEP="$@"
  SUB_STEP=""
  info
  info "[$STEP]"
}
# store some additional information for error reporting
substep() {
  SUB_STEP="$@"
  info " - $SUB_STEP"
}

err() {
  if [[ "$STEP" == "" ]]; then
      echo "Failed running: ${BASH_COMMAND}"
      exit 1
  else
    if [[ "$SUB_STEP" != "" ]]; then
      echo "Failed at [$STEP / $SUB_STEP] running : ${BASH_COMMAND}"
      exit 1
    else
      echo "Failed at [$STEP] running : ${BASH_COMMAND}"
      exit 1
    fi
  fi
}


FILE_GITEA_VALUES_YAML=`cat <<EOF
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: nginx
  hosts:
    - ${GIT_HOST}
gitea:
  admin:
    password: ${GITEA_ADMIN_PASSWORD}
  config:
    database:
      DB_TYPE: sqlite3
      ## Note that the intit script checks to see if the IP & port of the database service is accessible, so make sure you set those to something that resolves as successful (since sqlite uses files on disk setting the port & ip won't affect the running of gitea).
      HOST: ${IP}:80 # point to the nginx ingress
    service:
      DISABLE_REGISTRATION: true
  database:
    builtIn:
      postgresql:
        enabled: false
image:
  version: 1.13.0
EOF
`

TOKEN=""
giteaCreateUserAndToken() {
  username=$1
  password=$2

  request=`echo "${FILE_USER_JSON}" \
    | yq e '.email="'${username}@example.com'"' - \
    | yq e '.full_name="'${username}'"' - \
    | yq e '.login_name="'${username}'"' - \
    | yq e '.username="'${username}'"' - \
    | yq e '.password="'${password}'"' -`

  substep "creating ${username} user"
  response=`echo "${request}" | curl -s -X POST "${GIT_URL}/api/v1/admin/users" "${CURL_GIT_ADMIN_AUTH[@]}" "${CURL_TYPE_JSON[@]}" --data @-`
  # info $request
  # info $response

  substep "updating ${username} user"
  response=`echo "${request}" | curl -s -X PATCH "${GIT_URL}/api/v1/admin/users/${username}" "${CURL_GIT_ADMIN_AUTH[@]}" "${CURL_TYPE_JSON[@]}" --data @-`
  # info $response

  substep "creating ${username} token"
  curlBasicAuth "${username}" "${password}"
  response=`curl -s -X POST "${GIT_URL}/api/v1/users/${username}/tokens" "${CURL_AUTH[@]}" "${CURL_TYPE_JSON[@]}" --data '{"name":"jx3"}'`
  # info $response
  token=`echo "${response}" | yq eval '.sha1' -`
  if [[ "$token" == "null" ]]; then
    info "Failed to create token for ${username}, json response: \n${response}"
    return 1
  fi
  TOKEN="${token}"
}

kind_bin="${DIR}/kind-${KIND_VERSION}"
installKind() {
  step "Installing kind ${KIND_VERSION}"
  if [ -x "${kind_bin}" ] ; then
    substep "kind already downloaded"
  else
    substep "downloading"
    curl -L -s "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-amd64" > ${kind_bin}
    chmod +x ${kind_bin}
  fi
  kind version
}

kind() {
  "${kind_bin}" "$@"
}

jx_bin="${DIR}/jx-${JX_VERSION}"
installJx() {
  step "Installing jx ${JX_VERSION}"
  if [ -x "${jx_bin}" ] ; then
    substep "jx already downloaded"
  else
    substep "downloading"
    curl -L -s "https://github.com/jenkins-x/jx-cli/releases/download/v${JX_VERSION}/jx-cli-linux-amd64.tar.gz" | tar -xzf - jx
    mv jx ${jx_bin}
    chmod +x ${jx_bin}
  fi
  jx version
}
jx() {
  "${jx_bin}" "$@"
}

helm_bin=`which helm || true`
installHelm() {
  step "Installing helm"
  if [ -x "${helm_bin}" ] ; then
    substep "helm in path"
  else
    substep "downloading"
    curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | "${helm_bin}"
    helm_bin=`which helm`
  fi
  helm version
}
helm() {
  "${helm_bin}" "$@"
}

yq_bin="${DIR}/yq-${YQ_VERSION}"
installYq() {
  step "Installing yq ${YQ_VERSION}"
  if [ -x "${yq_bin}" ] ; then
    substep "yq already downloaded"

  else
    substep "downloading"
    curl -L -s https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64 > "${yq_bin}"
    chmod +x "${yq_bin}"
  fi
  yq --version
}

yq() {
  "${yq_bin}" "$@"
}


kpt_bin="${DIR}/kpt-${KPT_VERSION}"
installKpt() {
  step "Installing kpt ${KPT_VERSION}"
  if [ -x "${kpt_bin}" ] ; then
    substep "kpt already downloaded"

  else
    substep "downloading"
    curl -L -s https://github.com/GoogleContainerTools/kpt/releases/download/v${KPT_VERSION}/kpt_linux_amd64-${KPT_VERSION}.tar.gz | tar -xzf - kpt
    mv kpt "${kpt_bin}"
    chmod +x "${kpt_bin}"
  fi
  kpt version
}

kpt() {
  "${kpt_bin}" "$@"
}



help() {
  # TODO
  info "run 'jx3-kind.sh create' or 'jx3-kind.sh destroy'"
}

destroy() {

  if [[ -f "${LOG_FILE}" ]]; then
    rm "${LOG_FILE}"
  fi
  if [[ -d node-http ]]; then
    rm -rf ./node-http
  fi
  rm -f .*.token || true

  kind delete cluster --name="${KIND_CLUSTER_NAME}"
  docker network rm "${DOCKER_NETWORK_NAME}"

}

configureHelm() {
  step "Configuring helm chart repositories"

  substep "ingress-nginx"
  helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

  substep "gitea-charts"
  helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add gitea-charts https://dl.gitea.io/charts/

  if [ "${PRE_INSTALL_SECRET_INFRA}" == "true" ]; then
    substep "banzaicloud-stable"
    helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add banzaicloud-stable https://kubernetes-charts.banzaicloud.com

    substep "jx3"
    helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add jx3 https://storage.googleapis.com/jenkinsxio/charts

    substep "external-secrets"
    helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add external-secrets https://external-secrets.github.io/kubernetes-external-secrets
  fi

  substep "helm repo update"
  helm --kube-context "kind-${KIND_CLUSTER_NAME}"  repo update
}

installNginxIngress() {

  step "Installing nginx ingress"

  kubectl --context "kind-${KIND_CLUSTER_NAME}" create namespace nginx

  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/provider/kind/deploy.yaml

  #echo "${FILE_NGINX_VALUES}" | helm --kube-context "kind-${KIND_CLUSTER_NAME}"  install nginx --namespace nginx --values - ingress-nginx/ingress-nginx

  sleep 10

  substep "Waiting for nginx to start"

  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=100m

#  kubectl wait --namespace nginx \
#    --for=condition=ready pod \
#    --selector=app.kubernetes.io/name=ingress-nginx \
#    --timeout=10m
}


installGitea() {
  step "Installing Gitea"

  kubectl --context "kind-${KIND_CLUSTER_NAME}" create namespace gitea

  helm --kube-context "kind-${KIND_CLUSTER_NAME}" repo add gitea-charts https://dl.gitea.io/charts/

  echo "${FILE_GITEA_VALUES_YAML}" | helm --kube-context "kind-${KIND_CLUSTER_NAME}" install --namespace gitea -f - gitea gitea-charts/gitea

  substep "Waiting for Gitea to start"


  kubectl wait --namespace gitea \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=gitea \
    --timeout=100m

  # Verify that gitea is serving
  for i in {1..20}; do
    http_code=`curl -LI -o /dev/null -w '%{http_code}' -s "${GIT_URL}/api/v1/admin/users" "${CURL_GIT_ADMIN_AUTH[@]}"`
    if [[ "${http_code}" = "200" ]]; then
      break
    fi
    sleep 1
  done

  if [[ "${http_code}" != "200" ]]; then
    info "Gitea didn't startup"
    return 1
  fi

  info "Gitea is up at ${GIT_URL}"
  info "Login with username: gitea_admin password: ${GITEA_ADMIN_PASSWORD}"
}

configureGiteaOrgAndUsers() {

  step "Setting up gitea organisation and users"

  giteaCreateUserAndToken "${BOT_USER}" "${BOT_PASS}"
  botToken="${TOKEN}"
  echo "${botToken}" > "${DIR}/.${KIND_CLUSTER_NAME}-bot.token"

  giteaCreateUserAndToken "${DEVELOPER_USER}" "${DEVELOPER_PASS}"
  developerToken="${TOKEN}"
  echo "${developerToken}" > "${DIR}/.${KIND_CLUSTER_NAME}-developer.token"
  substep "creating ${ORG} organisation"

  curlTokenAuth "${developerToken}"
  json=`curl -s -X POST "${GIT_URL}/api/v1/orgs" "${CURL_AUTH[@]}" "${CURL_TYPE_JSON[@]}" --data '{"repo_admin_change_team_access": true, "username": "'${ORG}'", "visibility": "private"}'`
  # info "${json}"

  substep "add ${BOT_USER} an owner of ${ORG} organisation"

  substep "find owners team for ${ORG}"
  curlTokenAuth "${developerToken}"
  json=`curl -s "${GIT_URL}/api/v1/orgs/${ORG}/teams/search?q=owners" "${CURL_AUTH[@]}" "${CURL_TYPE_JSON[@]}"`
  id=`echo "${json}" | yq eval '.data[0].id' -`
  if [[ "${id}" == "null" ]]; then
    info "Unable to find owners team, json response :\n${json}"
    return 1
  fi

  substep "add ${BOT_USER} as member of owners team (#${id}) for ${ORG}"
  curlTokenAuth "${developerToken}"
  response=`curl -s -X PUT "${GIT_URL}/api/v1/teams/${id}/members/${BOT_USER}" "${CURL_AUTH[@]}" "${CURL_TYPE_JSON[@]}"`

}

loadGitUserTokens() {
  botToken=`cat ".${KIND_CLUSTER_NAME}-bot.token"`
  developerToken=`cat ".${KIND_CLUSTER_NAME}-developer.token"`
}




waitFor() {
  timeout="$1"; shift
  label="$1"; shift
  command="$1"; shift
  args=("$@")

  substep "Waiting for: ${label}"
  while :
  do
    "${command}" "${args[@]}" 2>&1 >/dev/null && RC=$? || RC=$?
    if [[ $RC -eq 0 ]]; then
      return 0
    fi
    sleep 5
  done
  info "Gave up waiting for: ${label}"
  return 1
}

getUrlBodyContains() {
  url=$1; shift
  expectedText=$1; shift
  curl -s "${url}" | grep "${expectedText}" > /dev/null
}


# resetGitea() {
#   #
#   #
#   # DANGER : THIS WILL REMOVE ALL GITEA DATA
#   #
#   #
#   step "Resetting Gitea"
#   substep "Clar gitea data folder which includes the sqlite database and repositories"
#   kubectl --context "kind-${KIND_CLUSTER_NAME}" -n gitea exec gitea-0 -- rm -rf "/data/*"


#   substep "Restart gitea pod"
#   kubectl --context "kind-${KIND_CLUSTER_NAME}" -n gitea delete pod gitea-0
#   sleep 5
#   expectPodsReadyByLabel gitea app.kubernetes.io/name=gitea

# }


create() {
  installKind
  installYq
  installHelm
  installJx
  installKubectl
  installKpt
  createKindCluster
  configureHelm
  installNginxIngress
  installGitea
  if [ "${PRE_INSTALL_SECRET_INFRA}" == "true" ]; then
    installSecretInfra
  fi
  configureGiteaOrgAndUsers
}

function_exists() {
  declare -f -F $1 > /dev/null
  return $?
}


installNginxIngress
installGitea
configureGiteaOrgAndUsers


