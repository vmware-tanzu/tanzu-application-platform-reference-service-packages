#!/usr/bin/env bash

CONFIG_NAME=$1
CONFIG_IMAGE=$2
CONFIG_VERSION=$3
AZURE_CONFIG_SECRET_NAME=$4
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

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

kubectl wait --for=condition=Healthy configuration ${CONFIG_NAME}
kubectl get configuration
kubectl describe configurationrevisions.pkg.crossplane.io
sleep 10
kubectl wait --for=condition=ready pod -l pkg.crossplane.io/provider=provider-azure  --namespace ${CROSSPLANE_NAMESPACE}

echo ">> Create Azure Provider Config"
cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
metadata:
  name: default
kind: ProviderConfig
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: ${CROSSPLANE_NAMESPACE}
      name: ${AZURE_CONFIG_SECRET_NAME}
      key: creds
EOF

kubectl get providerconfig