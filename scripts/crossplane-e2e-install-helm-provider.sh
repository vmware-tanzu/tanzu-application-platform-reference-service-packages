up controlplane provider install xpkg.upbound.io/crossplane-contrib/provider-helm:v0.12.0 || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io crossplane-contrib-provider-helm

sleep 3

cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(kubectl -n upbound-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|upbound-system:|g')
kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" || true