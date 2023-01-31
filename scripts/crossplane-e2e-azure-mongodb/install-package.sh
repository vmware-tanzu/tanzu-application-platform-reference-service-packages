#!/usr/bin/env bash

set -euo pipefail

CONFIG_IMAGE=${1:-${CONFIG_IMAGE:-}}
CONFIG_VERSION=${2:-${CONFIG_VERSION:-}}
[ -z "${CONFIG_IMAGE:-}" ] && ( echo "The CONFIG_IMAGE environment variable must be defined" ; exit 1 )
[ -z "${CONFIG_VERSION:-}" ] && ( echo "The CONFIG_VERSION environment variable must be defined" ; exit 1 )

echo ">> Installing Crossplane Package via Configuration CR"
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: ${CONFIG_NAME}
  annotations:
    meta.crossplane.io/description: |
      Package for Azure MongoDB via CosmosDB (DocumentDB) using a limited Crossplane package.
spec:
  ignoreCrossplaneConstraints: false
  package: ${CONFIG_IMAGE}:${CONFIG_VERSION}
  packagePullPolicy: IfNotPresent
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 3
  skipDependencyResolution: false
EOF

sleep 300

kubectl wait --for=condition=Healthy --timeout=5m configuration ${CONFIG_NAME}
kubectl wait --for=condition=Healthy --timeout=5m configurationrevisions.pkg.crossplane.io -l pkg.crossplane.io/package=${CONFIG_NAME}
kubectl get configuration
kubectl describe configurationrevisions.pkg.crossplane.io
kubectl wait --for=condition=Available apiservices.apiregistration.k8s.io v1alpha1.azure.ref.services.apps.tanzu.vmware.com
echo
kubectl api-resources --api-group azure.ref.services.apps.tanzu.vmware.com
