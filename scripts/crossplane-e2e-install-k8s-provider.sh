up controlplane provider install xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.5.0 || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io crossplane-contrib-provider-kubernetes

sleep 3

cat <<EOF | kubectl apply -f -
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

SA=$(kubectl -n upbound-system get sa -o name | grep provider-kubernetes | sed -e 's|serviceaccount\/|upbound-system:|g')
kubectl create clusterrolebinding provider-kubernetes-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" || true