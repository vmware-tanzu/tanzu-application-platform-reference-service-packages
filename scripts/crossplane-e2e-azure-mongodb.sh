#!/usr/bin/env bash

echo ">> Local Test"

export CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}
AZURE_CREDS_SECRET_NAME=${AZURE_CREDS_SECRET_NAME:-"azure-secret"}
UXP_VERSION=${UXP_VERSION:-"v1.10.1-up.1"}
CONFIG_NAME=${CONFIG_NAME:-"trp-azure-mongodb"}
CONFIG_IMAGE=${CONFIG_IMAGE:-"ghcr.io/vmware-tanzu-labs/tap-reference-packages-azure/crossplane-mongodb"}
CONFIG_VERSION=${CONFIG_VERSION:-"0.23.1-beta.0"}
CLAIM_NAME=${CLAIM_NAME:-"trp-cosmosdb-mongo-08"}
TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-mongo"}

kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

pushd $(dirname $0)

# Requires AZURE_CONFIG to contain an Azure API credential config (JSON format)
./crossplane-azure-provider-create-secret.sh ${AZURE_CREDS_SECRET_NAME} "${AZURE_CONFIG}"

./crossplane-install-uxp.sh ${UXP_VERSION}

./crossplane-e2e-mongodb/crossplane-install-package.sh ${CONFIG_NAME} ${CONFIG_IMAGE} ${CONFIG_VERSION} ${AZURE_CREDS_SECRET_NAME}

./crossplane-e2e-mongodb/crossplane-claim-instance.sh ${CLAIM_NAME}

./crossplane-e2e-mongodb/crossplane-test.sh ${TEST_APP_NAME}

./crossplane-e2e-mongodb/crossplane-test.sh ${TEST_APP_NAME}

popd
