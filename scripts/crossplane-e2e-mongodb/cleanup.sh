#!/usr/bin/env bash

CLAIM_NAME=${CLAIM_NAME:-"trp-cosmosdb-mongo-08"}
TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-mongo"}
CONFIG_NAME=${CONFIG_NAME:-"trp-azure-mongodb"}

echo ">> Cleaning Up Resources"
echo " > WARNING -> This can take a while (~10 minutes), as it waits for Azure to delete the resources!"

kubectl delete mongodbinstance ${CLAIM_NAME} || true
kubectl delete deploy ${TEST_APP_NAME} || true
kubectl delete MongoDatabase -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete MongoCollection -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete Account -l crossplane.io/claim-name=${CLAIM_NAME} ||  true
kubectl delete ResourceGroup -l crossplane.io/claim-name=${CLAIM_NAME} || true
kubectl delete configuration ${CONFIG_NAME} || true
kubectl delete providerconfig.azure.upbound.io default || true
