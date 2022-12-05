up controlplane provider install xpkg.upbound.io/crossplane-contrib/provider-terraform:v0.4.0 || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io crossplane-contrib-provider-terraform

sleep 1