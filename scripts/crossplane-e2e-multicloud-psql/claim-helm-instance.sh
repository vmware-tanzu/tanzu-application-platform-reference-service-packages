#!/usr/bin/env bash

set -euo pipefail

[ -z "${CLAIM_NAME:-}" ] && ( echo "The CLAIM_NAME environment variable must be defined" ; exit 1 )
[ -z "${STORAGE_CLASS:-}" ] && ( echo "The STORAGE_CLASS environment variable must be defined" ; exit 1 )
[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )

echo ">> Claiming a PSQL Instance"
kubectl apply -f - <<EOF
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  namespace: default
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: helm
  parameters:
    location: local
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: ${STORAGE_CLASS}
EOF

kubectl get providerconfig,xpostgresqlinstances,postgresqlinstances

echo ">> Showing Secrets (1)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

kubectl get managed
trap 'kubectl get managed ; kubectl describe postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME} ; kubectl get xpostgresqlinstances -o yaml ; kubectl get secrets ${CLAIM_NAME} -o yaml' ERR

echo ">> Waiting for Managed Resources To Get Ready"
kubectl wait --for=condition=ready postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME} --timeout=120s
# We can also wait on the "release"

echo ">> Showing Secrets (2)"
kubectl get secret -n ${CROSSPLANE_NAMESPACE}
kubectl get secret

echo ">> Showing Comp and Claim status"
kubectl get xpostgresqlinstances,postgresqlinstances
