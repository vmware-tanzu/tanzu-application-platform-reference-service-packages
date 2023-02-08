#!/usr/bin/env bash

set -euo pipefail

[ -z "$SERVICE" ] && ( echo "The SERVICE environment variable must be defined" ; exit 1 )

CREDENTIALS=${CREDENTIALS:-$HOME/.aws/credentials}

helm_install() {
  echo ">> Install the AWS $SERVICE Controller for Kubernetes"

  aws ecr-public get-login-password --region us-east-1 | \
    helm registry login --username AWS --password-stdin public.ecr.aws

  helm upgrade --install \
    ack-$SERVICE-controller \
    oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart \
    --create-namespace \
    --namespace $ACK_NAMESPACE \
    --version=$RELEASE_VERSION \
    --set=aws.region=$AWS_REGION \
    $*
}

SERVICE=$(tr '[:upper:]' '[:lower:]' <<<$SERVICE)
RELEASE_VERSION=`curl -sL https://api.github.com/repos/aws-controllers-k8s/$SERVICE-controller/releases/latest | jq -r .tag_name`
ACK_NAMESPACE=${ACK_NAMESPACE:-ack-system}
AWS_REGION=${AWS_REGION:-eu-central-1}

echo ">> Define ACK authentication"
# https://aws-controllers-k8s.github.io/community/docs/user-docs/authentication/

if [ ! -z "${AWS_ACCESS_KEY_ID:-}" -a ! -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
  echo "WARNING - Using AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN environment variables"
  helm_install

  kubectl -n ${ACK_NAMESPACE} set env deployments.apps -l app.kubernetes.io/instance=ack-${SERVICE}-controller \
      AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
      AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
      AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"

elif [ -r "${CREDENTIALS}" ]; then
  echo "Using shared credentials file"
  SECRET="aws-credentials"
  kubectl create namespace $ACK_NAMESPACE || true
  kubectl -n ${ACK_NAMESPACE} delete secret ${SECRET} &>/dev/null || true
  kubectl -n ${ACK_NAMESPACE} create secret generic ${SECRET} --from-file credentials=${CREDENTIALS}

  helm_install --set=aws.credentials.secretName=${SECRET}

fi
