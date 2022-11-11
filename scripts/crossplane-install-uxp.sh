UXP_VERSION=${1}
echo ">> Installing UXP - Universal Crossplane"
up uxp install --set 'args={--enable-external-secret-stores}' ${UXP_VERSION}
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=cloud-infrastructure-controller --namespace upbound-system