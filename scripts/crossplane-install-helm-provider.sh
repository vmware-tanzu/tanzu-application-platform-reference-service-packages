#!/usr/bin/env bash

PROVIDER_NAME="provider-helm"
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

up controlplane provider install xpkg.upbound.io/crossplane-contrib/provider-helm:v0.12.0 --name ${PROVIDER_NAME} || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io ${PROVIDER_NAME}
kubectl wait --for=condition=Available=True apiservices.apiregistration.k8s.io v1beta1.helm.crossplane.io

cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(kubectl -n ${CROSSPLANE_NAMESPACE} get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|'${CROSSPLANE_NAMESPACE}':|g')
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" || true
