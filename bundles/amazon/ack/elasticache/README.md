# AWS Controllers for Kubernetes - Elasticache Instance

Status: Experimental

## Prerequisites

### Security group

You need to have a security group allowing network traffic to the Elasticache instance.
On EKS, the cluster comes with a security group that's automatically applied to all nodes in the cluster.

```sh
EKS_CLUSTER_NAME="my-eks-cluster"
EKS_SECURITY_GROUP_ID=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --output text --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId')
```

This ID can then be used as source security group for the actual Elasticache security group.
If you're planning to have Elasticache deployed into the same VPC as EKS you can run the following commands
to create the security group:

```sh
EKS_VPC_ID=$(aws eks describe-cluster --name ${EKS_CLUSTER_NAME} --output text --query 'cluster.resourcesVpcConfig.vpcId')
ELASTICACHE_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "Elasticache" --description "Elasticache security group" --vpc-id ${EKS_VPC_ID} --output text --query GroupId)
```

whereas the following commands will create the proper rules for connecting to the Elasticache instance from EKS:

```sh
REDIS_PORT=6379
aws ec2 authorize-security-group-ingress --group-id ${ELASTICACHE_SECURITY_GROUP_ID} --source-group ${EKS_SECURITY_GROUP_ID} --protocol tcp --port ${REDIS_PORT}
```

### CacheSubnetGroup

The Elasticache nodes will be created in a `CacheSubnetGroup` which can be either created as part of the package, supplying the IDs of the subnets that have to be part of such group, or pre-created.

For example, you can get the IDs of the subnets in your EKS VPC running

```sh
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${EKS_VPC_ID}" --query "Subnets[].SubnetId" --output text)
```

and then use those values to create the `CacheSubnetGroup` like

```sh
SUBNET_GROUP_NAME="my-cache-subnet-group"
aws elasticache create-cache-subnet-group --cache-subnet-group-name ${SUBNET_GROUP_NAME} --cache-subnet-group-description ${SUBNET_GROUP_NAME} --subnet-ids $(echo $SUBNET_IDS)
```

## Use

The following command shows the available input fields that can be supplied to the package, along with their type and default value:

```sh
ytt --data-values-schema-inspect -o openapi-v3 -f bundles/azure/aso/psql/bundle/config
```

A sample input file looks like

```yaml
name: my-elasticache-cluster
namespace: elasticache
cacheSubnetGroupName: my-cache-subnet-group
vpcSecurityGroupIDs:
  - sg-0a4ddae4fbf426cc8 #! the security group ID stored in variable ELASTICACHE_SECURITY_GROUP_ID
```

and the whole infrastructure can then be created as

```sh
ytt -f bundles/azure/aso/psql/bundle/config -f /path/to/input/file.yaml | kubectl apply -f -
```

## Customize

To customize the configuration of this Package Bundle modify the contents of `bundle` directory and follow the [Build](#build) steps.

## Build

>**Note**: This will be automated in the future

To alter this Package, modify the contents and perform the following steps to build the Package Bundle image. These steps use the following:

* [kbld](https://carvel.dev/kbld)
* [imgpkg](https://carvel.dev/imgpkg)

1. Build a new Package bundle image:

```sh
export REPO_HOST=<YOUR_IMAGE_REPO> #! e.g. ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages
export BUNDLE_TAG=<YOUR_BUNDLE_TAG> #! e.g. latest

pushd bundle
    kbld -f config/ --imgpkg-lock-output=.imgpkg/images.yml
    imgpkg push -b ${REPO_HOST}/elasticache.aws.references.services.apps.tanzu.vmware.com:$BUNDLE_TAG -f .
popd
```

1. Take the SHA produced by `imgpkg` and update `repository/packages/amazon/elasticache/package.yaml` by modifying `template.spec.fetch[0].imgpkgBundle.image` value.
