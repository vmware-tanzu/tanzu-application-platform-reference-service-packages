#!/usr/bin/env bash

CONFIG_NAME=${1:-${CONFIG_NAME:-}}
CONFIG_IMAGE=${2:-${CONFIG_IMAGE:-}}
CONFIG_VERSION=${3:-${CONFIG_VERSION:-}}
[ -z "${CONFIG_NAME:-}" ] && ( echo "The CONFIG_NAME environment variable must be defined" ; exit 1 )
[ -z "${CONFIG_IMAGE:-}" ] && ( echo "The CONFIG_IMAGE environment variable must be defined" ; exit 1 )
[ -z "${CONFIG_VERSION:-}" ] && ( echo "The CONFIG_VERSION environment variable must be defined" ; exit 1 )

echo ">> Installing Crossplane Package via Configuration CR"
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: ${CONFIG_NAME}
spec:
  ignoreCrossplaneConstraints: true
  package: ${CONFIG_IMAGE}:${CONFIG_VERSION}
  packagePullPolicy: Allways
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 3
  skipDependencyResolution: true
EOF

sleep 300

kubectl wait --for=condition=Healthy --timeout=5m configuration ${CONFIG_NAME}
kubectl wait --for=condition=Healthy --timeout=5m configurationrevisions.pkg.crossplane.io -l pkg.crossplane.io/package=${CONFIG_NAME}
kubectl get configuration
kubectl describe configurationrevisions.pkg.crossplane.io
