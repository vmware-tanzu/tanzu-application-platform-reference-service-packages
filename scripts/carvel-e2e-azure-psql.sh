#!/usr/bin/env bash

set -euo pipefail

INSTALL_TIMEOUT="20m"

SCRIPT_FOLDER=$(basename $0 .sh)

export NAME="${NAME:-$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | sha1sum | head -c 20)}"
export PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
APP_NAME=${APP_NAME:-${NAME}}
export ASO_CONTROLLER_NAMESPACE="azureserviceoperator-system"

[ -z "${PACKAGE_METADATA_NAME:-}" ] && echo "Environment variable PACKAGE_METADATA_NAME is not defined" && exit 1
[ -z "${PACKAGE_VERSION:-}" ] && echo "Environment variable PACKAGE_VERSION is not defined" && exit 1

while true; do
  case "${1:-}" in
    --skip-aso-install)
      SKIP_ASO_INSTALL=1 ; shift ;;
    *)
      break ;;
  esac
done

pushd $(dirname $0)

if [ -z ${SKIP_ASO_INSTALL:-} ]; then
  # install ASO and dependencies
  ./carvel-azure-install-aso.sh
fi

echo ">> Prepare package values"

LOCATION="${LOCATION:-westeurope}"

JOBNAME="get-public-ip-${NAME}"
kubectl create job ${JOBNAME} --image curlimages/curl -- curl -sSf https://api.ipify.org
kubectl wait --for=condition=Complete=True job ${JOBNAME}
PUBLIC_IP="$(kubectl logs jobs/${JOBNAME})"
kubectl delete job ${JOBNAME}

VALUES=$(mktemp)
cat <<EOF >$VALUES
---
name: ${NAME}
namespace: ${PACKAGE_NAMESPACE}
location: ${LOCATION}
aso_controller_namespace: ${ASO_CONTROLLER_NAMESPACE}
create_namespace: false

server:
  administrator_name: testadmin

database:
  name: testdb

firewall_rules:
  - startIpAddress: 0.0.0.0
    endIpAddress: 0.0.0.0
  - startIpAddress: ${PUBLIC_IP}
    endIpAddress: ${PUBLIC_IP}

resource_group:
  use_existing: false
  name: carvel-test-${NAME}
EOF
trap "rm ${VALUES}" EXIT

# install package
kubectl create namespace ${PACKAGE_NAMESPACE} || true

SA=${PACKAGE_METADATA_NAME}
export INSTALL_NAME=${PACKAGE_METADATA_NAME}

echo ">> Prepare RBAC"
ytt -f ./${SCRIPT_FOLDER}/rbac.ytt.yml -v serviceAccount=${SA} -v namespace=${PACKAGE_NAMESPACE} | kubectl apply -f -

echo ">> Install package"
kctrl package install -n ${PACKAGE_NAMESPACE} -i ${INSTALL_NAME} -p ${PACKAGE_METADATA_NAME} --version ${PACKAGE_VERSION} --values-file ${VALUES} --service-account-name ${SA} --wait=false

timeout --foreground -s TERM $INSTALL_TIMEOUT bash -c '
INIT_TIMEOUT_SECONDS=${TIMEOUT:-60}
MAX_TIMEOUT_SECONDS=${TIMEOUT:-300}
TIMEOUT_SECONDS=${INIT_TIMEOUT_SECONDS}
while true; do
  echo ">> Waiting for stack ${NAME} to reconcile for ${TIMEOUT_SECONDS} seconds..."
  kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout="${TIMEOUT_SECONDS}s" packageinstalls.packaging.carvel.dev ${INSTALL_NAME} && break || true

  # the cloud controller needs to be kicked because it might conflict with kapp-controller for taking ownership of cloud resources
  kubectl -n ${ASO_CONTROLLER_NAMESPACE} rollout restart deployments.apps azureserviceoperator-controller-manager

  let TEMP_TIMEOUT=${TIMEOUT_SECONDS}*2
  [[ ${TEMP_TIMEOUT} > ${MAX_TIMEOUT_SECONDS} ]] && TEMP_TIMEOUT=${MAX_TIMEOUT_SECONDS}
  TIMEOUT_SECONDS=${TEMP_TIMEOUT}
done
'

# run test
SECRET_NAME="${NAME}-bindable"
./${SCRIPT_FOLDER}/test.sh ${SECRET_NAME} ${APP_NAME}

popd
