---
title: Install the AWS Controllers for Kubernetes (ACK)
description: How to install the AWS Controllers for Kubernetes (ACK)
---

[AWS Controllers for Kubernetes (ACK)][ack-overview] lets you define and use AWS service resources directly from Kubernetes, by mapping AWS services to Kubernetes CRDs.

There's a number of different controllers to manage different AWS services, with different levels of maturity, listed in the [documentation](https://aws-controllers-k8s.github.io/community/docs/community/services/).
The following example shows how to install the Elasticache controller, but the same concept applies to all of them.

[ack-overview]: https://aws-controllers-k8s.github.io/community/docs/community/overview/

## Install ElastiCache Controller

```sh
SERVICE="elasticache"
RELEASE_VERSION=`curl -sL https://api.github.com/repos/aws-controllers-k8s/$SERVICE-controller/releases/latest | grep '"tag_name":' | cut -d'"' -f4`
ACK_SYSTEM_NAMESPACE="ack-system"
AWS_REGION="eu-central-1"

aws ecr-public get-login-password --region us-east-1 | \
  helm registry login --username AWS --password-stdin public.ecr.aws

helm install \
  ack-$SERVICE-controller \
  oci://public.ecr.aws/aws-controllers-k8s/$SERVICE-chart \
  --create-namespace \
  --namespace $ACK_SYSTEM_NAMESPACE \
  --version=$RELEASE_VERSION \
  --set=aws.region=$AWS_REGION
```

!!! warning
    The `--region` flag in the `aws ecr-public get-login-password` command must be set either to `us-east-1` or `us-west-2`, as described in [ECR public AWS documentation](https://docs.aws.amazon.com/general/latest/gr/ecr-public.html).

Set the `AWS_REGION` variable according to your needs and
[configure the IAM role for ACK's service account](https://aws-controllers-k8s.github.io/community/docs/user-docs/irsa/#step-1-create-an-oidc-identity-provider-for-your-cluster).

If you followed the guide for [creating the EKS cluster][create-eks] v1.23+ you should have already configured the OIDC provider for authentication,
therefore you can skip to [configuring the IAM role and policy for the service account](https://aws-controllers-k8s.github.io/community/docs/user-docs/irsa/#step-2-create-an-iam-role-and-policy-for-your-service-account).

[create-eks]: ./eks.md
