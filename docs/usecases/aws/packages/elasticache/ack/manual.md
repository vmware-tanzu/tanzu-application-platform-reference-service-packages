---
title: Creating AWS Elasticache Instances manually using kubectl (experimental)
---

This topic describes how to use Services Toolkit to allow Tanzu Application Platform workloads to
consume AWS Elasticache for Redis.
This particular topic makes use of [AWS Controller for Kubernetes (ACK)][ack-overview]
to manage AWS Elasticache resources.

Following this guide, you will be creating all the resources in the `service-instances` namespace.
It's important to make sure it exists before reading on.

## Create a cache subnet group

The Elasticache instances must be created in a Cache Subnet Group, that can be created in a number
of ways, here you will leverage ACK to create it.

First of all, you have to get the IDs of the subnets you want to build the Cache Subnet Group for.


!!! example
    You could have a list of all the subnets in a given VPC and then choose amongst them.

    ```sh
    VPC_NAME="my-vpc-name"
    VPC_ID=$(aws ec2 describe-vpcs --filter "Name=tag:Name,Values=${VPC_NAME}" --query "Vpcs[0].VpcId" --output text)
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --query "Subnets[].SubnetId")
    ```

    This is just an example. Make sure you do choose your subnets carefully.

When you have a list of subnetIDs stored in the `SUBNET_IDS` shell variable, you can create your `CacheSubnetGroup`.
Create the following `ytt` template

```yaml title="cache-subnet-group.ytt.yaml" linenums="1"
#@ load("@ytt:data", "data")
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: CacheSubnetGroup
metadata:
  name: ack-elasticache
  namespace: service-instances
spec:
  cacheSubnetGroupDescription: A subnet group for Elasticache
  cacheSubnetGroupName: #@ data.values.cacheSubnetGroupName
  subnetIDs: #@ data.values.subnetIDs
```

Now you can use `ytt` to add the proper values and pipe it to `kubectl apply`

```sh
CACHE_SUBNET_GROUP_NAME="ack-elasticache"

ytt \
  -v cacheSubnetGroupName="${CACHE_SUBNET_GROUP_NAME}" \
  -v subnetIDs="${SUBNET_IDS}" \
  -f cache-subnet-group.ytt.yaml \
  | kubectl apply -f -
```

## Create the users to log into Elasticache

You need at least one usergroup with at least one member user to associate
to the Elasticache instance.
Every group must have one user with **name** `default` and up to 100 total users
(more on [Elasticache quotas][elasticache-quotas]).

However, there can be only one user with **id** `default` **per Elasticache instance**, which is
automatically made available by AWS, but there can be more users with **name** `default`
and different id.
This is useful to know in order to create proper default users for each group.

For the sake of this example, you will create just one user group and a default user in it with all
the permissions.
In order to generate a random password, you will make use of [Secretgen Controller][secretgen-controller],
which is provided out of the box by TAP, thus if you went through the prerequisites
it should have already been installed.

The following snippet declares the default user along with its auto-generated password and the usergroup:

```yaml title="elasticache-user.yaml" linenums="1"
---
apiVersion: secretgen.k14s.io/v1alpha1
kind: Password
metadata:
  name: ack-elasticache-default-creds
  namespace: service-instances
spec:
  length: 128
  secretTemplate:
    type: Opaque
    stringData:
      password: $(value)
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: User
metadata:
  name: ack-elasticache-default
  namespace: service-instances
spec:
  accessString: on ~* +@all
  engine: redis
  passwords:
  - name: ack-elasticache-default-creds
    key: password
    namespace: service-instances
  userID: ack-elasticache-default
  userName: default
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: UserGroup
metadata:
  name: ack-elasticache
  namespace: service-instances
spec:
  engine: redis
  userGroupID: ack-elasticache
  userIDs:
  - ack-elasticache-default
```

Store it into the `elasticache-user.yaml` file and apply it:

```sh
kubectl apply -f elasticache-user.yaml
```

## Create the ReplicationGroup

Before going ahead and create the `ReplicationGroup` resource, which maps to the actual instance
that can be consumed, you need to create a proper security group for filtering the
incoming and outgoing traffic.

Assuming that you want to be able to connect to Elasticache from the EKS instance
[created previously](../../../prerequisites/eks.md), you can use the EKS security group as source
for the new security group which will actually filter the Elasticache traffic.

```sh
# AWS region you're operating in
export AWS_REGION="eu-west-1"

# EKS cluster name
CLUSTER_NAME="my-eks-cluster"

EKS_SECURITY_GROUP_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

# VPC_ID has been defined above in "Create a cache subnet group"
ELASTICACHE_SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "Elasticache" --description "Elasticache security group" --vpc-id ${VPC_ID} --output text --query GroupId)

REDIS_PORT=6379
aws ec2 authorize-security-group-ingress --group-id ${ELASTICACHE_SECURITY_GROUP_ID} --source-group ${EKS_SECURITY_GROUP_ID} --protocol tcp --port ${REDIS_PORT}
```

Now you can define the `ReplicationGroup` using the following `ytt` template

```yaml title="replication-group.ytt.yaml" linenums="1"
#@ load("@ytt:data", "data")
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: ReplicationGroup
metadata:
  name: ack-elasticache
  namespace: service-instances
spec:
  description: A redis service instance
  engine: redis
  replicationGroupID: ack-elasticache
  cacheNodeType: cache.t2.micro
  cacheSubnetGroupName: #@ data.values.cacheSubnetGroupName
  securityGroupIDs:
  - #@ data.values.securityGroupID
  userGroupIDs:
  - ack-elasticache
```

and apply it

```sh
ytt \
  -v cacheSubnetGroupName="${CACHE_SUBNET_GROUP_NAME}" \
  -v securityGroupID="${ELASTICACHE_SECURITY_GROUP_ID}" \
  -f replication-group.ytt.yaml \
  | kubectl apply -f -
```

It will take 5 to 10 minutes to create.
You can wait for the resource to be ready running the command

```sh
kubectl -n service-instances wait --for=condition=ACK.ResourceSynced=True replicationgroups.elasticache.services.k8s.aws ack-elasticache
```

or you can take a closer look at the new resource

```sh
kubectl -n service-instances get replicationgroups.elasticache.services.k8s.aws ack-elasticache -o yaml
```

particularly at the `status` field, which eventually will display something like

```yaml
status:
...
  conditions:
  - status: "True"
    type: ACK.ResourceSynced
...
  status: available
```

The status object also contains the details of the provisioned AWS resource,
along with the nodegroups and their endpoints.

## Create a Binding Specification Compatible Secret

As mentioned in
[Creating service instances that are compatible with Tanzu Application Platform](./index.md#create-service-instances-that-are-compatible-with-tanzu-application-platform),
in order for Tanzu Application Platform workloads to be able to claim and bind to services
such as AWS Elasticache,
a resource compatible with [Service Binding Specification](https://github.com/servicebinding/spec)
must exist in the cluster.
This can take the form of either a `ProvisionedService`, as defined by the specification, or a
Kubernetes `Secret` with some known keys, also as defined in the specification.

In this guide, you create a Kubernetes secret in the necessary format using the
[secretgen-controller][secretgen-controller] tooling.
You do so by using the `SecretTemplate` API to extract values from
the ACK resources and populate a new spec-compatible secret with the values.

### Create a ServiceAccount for Secret Templating

As part of using the `SecretTemplate` API, a Kubernetes `ServiceAccount` must be provided.
The `ServiceAccount` is used for reading the `ReplicationGroup` resource and the `Secret` created
from the `Password` resource above.

Create the following Kubernetes resources on your EKS cluster:

```yaml title="rbac.yaml" linenums="1"
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ack-elasticache-reader
  namespace: service-instances
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ack-elasticache-reader
  namespace: service-instances
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
  resourceNames:
  - ack-elasticache-default-creds
- apiGroups:
  - elasticache.services.k8s.aws
  resources:
  - replicationgroups
  verbs:
  - get
  - list
  - watch
  resourceNames:
  - ack-elasticache
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ack-elasticache-reader
  namespace: service-instances
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ack-elasticache-reader
subjects:
- kind: ServiceAccount
  name: ack-elasticache-reader
  namespace: service-instances
```

```sh
kubectl apply -f rbac.yaml
```

### Create a SecretTemplate

In combination with the `ServiceAccount` just created, a `SecretTemplate` can be used to declaratively
create a secret that is compatible with the service binding specification.
For more information on this API see the [Secret Template Documentation][secrettemplate-docs].

Create the following Kubernetes resource on your EKS cluster:

```yaml title="secrettemplate.yaml" linenums="1"
apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretTemplate
metadata:
  name: ack-elasticache-default-creds-bindable
  namespace: service-instances
spec:
  serviceAccountName: ack-elasticache-reader
  inputResources:
  - name: replicationGroup
    ref:
      apiVersion: elasticache.services.k8s.aws/v1alpha1
      kind: ReplicationGroup
      name: ack-elasticache
  - name: creds
    ref:
      apiVersion: v1
      kind: Secret
      name: ack-elasticache-default-creds
  template:
    metadata:
      labels:
        services.apps.tanzu.vmware.com/class: aws-elasticache
    type: servicebinding.io/redis
    stringData:
      type: redis
      username: $(.creds.data.username)
      ssl: "true"
      host: $(.replicationGroup.status.nodeGroups[0].primaryEndpoint.address)
      port: $(.replicationGroup.status.nodeGroups[0].primaryEndpoint.port)
    data:
      password: $(.creds.data.password)
```

```sh
kubectl apply -f secrettemplate.yaml
```

### Verify the Service Instance

Wait until the `ReplicationGroup` instance is ready as described [before](#create-the-replicationgroup).

Next, ensure a bindable `Secret` was produced by the `SecretTemplate`.
To do so, run:

```sh
kubectl -n service-instances wait --for=condition=ReconcileSucceeded=True secrettemplates.secretgen.carvel.dev ack-elasticache-default-creds-bindable

kubectl -n service-instances get secret ack-elasticache-default-creds-bindable
```

[elasticache-quotas]: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/quota-limits.html
[secretgen-controller]: https://github.com/vmware-tanzu/carvel-secretgen-controller
[secrettemplate-docs]: https://github.com/vmware-tanzu/carvel-secretgen-controller/blob/develop/docs/secret-template.md
[secretgen-controller]: https://github.com/vmware-tanzu/carvel-secretgen-controller/
[ack-overview]: https://aws-controllers-k8s.github.io/community/docs/community/overview