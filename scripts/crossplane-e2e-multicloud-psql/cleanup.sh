#!/usr/bin/env bash

CLAIM_NAME=${CLAIM_NAME:-"postgresql-0001"}
TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-postgres"}
CONFIG_NAME=${CONFIG_NAME:-"trp-multicloud-psql"}

echo ">> Cleaning Up Resources"
echo " > WARNING -> This can take a while (~10 minutes), as it waits for Azure to delete the resources!"

kubectl delete postgresqlinstances ${CLAIM_NAME} || true
kubectl delete deploy ${TEST_APP_NAME} || true
kubectl delete configuration ${CONFIG_NAME} || true

kubectl delete providerconfigs.helm.crossplane.io default || true
kubectl delete providerconfigs.kubernetes.crossplane.io default || true

kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-helm || true
kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-kubernetes || true
kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-terraform || true