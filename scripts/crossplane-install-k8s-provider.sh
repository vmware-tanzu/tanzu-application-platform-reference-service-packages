#!/usr/bin/env bash

PROVIDER_NAME="provider-kubernetes"
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

up controlplane provider install xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.5.0 --name ${PROVIDER_NAME} || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io ${PROVIDER_NAME}
kubectl wait --for=condition=Available=True apiservices.apiregistration.k8s.io v1alpha1.kubernetes.crossplane.io

cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(kubectl -n ${CROSSPLANE_NAMESPACE} get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|'${CROSSPLANE_NAMESPACE}':|g')
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" || true
