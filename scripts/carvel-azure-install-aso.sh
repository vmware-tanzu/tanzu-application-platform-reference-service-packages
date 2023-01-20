#!/usr/bin/env bash

set -euo pipefail

CERT_MANAGER_MANIFEST="https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml"
ASO_MANIFEST="https://github.com/Azure/azure-service-operator/releases/download/v2.0.0-beta.3/azureserviceoperator_v2.0.0-beta.3.yaml"
ASO_NAMESPACE="azureserviceoperator-system"

echo ">> Install certmanager"
kubectl apply -f ${CERT_MANAGER_MANIFEST}
kubectl -n cert-manager wait --for=condition=Available=True deployments.apps cert-manager
kubectl -n cert-manager wait --for=condition=Available=True deployments.apps cert-manager-cainjector
kubectl -n cert-manager wait --for=condition=Available=True deployments.apps cert-manager-webhook
kubectl wait --for=condition=Available apiservices.apiregistration.k8s.io v1.cert-manager.io
kubectl wait --for=condition=Available apiservices.apiregistration.k8s.io v1.acme.cert-manager.io

echo ">> Install Azure Service Operator"
kubectl create ns ${ASO_NAMESPACE} || true
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: aso-controller-settings
  namespace: ${ASO_NAMESPACE}
stringData:
  AZURE_SUBSCRIPTION_ID: "$AZURE_SUBSCRIPTION_ID"
  AZURE_TENANT_ID: "$AZURE_TENANT_ID"
  AZURE_CLIENT_ID: "$AZURE_CLIENT_ID"
  AZURE_CLIENT_SECRET: "$AZURE_CLIENT_SECRET"
EOF

kubectl apply --server-side=true -f ${ASO_MANIFEST}
kubectl -n ${ASO_NAMESPACE} wait --for=condition=Available --timeout=5m deployments.apps azureserviceoperator-controller-manager
