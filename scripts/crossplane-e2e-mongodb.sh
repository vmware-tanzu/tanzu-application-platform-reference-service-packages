echo ">> Local Test"

AZURE_CREDS_SECRET_NAME=${AZURE_CREDS_SECRET_NAME:-"azure-secret"}
UXP_VERSION=${UXP_VERSION:-"v1.10.1-up.1"}
export CONFIG_NAME=${CONFIG_NAME:-"trp-azure-mongodb"}
CONFIG_IMAGE=${CONFIG_IMAGE:-"ghcr.io/vmware-tanzu-labs/tap-reference-packages-azure/crossplane-mongodb"}
CONFIG_VERSION=${CONFIG_VERSION:-"0.23.1-beta.0"}
export CLAIM_NAME=${CLAIM_NAME:-"trp-cosmosdb-mongo-08"}
export TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-mongo"}

kubectl create namespace upbound-system || true

# Requires AZURE_CONFIG to contain an Azure API credential config (JSON format)
./crossplane-azure-provider-create-secret.sh ${AZURE_CREDS_SECRET_NAME} "${AZURE_CONFIG}"

./crossplane-install-uxp.sh ${UXP_VERSION}

./mongodb/crossplane-install-package.sh ${CONFIG_NAME} ${CONFIG_IMAGE} ${CONFIG_VERSION} ${AZURE_CREDS_SECRET_NAME}

./mongodb/crossplane-claim-instance.sh ${CLAIM_NAME}

./mongodb/crossplane-test.sh ${TEST_APP_NAME}

./mongodb/crossplane-test.sh ${TEST_APP_NAME}
