---
title: Create an EKS cluster with EBS CSI driver
description: How to create an EKS cluster with EBS CSI driver
---

An EKS cluster can be created in a number of ways, including AWS console, CLI, Terraform or CloudFormation.
The quickest and simplest way to create an EKS cluster is to use [eksctl](https://eksctl.io/),
a CloudFormation wrapper, that will be used in this guide.

## Define the environment parameters

The following are the parameters needed for the commands in this guide,
which must be set the values that match your environment and needs.

```sh
# AWS region you're operating in
export AWS_REGION="eu-central-1"

# autoscaling group minimum number of nodes
ASG_MIN_NODES="2"

# autoscaling group maximum number of nodes
ASG_MAX_NODES="4"

# EKS cluster name
CLUSTER_NAME="my-eks-cluster"

# EKS kubernetes version to deploy
KUBERNETES_VERSION="1.23"
```

!!! info
    The `AWS_REGION` variable must be an environment variable (thus the `export`)
    to be used by `eksctl` and `aws` commands.
    The other variables can be just shell variables.

!!! tip
    A list of available kubernetes versions for the `KUBERNETES_VERSION` variable can be obtained running
   
    ```sh
    aws eks describe-addon-versions --query "addons[].addonVersions[].compatibilities[].clusterVersion" | jq 'unique|sort'
    ```

## Create the EKS cluster

The following command can create an EKS cluster based on the parameters defined above:

```sh
eksctl create cluster -m ${ASG_MIN_NODES} -M ${ASG_MAX_NODES} -n ${CLUSTER_NAME} --version ${KUBERNETES_VERSION}
```

The previous command waits until the cluster is created and also updates the `KUBECONFIG` file with the details of the new cluster.

## Configure the EBS CSI controller

From version 1.23 onwards it is necessary to create the addon for the EBS CSI driver.

```sh
aws eks create-addon --cluster-name ${CLUSTER_NAME} --addon-name aws-ebs-csi-driver
```

EKS pods' service accounts can assume AWS IAM roles to be able to authenticate and interact with
the AWS APIs.
They are mapped to web identities via an IAM OIDC provider that must be created for the EKS cluster.
You will then need to create a proper role for the EBS CSI controller to be able to create and manage
EBS volumes.

```sh
# define variables for IAM
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_URL=$(aws eks describe-cluster --name ${CLUSTER_NAME} --output text --query "cluster.identity.oidc.issuer")
OIDC_ID=$(cut -d/ -f3- <<<$OIDC_URL)
EBS_ROLE="AmazonEKS_EBS_CSI_Driver-${CLUSTER_NAME}"
ROLE_TRUST_POLICY=$(mktemp)
ROLE_PERMISSION_POLICY=$(mktemp)

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
            "StringEquals": {
                "${OIDC_ID}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            }
        }
    }]
}
EOF

# create the role for the EBS CSI controller with the proper trust policy
aws iam create-role --role-name ${EBS_ROLE} --assume-role-policy-document file://${ROLE_TRUST_POLICY}

# fetch a sample permission policy document
curl -sSfL -o ${ROLE_PERMISSION_POLICY} https://raw.githubusercontent.com/kubernetes-sigs/aws-ebs-csi-driver/master/docs/example-iam-policy.json

# create the permission policy
PERMISSION_POLICY_ARN=$(aws iam create-policy --policy-name ${EBS_ROLE} --policy-document file://${ROLE_PERMISSION_POLICY} --query Policy.Arn --output text)

# attach the policy to the role
aws iam attach-role-policy --policy-arn ${PERMISSION_POLICY_ARN} --role-name ${EBS_ROLE}

# clean up temporary files
rm ${ROLE_TRUST_POLICY}
rm ${ROLE_PERMISSION_POLICY}
```

Next, you must prepare the OIDC provider (see also [AWS documentation][eks-oidc]).
If the EKS cluster has just been created the OIDC provider does not exist yet,
otherwise you can run the following command to make sure

```sh
aws iam list-open-id-connect-providers | grep $OIDC_ID
```

If no output is returned, the OIDC provider does not exist and you must create it.

!!! note ""
    === "Option 1 (quick)"
        The `eksctl` does the heavy lifting for you and creates
        the OIDC provider with the proper configuration for your EKS cluster.

        ```sh
        eksctl utils associate-iam-oidc-provider --cluster ${CLUSTER_NAME} --approve
        ```

    === "Option 2 (know what you are doing)"
        Get rid of the `eksctl` magic and configure the OIDC provider yourself.

        Get the SHA1 fingerprint for validating the OIDC provider certificate:
        ```sh
        OIDC_HOST=$(echo $OIDC_ID | cut -d/ -f1)
        SHA1_FINGERPRINT=$({echo | openssl s_client -connect ${OIDC_HOST}:443 -servername ${OIDC_HOST} -showcerts | openssl x509 -fingerprint -noout -sha1} 2>/dev/null | cut -d= -f2 | sed s/://g)
        ```
        
        Create the OIDC provider:
        ```sh
        aws iam create-open-id-connect-provider --url ${OIDC_URL} --thumbprint-list ${SHA1_FINGERPRINT} --client-id-list sts.amazonaws.com
        ```

You must then configure the Kubernetes service account to assume the role

```sh
# annotate the controller service account with the new role ARN
kubectl -n kube-system annotate serviceaccount ebs-csi-controller-sa eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/${EBS_ROLE}

# restart ebs-csi-controller pods
kubectl -n kube-system rollout restart deployment ebs-csi-controller
```

Your EKS cluster is now configured to dynamically allocate EBS volumes.
You need to create the proper `StorageClass` resources for your `PersistentVolumeClaims` to use,
like in [this example][dynamic-provisioning-example].

[eks-oidc]: https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
[dynamic-provisioning-example]: https://github.com/kubernetes-sigs/aws-ebs-csi-driver/tree/master/examples/kubernetes/dynamic-provisioning
