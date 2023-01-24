#!/usr/bin/env bash

set -euo pipefail

[ -z "${CROSSPLANE_NAMESPACE:-}" ] && ( echo "The CROSSPLANE_NAMESPACE environment variable must be defined" ; exit 1 )
[ -z "${AZURE_CONFIG:-}" ] && ( echo "The AZURE_CONFIG environment variable must be defined" ; exit 1 )

PROVIDER_NAME="upbound-provider-azure"
AZURE_CONFIG_SECRET_NAME="azure-secret"

kubectl create namespace ${CROSSPLANE_NAMESPACE} || true

echo ">> Install ${PROVIDER_NAME} provider"
up controlplane provider install xpkg.upbound.io/upbound/provider-azure:v0.18.1 --name ${PROVIDER_NAME} || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io ${PROVIDER_NAME}
kubectl wait --for=condition=Available=True apiservices.apiregistration.k8s.io v1beta1.azure.upbound.io

echo ">> Create Azure Config Secret - secret name=${AZURE_CONFIG_SECRET_NAME}"
kubectl delete secret ${AZURE_CONFIG_SECRET_NAME} -n ${CROSSPLANE_NAMESPACE} || true
kubectl create secret generic ${AZURE_CONFIG_SECRET_NAME} -n ${CROSSPLANE_NAMESPACE} --from-literal=creds="${AZURE_CONFIG}"

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

kubectl wait --for=condition=Healthy --timeout=5m providers.pkg.crossplane.io ${PROVIDER_NAME}
kubectl -n upbound-system get deployments.apps

echo
kubectl get providers.pkg.crossplane.io ${PROVIDER_NAME}
echo
kubectl api-resources --api-group azure.upbound.io -o name | xargs -rn1 kubectl get crd
echo