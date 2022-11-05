---
title: Consuming AWS Elasticache with ACK
---

This guide describes using the Services Toolkit to allow Tanzu Application Platform workloads to
consume AWS Elasticache.
This particular topic makes use of [AWS Controller for Kubernetes (ACK)][ack-overview] to manage AWS Elasticache instances.

!!! note
    This usecase is not currently compatible with TAP air-gapped installations.

[ack-overview]: https://aws-controllers-k8s.github.io/community/docs/community/overview/

## Prerequisites

You need to meet a number of [prerequisites](../../../prerequisites/index.md) before being able to effectively follow this guide.

## Create service instances that are compatible with Tanzu Application Platform

The installation of the AWS Elasticache Controller for Kubernetes results in the availability of
new Kubernetes APIs for interacting with Elasticache resources from within the TAP cluster.

```sh
kubectl api-resources --api-group elasticache.services.k8s.aws
```

```text
NAME                   SHORTNAMES   APIVERSION                              NAMESPACED   KIND
cacheparametergroups                elasticache.services.k8s.aws/v1alpha1   true         CacheParameterGroup
cachesubnetgroups                   elasticache.services.k8s.aws/v1alpha1   true         CacheSubnetGroup
replicationgroups                   elasticache.services.k8s.aws/v1alpha1   true         ReplicationGroup
snapshots                           elasticache.services.k8s.aws/v1alpha1   true         Snapshot
usergroups                          elasticache.services.k8s.aws/v1alpha1   true         UserGroup
users                               elasticache.services.k8s.aws/v1alpha1   true         User
```

To create an AWS Elasticache service instance for consumption by Tanzu Application
Platform, you can use a ready-made, reference Carvel Package.
The Service Operator typically performs this step. Follow the steps in
[Creating an AWS Elasticache service instance using a Carvel Package][si-carvel].

Alternatively, if you are interested in authoring your own Reference Package
and want to learn about the underlying APIs and how they come together to
produce a useable service instance for the Tanzu Application Platform, you can
achieve the same outcome using the more advanced [Creating an AWS Elasticache service instance manually][si-manual].

Once you have completed either of these steps and have a running AWS Elasticache service
instance, please return here to continue with the rest of the use case.

[si-carvel]: ./package.md
[si-manual]: ./manual.md

## Create a service instance class for AWS Elasticache

Now that you know how to create AWS Elasticache instances, it's time to learn how to make
those instances discoverable to Application Operators.
Again, this step is typically performed by the service operator persona.

You can use Services Toolkit's `ClusterInstanceClass` API to create a service instance class to
represent Elasticache service instances within the cluster.
The existence of such classes makes these logical service instances discoverable to
application operators, thus allowing them to create [Resource Claims][resource-claims]
for such instances and to then bind them to application workloads.

Create the following Kubernetes resource on your AKS cluster:

```yaml title="clusterinstanceclass.yaml" linenums="1"
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: aws-elasticache
spec:
  description:
    short: AWS Elasticache instances
  pool:
    kind: Secret
    labelSelector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: aws-elasticache
```

```sh
kubectl apply -f clusterinstanceclass.yaml
```

In this particular example, the class represents claimable instances of
Postgresql by a `Secret` object with the label
`services.apps.tanzu.vmware.com/class` set to `aws-elasticache`.

In addition, you need to grant sufficient RBAC permissions to Services Toolkit to be able to
read the secrets specified by the class. Create the following RBAC on your AKS cluster:

```yaml title="clusterrole.yaml" linenums="1"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: stk-secret-reader
  labels:
    servicebinding.io/controller: "true"
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
```

```sh
kubectl apply -f clusterrole.yaml
```

If you want to claim resources across namespace boundaries, you will have to create
a corresponding `ResourceClaimPolicy`.
For example, if the provisioned AWS Elasticache instance named `redis` exists in namespace `service-instances`
and you want to allow App Operators to claim them for workloads residing in the `default` namespace,
you would have to create the following `ResourceClaimPolicy`:

```yaml title="resourceclaimpolicy.yaml" linenums="1"
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: default-can-claim-aws-elasticache
  namespace: service-instances
spec:
  subject:
    kind: Secret
    group: ""
    selector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: aws-elasticache
  consumingNamespaces: [ "default" ]
```

```sh
kubectl apply -f resourceclaimpolicy.yaml
```

## Discover, Claim, and Bind to an AWS Elasticache for Redis instance

The act of creating the `ClusterInstanceClass` and the corresponding RBAC essentially advertises to
application operators that AWS Elasticache for Redis is available to use with
their application workloads on Tanzu Application Platform.
In this section, you learn how to discover, claim, and bind to the
AWS Elasticache service instance previously created.
Discovery and claiming service instances is typically the responsibility
of the application operator persona.
Binding is typically a step for Application Developers.

To discover what service instances are available to them, application operators can run:

```sh hl_lines="1"
$ tanzu services classes list

  NAME             DESCRIPTION
  aws-elasticache  AWS Elasticache instances
```

You can see information about the `ClusterInstanceClass` created in the previous step.
Each `ClusterInstanceClass` created will be added to the list of classes returned here.

The next step is to "claim" an instance of the desired class, but to do that, the application
operators must first discover the list of currently claimable instances for the class.
The capacity to claim instances is affected by many variables (including namespace boundaries, claim
policies, and the exclusivity of claims) and so Services Toolkit provides a CLI command to help inform
application operators of the instances that can result in successful claims.
This command is the `tanzu service claimable list` command.

```sh hl_lines="1"
$ tanzu services claimable list --class aws-elasticache -n default

  NAME                         NAMESPACE          KIND    APIVERSION
  redis-reader-creds-bindable  service-instances  Secret  v1
  redis-writer-creds-bindable  service-instances  Secret  v1
```

Create a claim for the newly created secret by running:

```sh
tanzu services claim create redis-writer-claim \
  --namespace default \
  --resource-namespace service-instances \
  --resource-name redis-writer-creds-bindable \
  --resource-kind Secret \
  --resource-api-version v1
```

Obtain the claim reference of the claim by running:

```sh hl_lines="1"
$ tanzu services claim list -o wide

  NAME                READY  REASON  CLAIM REF
  redis-writer-claim  True   Ready   services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:redis-writer-claim
```

### Test Claim With TAP Workload

Create an application workload that consumes the claimed AWS Elasticache by running:

Example:

```sh
tanzu apps workload create my-workload \
  --git-repo <a-git-repo> \
  --git-tag <a-tag-to-checkout> \
  --type web \
  --annotation autoscaling.knative.dev/minScale=1 \
  --service-ref db=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:redis-writer-claim
```

`--service-ref` is set to the claim reference obtained previously.

Your application workload starts and gets automatically the credentials to the
AWS Elasticache instance via service bindings.

## Delete an AWS Elasticache service instance resources

To delete the AWS Elasticache service instance, you can run the appropriate cleanup commands
for how you created the service.

### Delete an AWS Elasticache instance via Carvel Package

```sh
tanzu package installed delete redis-instance
```

### Delete an AWS Elasticache instance via Kubectl

Delete the AWS Elasticache instance by running:

```console
kubectl delete -n service-instances replicationgroup.elasticache.services.k8s.aws redis
kubectl delete -n service-instances usergroup.elasticache.services.k8s.aws redis
kubectl delete -n service-instances user.elasticache.services.k8s.aws redis-default
kubectl delete -n service-instances user.elasticache.services.k8s.aws redis-reader
kubectl delete -n service-instances user.elasticache.services.k8s.aws redis-writer
kubectl delete -n service-instances cachesubnetgroups.elasticache.services.k8s.aws ack-elasticache
kubectl delete -n service-instances secrettemplate.secretgen.carvel.dev redis-reader-creds-bindable
kubectl delete -n service-instances secrettemplate.secretgen.carvel.dev redis-writer-creds-bindable
kubectl delete -n service-instances password.secretgen.carvel.dev redis-reader-creds
kubectl delete -n service-instances password.secretgen.carvel.dev redis-writer-creds
kubectl delete -n service-instances serviceaccounts redis-elasticache-reader
kubectl delete -n service-instances role redis-elasticache-reader
kubectl delete -n service-instances rolebinding redis-elasticache-reader
```
<!-- 
## AWS Controller for Kubernetes Troubleshooting

Sometimes the AWS Controller for Kubernetes doesn't behave as expected.
You can go through a [troubleshooting guide][si-troubleshooting] to search for help
about the most common scenarios.

[si-troubleshooting]: ./troubleshooting.md
[resource-claims]: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.8/svc-tlk/GUID-resource_claims-api_docs.html -->

[resource-claims]: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.8/svc-tlk/GUID-resource_claims-api_docs.html
