CLAIM_NAME=$1

echo ">> Claiming a MongoDBInstance"
cat <<EOF | kubectl apply -f -
apiVersion: azure.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: MongoDBInstance
metadata:
  namespace: default
  name: ${CLAIM_NAME}
spec:
  compositionSelector:
    matchLabels:
      database: mongodb
  parameters:
    location: "West Europe"
    capabilities:
      - name: "EnableMongo"
      - name: "mongoEnableDocLevelTTL"
  publishConnectionDetailsTo:
    name: trp-cosmosdb-mongo-bindable-08
    configRef:
      name: default
    metadata:
      labels:
        services.apps.tanzu.vmware.com/class: azure-mongodb
EOF

kubectl get providerconfig,xmongodbinstance,mongodbinstance

echo ">> Installing Test Application"
kubectl apply -f https://raw.githubusercontent.com/joostvdg/spring-boot-mongo/main/kubernetes/raw/deployment.yaml 
kubectl get deployment

echo ">> Showing Secrets (1)"
kubectl get secret -n upbound-system
kubectl get secret

echo ">> Waiting for Managed Resources To Get Ready"
kubectl wait --for=condition=ready mongodbinstances.azure.ref.services.apps.tanzu.vmware.com ${CLAIM_NAME} --timeout=400s

echo ">> Showing Secrets (2)"
kubectl get secret -n upbound-system
kubectl get secret

echo ">> Showing Comp and Claim status"
kubectl get xmongodbinstance,mongodbinstance