#!/usr/bin/env bash

CONFIG_NAME=$1
CONFIG_IMAGE=$2
CONFIG_VERSION=$3
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

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

kubectl wait --for=condition=Healthy configuration ${CONFIG_NAME}
kubectl get configuration
kubectl describe configurationrevisions.pkg.crossplane.io

