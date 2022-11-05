---
title: Creating AWS Elasticache instances by using a Carvel package (experimental)
---

This topic describes creating, updating, and deleting AWS Elasticache instances using a Carvel package.
For a more detailed and low-level alternative procedure, see [Creating Service Instances
that are compatible with Tanzu Application Platform][manual].

[manual]: ./manual.md

<!-- ## Prerequisite

Meet the [prerequisites][prereqs]:

The Package Repository and service instance Package Bundles for this guide can
be found in the [Reference Service Packages][ref-pkgs] GitHub repository.

[ref-pkgs]: https://github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages
[prereqs]: ./prerequisites.md

## <a id="elasticache-package-create"></a> Create an AWS Elasticache instance using a Carvel package

Follow the steps in the following procedures. -->

## Add a reference package repository to the cluster

The namespace `tanzu-package-repo-global` has a special significance.
The kapp-controller defines a Global Packaging namespace.
In this namespace, any package that is made available through a Package Repository
is available in every namespace.

When the kapp-controller is installed via Tanzu Application Platform, the namespace is `tanzu-package-repo-global`.
If you install the controller in another way, verify which namespace is considered the
Global Packaging namespace.
You can use the following command to get the global namespace:

```sh
GLOBAL_NAMESPACE=$(kubectl -n kapp-controller get deployment kapp-controller -o json | jq -r '.spec.template.spec.containers[]|select(.name=="kapp-controller").args[]|select(.|startswith("-packaging-global-namespace"))|split("=")[1]')
```

To add a reference package repository to the cluster:

1. Use the Tanzu CLI to add the new Service Reference packages repository:

   ```sh
   tanzu package repository add tap-reference-service-packages \
       --url ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages:0.0.3 \
       -n ${GLOBAL_NAMESPACE}
   ```

1. Create a `ServiceAccount` to provision `PackageInstall` resources by using the following example.
   The namespace of this `ServiceAccount` must match the namespace of the `tanzu package install`
   command in the next step.

    ```yaml title="rbac.yaml" linenums="1"
    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: elasticache-install
    ---
    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: elasticache-install
    rules:
    - apiGroups: ["elasticache.services.k8s.aws"]
      resources: ["*"]
      verbs: ["*"]
    - apiGroups: ["secretgen.carvel.dev", "secretgen.k14s.io"]
      resources: ["secrettemplates","passwords"]
      verbs:     ["*"]
    - apiGroups: [""]
      resources: ["serviceaccounts","configmaps"]
      verbs:     ["*"]
    - apiGroups: [""]
      resources: ["namespaces"]
      verbs:     ["get", "list"]  
    - apiGroups: ["rbac.authorization.k8s.io"]
      resources: ["roles","rolebindings"]
      verbs:     ["*"]
    ---
    kind: RoleBinding
    apiVersion: rbac.authorization.k8s.io/v1
    metadata:
      name: elasticache-install
    subjects:
    - kind: ServiceAccount
      name: elasticache-install
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: elasticache-install
    ```

    ```sh
    kubectl apply -f rbac.yaml
    ```

## Create an AWS Elasticache instance through the Tanzu CLI

In order to configure the package installation, you must provide a values file.
Here are some values highlighted:

- **`namespace`** is the namespace where to deploy the AWS resources to, it may differ from the one
  dedicated to the package(s).
  The following example uses the `service-instances` namespace, do make sure it exists
  or set `createNamespace: true`.
- **`cacheSubnetGroupName`** is the name of the AWS `CacheSubnetGroup` to use for deploying the
  Elasticache instance.
  If it doesn't exist it can be created as part of the package setting the `createCacheSubnetGroup` flag
  to `true` and providing the `subnetIDs` list.
- **`vpcSecurityGroupIDs`** is a mandatory list of security group IDs that will be associated to the
  Elasticache instances and will filter network traffic to/from them.

!!! warning
    Because of the ephemeral nature of such IDs, if the security groups are destroyed and re-created,
    the package will need to be updated with the new values, otherwise Elasticache instances
    will become unreachable.

It is recommended to set the value of the `name` field below
from `redis` to something unique, using only lowercase letters, digits and hyphens.
Do make sure you also change the commands below using a `redis` value,
such as the `redis-writer-creds-bindable` from the SecretTemplate,
and replace `redis` with the actual `name`.

1. Create a values file holding the configuration of the AWS Elasticache service instance:

    ```yaml title="redis-instance-values.yml" linenums="1"
    ---
    name: redis
    namespace: service-instances
    cacheSubnetGroupName: redis-subnets
    replicasPerNodeGroup: 1
    vpcSecurityGroupIDs:
      - sg-0a4ddae4fbf426cc8
    tags:
      - key: Generator
        value: Carvel package
    ```

    !!! tip
        To understand which settings are available for this package you can run:
        ```sh
        tanzu package available get \
          --values-schema elasticache.aws.references.services.apps.tanzu.vmware.com/0.0.1-alpha
        ```
        This shows a list of all configuration options you can use in the
        `redis-instance-values.yml` file.

1. Use the Tanzu CLI to install an instance of the reference service instance package.

    ```sh
    tanzu package install redis-instance \
       --package-name elasticache.aws.references.services.apps.tanzu.vmware.com \
       --version 0.0.1-alpha \
       --service-account-name elasticache-install \
       --values-file redis-instance-values.yml \
       --wait
    ```

You can install the `elasticache.aws.references.services.apps.tanzu.vmware.com`
package multiple times to produce various AWS Elasticache instances.
You create a separate `<INSTANCE-NAME>-values.yml` for each instance, set a different `name` value,
and then install the package with the instance-specific data values file.

## Verify the AWS Resources

Verify the creation status for the AWS Elasticache instance by inspecting the conditions
in the Kubernetes API. To do so, run:

```sh
kubectl -n service-instances get replicationgroups.elasticache.services.k8s.aws redis -o yaml
```

After a few minutes, even up to 10 or more depending on how many replicas have been requested,
you will be able to find the binding-compliant secrets produced by `PackageInstall`.
Currently the package creates a `reader` and a `writer` user, each one with its own bindable secret.
To view them, run:

```sh
kubectl -n service-instances get secrettemplate redis-reader-creds-bindable -o jsonpath="{.status.secret.name}"
kubectl -n service-instances get secrettemplate redis-writer-creds-bindable -o jsonpath="{.status.secret.name}"
```

## Verify the Service Instance

First, wait until the Elasticache instance is ready.

```sh
kubectl -n service-instances wait --for=condition=ACK.ResourceSynced=True replicationgroups.elasticache.services.k8s.aws ack-elasticache
```

Next, ensure a bindable `Secret` was produced by the `SecretTemplate`.
To do so, run:

```sh
kubectl -n service-instances wait --for=condition=ReconcileSucceeded=True --timeout=5m secrettemplate redis-reader-creds-bindable

kubectl -n service-instances get secret -n default redis-reader-creds-bindable
```

The same applies to the `redis-writer-creds-bindable` resources.

## Summary

You have learnt to use Carvel's `Package` and `PackageInstall` APIs to
create an AWS Elasticache instance.
If you want to learn more about the pieces that comprise this service instance package,
see [Creating AWS Elasticache Instances manually using kubectl](./manual.md).

Now that you have this available in the cluster, you can learn how to make use
of it by continuing where you left off in [Consuming AWS Elasticache with ACK][create-class].

[create-class]: ./index.md#create-a-service-instance-class-for-aws-elasticache
