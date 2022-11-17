---
title: UXP AWS provider
description: How to install and configure the UXP AWS provider
---

Upbound Universal Crossplane (UXP) AWS provider is a provider for Amazon Web Services developed and supported by Upbound.

It can be deployed on top of a Kubernetes cluster with Crossplane, by using either the Upbound CLI
(see [here](../index.md) for details about installation) or a YAML manifest.

## Installation

You can check available releases on [project's GitHub repository](https://github.com/upbound/provider-aws/releases)
or using [`gh`](https://cli.github.com/) like

```sh
gh release list --repo upbound/provider-aws
```

and store the desired release into the `PROVIDER_AWS_RELEASE` variable.

!!! note ""
    === "Upbound CLI"
        Do make sure you have installed the `up` CLI as described [here](../index.md) and execute
        ```sh
        up controlplane provider install xpkg.upbound.io/upbound/provider-aws:${PROVIDER_AWS_RELEASE} --name provider-aws
        ```

    === "YAML manifest"
        ```sh
        kubectl apply -f - <<EOF
        apiVersion: pkg.crossplane.io/v1
        kind: Provider
        metadata:
          name: provider-aws
        spec:
          package: xpkg.upbound.io/upbound/provider-aws:${PROVIDER_AWS_RELEASE}
        EOF
        ```

It is now necessary to configure the provider's authentication to the AWS API endpoints.

The authentication method can vary based on your company's policies: for example,
you might be allowed to use long-term credentials such as access key and secret access key pairs,
however, if your Kubernetes platform is AWS EKS, it's much more secure to use [IAM roles for service accounts (IRSA)][irsa].

Please make sure you do create the OIDC provider
as described in the [EKS set-up guide](../../usecases/aws/prerequisites/eks.md) before reading on.
The following paragraphs explain how to configure IRSA for the Crossplane AWS provider.

## Create IAM role and policy

You must create a proper role for the provider to assume, for granting the necessary and sufficient permissions to manage the AWS infrastructure.
The least-privilege principle applies, therefore it's important to understand the actual needs and create the permission policy accordingly.
For example, the following snippet creates a policy that allows the role it's attached to to execute actions only on the S3 service.

First of all, set your the AWS region you're operating in and your EKS cluster name.

```sh
# AWS region you're operating in
export AWS_REGION="eu-central-1"

# EKS cluster name
CLUSTER_NAME="my-eks-cluster"

# define variables for IAM
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --output text --query "cluster.identity.oidc.issuer" | cut -d/ -f3-)
CROSSPLANE_ROLE="crossplane-for-${CLUSTER_NAME}"
ROLE_TRUST_POLICY=$(mktemp)
ROLE_PERMISSION_POLICY=$(mktemp)
```

You can then define the role's trust policy, in order to allow Crossplane AWS provider's
service account to assume it as WebIdentity, and then create the role.

```sh
# prepare the trust policy document
cat > ${ROLE_TRUST_POLICY} <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {
            "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_ID}"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
            "StringLike": {
                "${OIDC_ID}:sub": "system:serviceaccount:upbound-system:provider-aws-*"
            }
        }
    }]
}
EOF

# create the role with the proper trust policy
aws iam create-role --role-name ${CROSSPLANE_ROLE} --assume-role-policy-document file://${ROLE_TRUST_POLICY}
```

Now, the permission policies, that define which permissions are granted to the role, have to be created and attached to the role.
For this example you will need just one policy, with a number of statements declaring what the role can or cannot do.

```sh
# create the permission policy document
cat > ${ROLE_PERMISSION_POLICY} <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "s3:*",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF

# create the permission policy
PERMISSION_POLICY_ARN=$(aws iam create-policy --policy-name ${CROSSPLANE_ROLE} --policy-document file://${ROLE_PERMISSION_POLICY} --query Policy.Arn --output text)

# attach the policy to the role
aws iam attach-role-policy --policy-arn ${PERMISSION_POLICY_ARN} --role-name ${CROSSPLANE_ROLE}

# clean up temporary files
rm ${ROLE_TRUST_POLICY}
rm ${ROLE_PERMISSION_POLICY}
```

## Create Kubernetes resources

Create a `ProviderConfig` resource to specify IRSA as authentication method.

```sh
kubectl apply -f - <<EOF
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: IRSA
EOF
```

Create a `ControllerConfig` resource to specify the AWS provider's settings,
including the IRSA role to assume:

```sh
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/${CROSSPLANE_ROLE}
  name: aws-irsa
EOF
```

and patch the AWS provider to use it:

```sh
kubectl patch providers.pkg.crossplane.io provider-aws --type='merge' --patch '{"spec": { "controllerConfigRef": { "name": "aws-irsa" } } }'
```

Destroy the existing pods to make sure that new ones will be created:

```sh
kubectl -n upbound-system delete pods -l pkg.crossplane.io/provider=provider-aws
```

Now you can test the effectiveness of the configuration by creating a simple S3 bucket:

```sh
BUCKET_NAME=$(kubectl create -o yaml -f - <<EOF | yq '.metadata.name'
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  generateName: crossplane-test-bucket-
spec:
  forProvider:
    region: ${AWS_REGION}
EOF
)
```

and verify its status

```sh hl_lines="1"
$ kubectl get buckets.s3.aws.upbound.io ${BUCKET_NAME}
NAME                           READY   SYNCED   EXTERNAL-NAME                  AGE
crossplane-test-bucket-cxr9g   True    True     crossplane-test-bucket-cxr9g   80s
```

As the bucket is marked as synced, it's worth checking the status of the AWS resource:

```sh hl_lines="1"
$ aws s3api list-buckets | jq '.Buckets[]|select(.Name == "'${BUCKET_NAME}'")'
{
  "Name": "crossplane-test-bucket-cxr9g",
  "CreationDate": "2022-11-05T00:36:49+00:00"
}
```

This proves that the provider is configured correctly and you can safely delete the test bucket:

```sh
kubectl delete buckets.s3.aws.upbound.io ${BUCKET_NAME}
```

[irsa]: https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html
