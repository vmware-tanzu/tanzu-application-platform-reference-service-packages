#!/usr/bin/env bash

set -euo pipefail

TIMEOUT=${TIMEOUT:-5m}

export NAME="${NAME:-$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | sha1sum | head -c 20)}"
PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
export APP_NAME=${APP_NAME:-${NAME}}

pushd $(dirname $0)

# install ASO and dependencies
./carvel-azure-install-aso.sh

# install package
LOCATION="${LOCATION:-westeurope}"
PUBLIC_IP="$(curl -sSf https://api.ipify.org)"

VALUES=$(mktemp)
cat <<EOF >$VALUES
---
name: ${NAME}
namespace: ${PACKAGE_NAMESPACE}
location: ${LOCATION}
aso_controller_namespace: azureserviceoperator-system
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
INSTALL_NAME=${PACKAGE_METADATA_NAME}

echo ">> Prepare RBAC"
ytt -f ./carvel-e2e-azure-psql/rbac.ytt.yml -v serviceAccount=${SA} -v namespace=${PACKAGE_NAMESPACE} | kubectl apply -f -

echo ">> Install package"
kctrl package install -n ${PACKAGE_NAMESPACE} -i ${INSTALL_NAME} -p ${PACKAGE_METADATA_NAME} --version ${PACKAGE_VERSION} --values-file ${VALUES} --service-account-name ${SA} --wait=false

RESTARTS_MAX=4
RESTARTS_COUNT=0
while [ $RESTARTS_COUNT -lt $RESTARTS_MAX ]; do
  echo ">> Waiting for stack ${NAME} to reconcile..."
  kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout=${TIMEOUT} packageinstalls.packaging.carvel.dev ${INSTALL_NAME} && AGAIN=0 || AGAIN=1
  if [ $AGAIN -eq 0 ]; then
    RESTARTS_COUNT=$RESTARTS_MAX
  else
    # ASO needs to be kicked because it conflicts with kapp-controller for taking ownership of Azure resources
    let RESTARTS_COUNT=$RESTARTS_COUNT+1
    kubectl -n azureserviceoperator-system rollout restart deployments.apps azureserviceoperator-controller-manager
  fi
done

# run test
SECRET_NAME="${NAME}-bindable"
./carvel-e2e-azure-psql/test.sh ${SECRET_NAME} ${APP_NAME}

popd
