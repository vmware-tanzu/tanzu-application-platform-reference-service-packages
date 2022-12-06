#!/usr/bin/env bash

CLAIM_NAME=$1
STORAGE_CLASS=$2
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

echo ">> Claiming a PSQl Instance"
cat <<EOF | kubectl apply -f -
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: azure
  parameters:
    location: "West Europe"
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: ${STORAGE_CLASS}
EOF

kubectl get providerconfig,xpostgresqlinstances,postgresqlinstances

echo ">> Installing Test Application"
kubectl apply -f https://raw.githubusercontent.com/joostvdg/spring-boot-postgres/main/kubernetes/deployment.yaml
kubectl get deployment

echo ">> Showing Secrets (1)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Waiting for Managed Resources To Get Ready"
kubectl wait --for=condition=ready postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME} --timeout=400s
# We can also wait on the "release"

echo ">> Showing Secrets (2)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Showing Comp and Claim status"
kubectl get xpostgresqlinstances,postgresqlinstances
