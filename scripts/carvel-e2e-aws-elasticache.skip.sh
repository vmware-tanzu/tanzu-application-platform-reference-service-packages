#!/usr/bin/env bash

set -euo pipefail

INSTALL_TIMEOUT="20m"

SCRIPT_FOLDER=$(basename $0 .sh)

export NAME="${NAME:-$(dd if=/dev/urandom bs=20 count=1 2>/dev/null | sha1sum | head -c 20)}"
export PACKAGE_NAMESPACE=${PACKAGE_NAMESPACE:-services}
export APP_NAMESPACE=${APP_NAMESPACE:-services}
export APP_NAME=${APP_NAME:-${NAME}}
export ACK_NAMESPACE="ack-system"

[ -z "${PACKAGE_METADATA_NAME:-}" ] && echo "Environment variable PACKAGE_METADATA_NAME is not defined" && exit 1
[ -z "${PACKAGE_VERSION:-}" ] && echo "Environment variable PACKAGE_VERSION is not defined" && exit 1
[ -z "${CACHE_SUBNET_GROUP_NAME:-}" ] && echo "Environment variable CACHE_SUBNET_GROUP_NAME is not defined" && exit 1

while true; do
  case "${1:-}" in
    --skip-ack-install)
      SKIP_ACK_INSTALL=1 ; shift ;;
    *)
      break ;;
  esac
done

pushd $(dirname $0)

if [ -z ${SKIP_ACK_INSTALL:-} ]; then
  # install ACK
  ./carvel-aws-install-ack.sh
fi

echo ">> Prepare security group"

JOBNAME="get-public-ip-${NAME}"
kubectl create job ${JOBNAME} --image curlimages/curl -- curl -sSf https://api.ipify.org
kubectl wait --for=condition=Complete=True job ${JOBNAME}
PUBLIC_IP="$(kubectl logs jobs/${JOBNAME})"
kubectl delete job ${JOBNAME}

VPC_ID=$(aws elasticache describe-cache-subnet-groups --cache-subnet-group-name $CACHE_SUBNET_GROUP_NAME --query 'CacheSubnetGroups[0].VpcId' --output text)
SG_NAME="elasticache-test-${NAME}"

# make sure the security group does not exist before creating a new one
{
  aws ec2 describe-security-groups --filters 'Name="vpc-id",Values="'${VPC_ID}'"' 'Name="group-name",Values="'${SG_NAME}'"' --query 'SecurityGroups[0].GroupId' --output text | xargs aws ec2 delete-security-group --group-id
} || true
SG_ID=$(aws ec2 create-security-group --group-name "${SG_NAME}" --description "elasticache security group for testing" --vpc-id $VPC_ID --output text --query GroupId)
# trap "aws ec2 delete-security-group --group-id $SG_ID" EXIT
aws ec2 authorize-security-group-ingress --group-id $SG_ID --cidr ${PUBLIC_IP}/32 --protocol tcp --port 6379


VALUES=$(mktemp)
cat <<EOF >$VALUES
---
name: test-${NAME}
namespace: ${PACKAGE_NAMESPACE}
cacheSubnetGroupName: ${CACHE_SUBNET_GROUP_NAME}
cacheNodeType: cache.t2.micro
vpcSecurityGroupIDs:
  - ${SG_ID}
EOF

# install package
kubectl create namespace ${PACKAGE_NAMESPACE} || true

SA=${PACKAGE_METADATA_NAME}
export INSTALL_NAME=${PACKAGE_METADATA_NAME}

echo ">> Prepare RBAC"
ytt -f ./${SCRIPT_FOLDER}/rbac.ytt.yml -v serviceAccount=${SA} -v namespace=${PACKAGE_NAMESPACE} | kubectl apply -f -

echo ">> Install package"
kctrl package install -n ${PACKAGE_NAMESPACE} -i ${INSTALL_NAME} -p ${PACKAGE_METADATA_NAME} --version ${PACKAGE_VERSION} --values-file ${VALUES} --service-account-name ${SA} --wait=false

timeout --foreground -s TERM $INSTALL_TIMEOUT bash -c '
INIT_TIMEOUT_SECONDS=${TIMEOUT:-60}
MAX_TIMEOUT_SECONDS=${TIMEOUT:-300}
TIMEOUT_SECONDS=${INIT_TIMEOUT_SECONDS}
while true; do
  echo ">> Waiting for stack ${NAME} to reconcile for ${TIMEOUT_SECONDS} seconds..."
  kubectl -n ${PACKAGE_NAMESPACE} wait --for=condition=ReconcileSucceeded --timeout="${TIMEOUT_SECONDS}s" packageinstalls.packaging.carvel.dev ${INSTALL_NAME} && break || true

  # the cloud controller needs to be kicked because it might conflict with kapp-controller for taking ownership of cloud resources
  kubectl -n ${ACK_NAMESPACE} rollout restart deployments.apps -l app.kubernetes.io/instance=ack-${SERVICE}-controller

  let TEMP_TIMEOUT=${TIMEOUT_SECONDS}*2
  [[ ${TEMP_TIMEOUT} > ${MAX_TIMEOUT_SECONDS} ]] && TEMP_TIMEOUT=${MAX_TIMEOUT_SECONDS}
  TIMEOUT_SECONDS=${TEMP_TIMEOUT}
done
'

# run test
SECRET_NAME="${NAME}-bindable"
# ./${SCRIPT_FOLDER}/test.sh ${SECRET_NAME} ${APP_NAME}

popd
