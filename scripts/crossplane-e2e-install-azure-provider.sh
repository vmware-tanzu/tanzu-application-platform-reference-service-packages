CROSSPLANE_NAMESPACE=$1
AZURE_CONFIG_SECRET_NAME=$2

up controlplane provider install xpkg.upbound.io/upbound/provider-azure:v0.18.1 || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io upbound-provider-azure


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

kubectl get providers.pkg.crossplane.io upbound-provider-azure