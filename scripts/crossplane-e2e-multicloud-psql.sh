#!/usr/bin/env bash

set -euo pipefail

trap "echo '###ERROR###' ; !! ; top -b -1 -n 1" ERR

echo ">> Local Test"

SCRIPT_FOLDER=$(basename $0 .sh)

[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )

kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

pushd $(dirname $0)


# echo ">> Local Test"

# export CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}
# AZURE_CREDS_SECRET_NAME=${AZURE_CREDS_SECRET_NAME:-"azure-secret"}
# UXP_VERSION=${UXP_VERSION:-"v1.10.1-up.1"}
# CONFIG_NAME=${CONFIG_NAME:-"trp-multicloud-psql"}
# CONFIG_IMAGE=${CONFIG_IMAGE:-"ghcr.io/vmware-tanzu-labs/trp-azure-psql"}
# CONFIG_VERSION=${CONFIG_VERSION:-"0.0.1-rc-1"}
# CLAIM_NAME=${CLAIM_NAME:-"postgresql-0001"}
# TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-postgres"}
STORAGE_CLASS=${STORAGE_CLASS:-"default"}


# kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

# pushd $(dirname $0)

# TODO use this when we also have the Azure version
# Requires AZURE_CONFIG to contain an Azure API credential config (JSON format)
# ./crossplane-azure-provider-create-secret.sh ${AZURE_CREDS_SECRET_NAME} "${AZURE_CONFIG}"

# ./crossplane-install-uxp.sh ${UXP_VERSION}


echo "> Installing required providers"

# trap $(dirname $0)/crossplane-e2e-multicloud-psql/cleanup.sh EXIT

# install provider as well as its ProviderConfig only if the INSTALL_PROVIDER environment variable is not empty
[ -z "${INSTALL_PROVIDER:-}" ] || (
    ./crossplane-install-helm-provider.sh
    ./crossplane-install-k8s-provider.sh
    ./crossplane-install-tf-provider.sh
)

./${SCRIPT_FOLDER}/install-package.sh ${CONFIG_NAME} ${CONFIG_IMAGE} ${CONFIG_VERSION}
./${SCRIPT_FOLDER}/claim-helm-instance.sh ${CLAIM_NAME} ${STORAGE_CLASS}
./${SCRIPT_FOLDER}/test.sh

# ./${SCRIPT_FOLDER}/cleanup.sh

sleep 5

[ -z "${INSTALL_PROVIDER:-}" ] || (
    ./crossplane-install-azure-provider.sh
    ./crossplane-install-k8s-provider.sh
    ./crossplane-install-tf-provider.sh
)

./${SCRIPT_FOLDER}/install-package.sh ${CONFIG_NAME} ${CONFIG_IMAGE} ${CONFIG_VERSION}
./${SCRIPT_FOLDER}/claim-azure-instance.sh ${CLAIM_NAME} ${STORAGE_CLASS}
./${SCRIPT_FOLDER}/test.sh

./crossplane-e2e-multicloud-psql/cleanup.sh

popd
