#!/usr/bin/env bash

set -euo pipefail

CLAIM_NAME=${1:-${CLAIM_NAME:-}}
[ -z "${CLAIM_NAME:-}" ] && ( echo "The CLAIM_NAME environment variable must be defined" ; exit 1 )
[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )

echo
kubectl get xmongodbinstances.azure.ref.services.apps.tanzu.vmware.com,mongodbinstances.azure.ref.services.apps.tanzu.vmware.com

echo
echo ">> Claiming a MongoDBInstance"
kubectl apply -f - <<EOF
apiVersion: azure.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: MongoDBInstance
metadata:
  namespace: default
  name: ${CLAIM_NAME}
spec:
  compositionSelector:
    matchLabels:
      database: mongodb
  parameters:
    location: "West Europe"
    capabilities:
      - name: "EnableMongo"
      - name: "mongoEnableDocLevelTTL"
  publishConnectionDetailsTo:
    name: ${CLAIM_NAME}
    configRef:
      name: default
    metadata:
      labels:
        services.apps.tanzu.vmware.com/class: azure-mongodb
EOF

kubectl get xmongodbinstance,mongodbinstance

echo ">> Showing Secrets (1)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Waiting for Managed Resources To Get Ready"
kubectl wait --for=condition=ready mongodbinstances.azure.ref.services.apps.tanzu.vmware.com ${CLAIM_NAME} --timeout=10m

echo ">> Showing Secrets (2)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Showing Comp and Claim status"
kubectl get xmongodbinstance,mongodbinstance
