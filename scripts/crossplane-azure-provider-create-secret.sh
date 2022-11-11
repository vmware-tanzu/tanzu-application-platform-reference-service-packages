SECRET_NAME=$1
CREDS=$2

echo ">> Create Azure Config Secret - secret name=${SECRET_NAME}"
kubectl create secret generic "${SECRET_NAME}" -n upbound-system --from-literal=creds=${CREDS} || true