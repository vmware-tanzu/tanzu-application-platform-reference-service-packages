#!/usr/bin/env bash

set -euo pipefail

[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )
[ -z "${CLAIM_NAME:-}" ] && ( echo "The CLAIM_NAME environment variable must be defined" ; exit 1 )
[ -z "${CONFIG_NAME:-}" ] && ( echo "The CONFIG_NAME environment variable must be defined" ; exit 1 )

TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-mongo"}
PROVIDER_NAME="upbound-provider-azure"
AZURE_CONFIG_SECRET_NAME="azure-secret"

echo ">> Cleaning Up Resources"
echo " > WARNING -> This can take a while (~10 minutes), as it waits for Azure to delete the resources!"

kubectl delete mongodbinstance ${CLAIM_NAME} || true
kubectl delete deploy ${TEST_APP_NAME} || true
kubectl delete MongoDatabase -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete MongoCollection -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete Account -l crossplane.io/claim-name=${CLAIM_NAME} ||  true
kubectl delete ResourceGroup -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete configuration ${CONFIG_NAME} || true

[ -z "${INSTALL_PROVIDER:-}" ] || (
    kubectl delete providerconfig.azure.upbound.io default || true
    kubectl delete secret ${AZURE_CONFIG_SECRET_NAME} -n ${CROSSPLANE_NAMESPACE} || true
    kubectl delete providers.pkg.crossplane.io ${PROVIDER_NAME} || true
)
