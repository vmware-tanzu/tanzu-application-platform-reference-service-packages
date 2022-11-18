---
title: Via Crossplane Package
description: How to create an Azure MongoDB instance via a Crossplane package
---

In this section, we look at installing a Crossplane package,
and then use the resources provided by this package to create the MongoDB instance.

## Prerequisites

* [UpBound's Universal Crossplane:material-launch:](../../../../../../crossplane/)

## Install Package

Or use a Kubernetes resource file:

=== "Upbound CLI"
    Do make sure you have installed the `up` CLI, as described [here](../../../../../../crossplane), and execute:
    ```sh
    up controlplane configuration install \
        --name azure-mongodb \
        ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages/azure/crossplane/mongodb:0.0.4
    ```

=== "Kubernetes manifest"
    ```sh
    kubectl apply -f - <<EOF
    apiVersion: pkg.crossplane.io/v1
    kind: Configuration
    metadata:
        name: azure-mongodb
    spec:
        package: ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages/azure/crossplane/mongodb:0.0.4
    EOF
    ```

The [Crossplane docs](https://crossplane.io/docs/v1.10/concepts/packages.html#specpackage) clarify what you can configure in a Configuration.

To verify the Configuration has been installed successfully, run this command:

```sh
kubectl get configuration,configurationrevision
```

Which should yield something like this:

```sh
NAME                                            INSTALLED   HEALTHY   PACKAGE                                                                                                            AGE
configuration.pkg.crossplane.io/azure-mongodb   True        True      ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages/azure/crossplane/mongodb:0.0.4          13m

NAME                                                                 HEALTHY   REVISION   IMAGE                                                                                                              STATE    DEP-FOUND   DEP-INSTALLED   AGE
configurationrevision.pkg.crossplane.io/azure-mongodb-99c3a327f258   True      1          ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages/azure/crossplane/mongodb:0.0.4          Active   1           1               13m
```

!!! tip
    If the Configuration does not turn healthy within a few minutes,
    the information will be in the events.
    
    So use `kubectl describe`:

    ```sh
    kubectl describe configurationrevision
    ```

This Configuration package lists the UpBound **Azure Provider** as its dependency.
Crossplane resolves and installs the dependencies for you.

If you have already installed the Provider, you can either remove it (and any related **ProviderConfig**),
or disable the dependency resolution.

It does look like the `up` CLI currently does not support this,
so you have to use the _manifest_ solution instead.
Setting the following option: `spec.skipDependencyResolution: true`.

To verify the Provider is up and running:

```sh
kubectl get provider
```

This should yield the following:

```sh
NAME                     INSTALLED   HEALTHY   PACKAGE                                          AGE
upbound-provider-azure   True        True      xpkg.upbound.io/upbound/provider-azure:v0.19.0   29m
```

!!! hint
    In case you need to recreate the **ProviderConfig**,
    here's how you do that.

    ```sh
    kubectl apply -f - <<EOF
    apiVersion: azure.upbound.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
    spec:
      credentials:
        source: Secret
        secretRef:
          namespace: upbound-system
          name: azure-secret
          key: creds
    EOF
    ```

## Create Crossplane Claim

In contrast to creating a MongoDB instance through the managed resource definitions directly,
installing a Crossplane package (or _Configuration_) requires an additional step.

You now have a blueprint available to create MongoDB instances, through
Crossplane's [CompositeResourceDefinition](https://crossplane.io/docs/v1.10/concepts/composition.html#defining-composite-resources)(_XRD_)
and [Composition](https://crossplane.io/docs/v1.10/concepts/composition.html#configuring-composition) resources.

The package adds the following Custom Resources (_CR_) to your cluster:

* **MongoDBInstance**: the _Claim_ resource you use for requesting a new instance
* **XMongoDBInstance**: the Composition "instance", which is the bridge between your **Claim** and the **Composition**

It also adds an **XRD** and the aforementioned **Composition**.
The XRD defines the API for a type, including how to implement it (via one or more _Compositions_) and
how to request an instance of that type via a _Claim_.

In this package, the ClaimName is `MongoDBInstance`, which is the Kubernetes CR's **kind**.

```sh
LOCATION="West Europe"
INSTANCE_NAME=my-mongodb-instance
```

To create the claim, apply the following manifest:

```sh
kubectl apply -f - <<EOF
apiVersion: azure.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: MongoDBInstance
metadata:
  namespace: default
  name: ${INSTANCE_NAME}
spec:
  compositionSelector:
    matchLabels:
      database: mongodb
  parameters:
    location: ${LOCATION}
    capabilities:
      - name: "EnableMongo"
      - name: "mongoEnableDocLevelTTL"
  publishConnectionDetailsTo:
    name: ${INSTANCE_NAME}-bindable
    configRef:
      name: default
    metadata:
      labels:
        services.apps.tanzu.vmware.com/class: azure-mongodb
EOF
```

!!! hint
    For the Services Toolkit to bind the connection secret, 
    we use the `publishConnectionDetailsTo` beta feature instead of the original `writeConnectionSecretToRef`.

    This way, we can configure additional properties, such as the `metadata.labels`.

## Verify Managed Resource Creation

Verify the reconciliation status when you finish creating the Crossplane resources.

```sh
kubectl get resourcegroup,mongocollection,mongodatabase,account
```

Which should yield something like this:

```sh
NAME                                                            READY   SYNCED   EXTERNAL-NAME         AGE
resourcegroup.azure.upbound.io/my-mongodb-instance              True    True     my-mongodb-instance   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME         AGE
mongocollection.cosmosdb.azure.upbound.io/my-mongodb-instance   True    True     my-mongodb-instance   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME         AGE
mongodatabase.cosmosdb.azure.upbound.io/my-mongodb-instance     True    True     my-mongodb-instance   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME         AGE
account.cosmosdb.azure.upbound.io/my-mongodb-instance           True    True     my-mongodb-instance   26h
```

When all the resources are ready, the secret for your claim (the _MongoDBInstance_) is created,
and the claim is set to ready.

You can wait for this to happen with this `kubectl wait` command.

```sh
kubectl wait --for=condition=ready \
  mongodbinstances.azure.ref.services.apps.tanzu.vmware.com ${INSTANCE_NAME} \
   --timeout=400s
```

## Next Steps

!!! Success

    You can return to the [main guide:material-launch:](./index.md#once-resources-are-ready) to continue with the Services Toolkit sections.

    You should come back for the cleanup commands; see below.

## Cleanup Resources

!!! Danger

    These commands delete the resources in Azure.

    Crossplane uses finalizers on its resources.
    This ensures that the `kubectl delete` blocks until it confirms
    the resources are removed at the provider level.

```sh
kubectl delete mongodbinstance ${INSTANCE_NAME} || true
kubectl delete MongoDatabase -l crossplane.io/claim-name=${INSTANCE_NAME} || true
kubectl delete MongoCollection -l crossplane.io/claim-name=${INSTANCE_NAME} || true
kubectl delete Account -l crossplane.io/claim-name=${INSTANCE_NAME} ||  true
kubectl delete ResourceGroup -l crossplane.io/claim-name=${INSTANCE_NAME} || true
```

```sh
kubectl delete configuration ${CONFIG_NAME} || true
kubectl delete providerconfig.azure.upbound.io default || true
```

And if the provider was installed via this package,
you might want to clean that up as well.

```sh
kubectl delete provider upbound-provider-azure
```

## Explore the XRD and Composition

If you want to take a look at the XRD and Composition,
use the following commands.

To see them in the cluster:

```sh
kubectl get xrd,composition
```

This yields the following:

```sh
NAME                                                                                                                 ESTABLISHED   OFFERED   AGE
compositeresourcedefinition.apiextensions.crossplane.io/xmongodbinstances.azure.ref.services.apps.tanzu.vmware.com   True          True      112m

NAME                                                      AGE
composition.apiextensions.crossplane.io/mongodbinstance   112m
```

For more information, output them as `YAML` via the `-o yaml` flag in your `kubectl` command.
