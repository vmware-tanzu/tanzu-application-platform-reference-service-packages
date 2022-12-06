#!/usr/bin/env bash

CLAIM_NAME=${CLAIM_NAME:-"postgresql-0001"}
TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-postgres"}
CONFIG_NAME=${CONFIG_NAME:-"trp-multicloud-psql"}

echo ">> Cleaning Up Resources"
echo " > WARNING -> This can take a while (~10 minutes), as it waits for Azure to delete the resources!"

kubectl delete postgresqlinstances ${CLAIM_NAME} || true
kubectl delete deploy ${TEST_APP_NAME} || true
kubectl delete configuration ${CONFIG_NAME} || true

kubectl delete flexibleserverconfigurations.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true
kubectl delete flexibleserverdatabases.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true
kubectl delete flexibleserverfirewallrules.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true

FLEXIBLE_SERVER_NAME=$(kubectl get flexibleserver.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} -o name)
kubectl patch ${FLEXIBLE_SERVER_NAME} -p '{"metadata":{"finalizers":null}}' --type=merge || true
kubectl delete flexibleserver.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true


kubectl delete providerconfigs.helm.crossplane.io default || true
kubectl delete providerconfigs.kubernetes.crossplane.io default || true

kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-helm || true
kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-kubernetes || true
kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-terraform || true

