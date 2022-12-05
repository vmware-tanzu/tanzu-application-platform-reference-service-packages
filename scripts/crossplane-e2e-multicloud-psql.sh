#!/usr/bin/env bash

echo ">> Local Test"

export CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}
#AZURE_CREDS_SECRET_NAME=${AZURE_CREDS_SECRET_NAME:-"azure-secret"}
UXP_VERSION=${UXP_VERSION:-"v1.10.1-up.1"}
CONFIG_NAME=${CONFIG_NAME:-"trp-multicloud-psql"}
CONFIG_IMAGE=${CONFIG_IMAGE:-"ghcr.io/vmware-tanzu-labs/trp-azure-psql"}
CONFIG_VERSION=${CONFIG_VERSION:-"0.0.0-0.0.11-10-geabb607"}
CLAIM_NAME=${CLAIM_NAME:-"postgresql-0001"}
TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-postgres"}
STORAGE_CLASS=${STORAGE_CLASS:-"default"}

kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

pushd $(dirname $0)

# TODO use this when we also have the Azure version
# Requires AZURE_CONFIG to contain an Azure API credential config (JSON format)
# ./crossplane-azure-provider-create-secret.sh ${AZURE_CREDS_SECRET_NAME} "${AZURE_CONFIG}"

./crossplane-install-uxp.sh ${UXP_VERSION}


echo "> Installing required providers"

./crossplane-e2e-install-helm-provider.sh
./crossplane-e2e-install-k8s-provider.sh
./crossplane-e2e-install-tf-provider.sh


./crossplane-e2e-multicloud-psql/install-package.sh ${CONFIG_NAME} ${CONFIG_IMAGE} ${CONFIG_VERSION}

./crossplane-e2e-multicloud-psql/claim-helm-instance.sh ${CLAIM_NAME} ${STORAGE_CLASS}

./crossplane-e2e-multicloud-psql/test.sh ${TEST_APP_NAME} 

popd
