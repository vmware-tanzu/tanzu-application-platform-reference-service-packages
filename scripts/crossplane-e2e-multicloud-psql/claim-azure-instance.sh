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
    firewallRule:
      startIpAddress: "0.0.0.0"
      endIpAddress: "255.255.255.255"
EOF

kubectl get providerconfig,xpostgresqlinstances,postgresqlinstances

echo ">> Showing Secrets (1)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Waiting for Managed Resources To Get Ready"
kubectl wait --for=condition=ready postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME} --timeout=600s
# We can also wait on the "release"

echo ">> Showing Secrets (2)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Showing Comp and Claim status"
kubectl get xpostgresqlinstances,postgresqlinstances
