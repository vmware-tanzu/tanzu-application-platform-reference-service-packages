cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: xpkg.upbound.io/upbound/provider-terraform:v0.2.0
EOF

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io provider-terraform


sleep 1