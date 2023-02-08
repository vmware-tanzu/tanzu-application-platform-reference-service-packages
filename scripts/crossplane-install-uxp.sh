#!/usr/bin/env bash

CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

echo ">> Installing UXP - Universal Crossplane"
up uxp install --set 'args={--enable-external-secret-stores}' ${UXP_VERSION}
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=cloud-infrastructure-controller --namespace ${CROSSPLANE_NAMESPACE}

kubectl create clusterrolebinding crossplane-admin-binding --clusterrole cluster-admin --serviceaccount="upbound-system:crossplane" || true