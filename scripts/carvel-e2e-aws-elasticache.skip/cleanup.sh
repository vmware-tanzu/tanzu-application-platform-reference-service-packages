#!/usr/bin/env bash

set -euo pipefail

pushd $(dirname $0)

[ -z "${PACKAGE_METADATA_NAME:-}" ] && echo "Environment variable PACKAGE_METADATA_NAME is not defined" && exit 1

export PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}

INSTALL_NAME=${PACKAGE_METADATA_NAME}

VALUES_SECRET_NAME=$(kubectl -n ${PACKAGE_NAMESPACE} get packageinstalls.packaging.carvel.dev ${INSTALL_NAME} -o jsonpath='{.spec.values[0].secretRef.name}')
PACKAGE_DATA=$(kubectl -n ${PACKAGE_NAMESPACE} get secrets ${VALUES_SECRET_NAME} -o jsonpath='{.data}')
PACKAGE_VALUES=$(jq -e '.data."values.yml"' <<<$PACKAGE_DATA || jq -e '.data."values.yaml"' <<<$PACKAGE_DATA)

NAME=$(base64 -d <<<$PACKAGE_VALUES | yq .name)
APP_NAMESPACE=$(base64 -d <<<$PACKAGE_VALUES | yq .namespace)

APP_NAME=${APP_NAME:-${NAME}}
TIMEOUT="5m"
CHECK_INTERVAL="10s"


kubectl -n ${APP_NAMESPACE} delete deployments.apps ${APP_NAME} || true

SA=${PACKAGE_METADATA_NAME}

echo ">> Uninstall package"
kctrl package installed delete -n ${PACKAGE_NAMESPACE} -i ${INSTALL_NAME} --wait-timeout ${TIMEOUT} --wait-check-interval ${CHECK_INTERVAL} -y || {
    # the default user gets locked into the ACK.Terminal state because it can be deleted BEFORE its group is deleted
    # and when a resource get to that state there's no way to get out of it
    # in order to delete the kubernetes resource I need to remove the finalizers
    kubectl -n ${APP_NAMESPACE} patch users.elasticache.services.k8s.aws ${NAME}-default --type=json --patch '[{"op":"remove","path":"/metadata/finalizers"}]'
    DEFAULT_USER_ID=$(kubectl -n ${APP_NAMESPACE} get users.elasticache.services.k8s.aws ${NAME}-default -o jsonpath='{.spec.userID}')
    aws elasticache delete-user --user-id $DEFAULT_USER_ID
    kubectl -n ${APP_NAMESPACE} delete users.elasticache.services.k8s.aws ${NAME}-default
}

echo ">> Remove RBAC"
ytt -f ./rbac.ytt.yml -v serviceAccount=${SA} -v namespace=${PACKAGE_NAMESPACE} | kubectl delete -f -

popd
