---
title: Via Crossplane Instances
description: How to create an Azure MongoDB instance via Crossplane
---

To create a MongoDB instance in Azure, we need the following resources:

* ResourceGroup
* CosmosDB Account
* MongoDatabase
* MongoCollection

We will show you how to create all of them with Crossplane's 
[official Azure provider](https://marketplace.upbound.io/providers/upbound/provider-azure/).

!!! important
    We suggest defining a unique name for the resources to avoid potential conflicts.
    This is because we need the **Resource Group** and the CosmosDB **Account** names to be globally unique (within Azure).

    ```sh
    export UNIQUE_NAME=
    ```

    We must set a ***location*** where Azure creates the resources.
    As a default, we use `West Europe`, but feel free to change this.

    ```sh
    export LOCATION="West Europe"
    ```

   The examples help you create the files with the `UNIQUE_NAME`
    and `LOCATION` values are inserted in the places that matter.

## Pre-requisites

* [UpBound's Universal Crossplane](../../../../../../crossplane/)
* [Crossplane Azure Provider](../../../../../../crossplane/providers/azure/)
* [SecretGen Controller](../../../../prerequisites/#secretgen-controller): to transform the secret from Crossplane to the [Service Binding](https://servicebinding.io/) specification

### Verify Provider

```sh
kubectl api-resources --api-group cosmosdb.azure.upbound.io
```

This gives us the following APIs:

```sh
NAME                   SHORTNAMES   APIVERSION                          NAMESPACED   KIND
accounts                            cosmosdb.azure.upbound.io/v1beta1   false        Account
cassandraclusters                   cosmosdb.azure.upbound.io/v1beta1   false        CassandraCluster
cassandradatacenters                cosmosdb.azure.upbound.io/v1beta1   false        CassandraDatacenter
cassandrakeyspaces                  cosmosdb.azure.upbound.io/v1beta1   false        CassandraKeySpace
cassandratables                     cosmosdb.azure.upbound.io/v1beta1   false        CassandraTable
gremlindatabases                    cosmosdb.azure.upbound.io/v1beta1   false        GremlinDatabase
gremlingraphs                       cosmosdb.azure.upbound.io/v1beta1   false        GremlinGraph
mongocollections                    cosmosdb.azure.upbound.io/v1beta1   false        MongoCollection
mongodatabases                      cosmosdb.azure.upbound.io/v1beta1   false        MongoDatabase
sqlcontainers                       cosmosdb.azure.upbound.io/v1beta1   false        SQLContainer
sqldatabases                        cosmosdb.azure.upbound.io/v1beta1   false        SQLDatabase
sqlfunctions                        cosmosdb.azure.upbound.io/v1beta1   false        SQLFunction
sqlroleassignments                  cosmosdb.azure.upbound.io/v1beta1   false        SQLRoleAssignment
sqlroledefinitions                  cosmosdb.azure.upbound.io/v1beta1   false        SQLRoleDefinition
sqlstoredprocedures                 cosmosdb.azure.upbound.io/v1beta1   false        SQLStoredProcedure
sqltriggers                         cosmosdb.azure.upbound.io/v1beta1   false        SQLTrigger
tables                              cosmosdb.azure.upbound.io/v1beta1   false        Table
```

We also recommend, especially while testing or doing a PoC, creating a specific **Resource Group** for these resources.

The **Resource Group** API is part of the `azure.upbound.io` API group.

```sh
kubectl api-resources --api-group azure.upbound.io
``` 

As you can see:

```sh
NAME                            SHORTNAMES   APIVERSION                  NAMESPACED   KIND
providerconfigs                              azure.upbound.io/v1beta1    false        ProviderConfig
providerconfigusages                         azure.upbound.io/v1beta1    false        ProviderConfigUsage
resourcegroups                               azure.upbound.io/v1beta1    false        ResourceGroup
resourceproviderregistrations                azure.upbound.io/v1beta1    false        ResourceProviderRegistration
storeconfigs                                 azure.upbound.io/v1alpha1   false        StoreConfig
subscriptions                                azure.upbound.io/v1beta1    false        Subscription
```

## Create Namespace

There are some places where we need to provide the name of the namespace.

For the convenience of this example, we create a namespace with the same name.

```sh
kubectl create namespace ${UNIQUE_NAME}
```

## Create Resource Group

We create a **ResourceGroup** with a unique name and label it.
This is because some of the managed resources (i.e., the resources in Azure) depend
on other managed resources.

To find them, we must instruct Crossplane, which Crossplane resource
maps to the dependent managed resource. For this, we use the label.

```sh title="resourcegroup.yml"
echo "apiVersion: azure.upbound.io/v1beta1
kind: ResourceGroup
metadata:
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
  labels:
    testing.upbound.io/example-name: ${UNIQUE_NAME}
spec:
  forProvider:
    location: ${LOCATION}
  providerConfigRef:
    name: default
" > resourcegroup.yml
```

And now, you can apply the file to create the Crossplane resource.
Again, the Crossplane controller and the Azure provider controller
will ensure the resource in Azure exists and the status
is visible on our Crossplane resource in Kubernetes.

```sh
kubectl apply -f resourcegroup.yml
```

## Create CosmosDB Account

Next on the list is the CosmosDB **Account**.
This object defines the initial configuration of the **MongoDB** instance.

You make this **Account** a **MongoDB** instance by setting the capability `EnableMongo`.
If you want to set a specific version, use the `spec.forProvider.mongoServerVersion` parameter.

```sh title="account.yml"
echo "apiVersion: cosmosdb.azure.upbound.io/v1beta1
kind: account
metadata:
  annotations:
    meta.upbound.io/example-id: cosmosdb/v1beta1/mongocollection
  labels:
    testing.upbound.io/example-name: ${UNIQUE_NAME}
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
spec:
  forProvider:
    capabilities:
      - name: EnableMongo
      - name: mongoEnableDocLevelTTL
    consistencyPolicy:
      - consistencyLevel: Strong
    geoLocation:
      - failoverPriority: 0
        location: ${LOCATION}
    kind: MongoDB
    location: ${LOCATION}
    offerType: Standard
    resourceGroupNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
  writeConnectionSecretToRef:
    namespace: ${UNIQUE_NAME}
    name: ${UNIQUE_NAME}
" > account.yml
```

Create the file and apply it to the cluster.

```sh
kubectl apply -f account.yml
```

!!! info
    The **Account** requires a reference to a **Resource Group**.

    We do so via the `resourceGroupNameSelector`:

    ```yaml
    resourceGroupNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
    ```

## Create Mongo Database

Now that we have an **Account** that manages a **MongoDB** instance,
we can create a MongoDB **Database** in the Account.

```sh title="database.yml"
echo "apiVersion: cosmosdb.azure.upbound.io/v1beta1
kind: MongoDatabase
metadata:
  annotations:
    meta.upbound.io/example-id: cosmosdb/v1beta1/mongocollection
  labels:
    testing.upbound.io/example-name: ${UNIQUE_NAME}
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
spec:
  forProvider:
    accountNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
    resourceGroupNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
" > database.yml
```

```sh
kubectl apply -f database.yml
```

## Create Mongo Collection

In the MongoDB **Database**, we want to have at least one **Collection**
([read more about Database and Collection](https://www.mongodb.com/docs/manual/core/databases-and-collections/)).

All the same rules as before apply.
We define the resource's properties and then reference the dependencies.

```sh title="collection.yml"
echo "apiVersion: cosmosdb.azure.upbound.io/v1beta1
kind: MongoCollection
metadata:
  annotations:
    meta.upbound.io/example-id: cosmosdb/v1beta1/mongocollection
  labels:
    testing.upbound.io/example-name: ${UNIQUE_NAME}
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
spec:
  forProvider:
    defaultTtlSeconds: 777
    index:
    - keys:
      - _id
      unique: true
    shardKey: uniqueKey
    throughput: 400
    accountNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
    databaseNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
    resourceGroupNameSelector:
      matchLabels:
        testing.upbound.io/example-name: ${UNIQUE_NAME}
" > collection.yml
```

And as always, we apply the resource to the cluster
and let Crossplane work its magic.

```sh
kubectl apply -f collection.yml
```

## Verify Managed Resource Creation

Create the Crossplane resources and then verify the resources have a successful reconciliation.

```sh
kubectl get resourcegroup,mongocollection,mongodatabase,account \
    --namespace ${UNIQUE_NAME}
```

This should yield something like this: (where `trp-cosmosdb-mongo-01` will be your `$UNIQUE_NAME`)

```sh
NAME                                                            READY   SYNCED   EXTERNAL-NAME           AGE
resourcegroup.azure.upbound.io/trp-cosmosdb-mongo-01            True    True     trp-cosmosdb-mongo-01   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME           AGE
mongocollection.cosmosdb.azure.upbound.io/trp-cosmosdb-mongo-01 True    True     trp-cosmosdb-mongo-01   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME           AGE
mongodatabase.cosmosdb.azure.upbound.io/trp-cosmosdb-mongo-01   True    True     trp-cosmosdb-mongo-01   26h

NAME                                                            READY   SYNCED   EXTERNAL-NAME           AGE
account.cosmosdb.azure.upbound.io/trp-cosmosdb-mongo-01         True    True     trp-cosmosdb-mongo-01   26h
```

To use the **MongoDB** instance from our application, we need to bind the connection details.

The secret generated by Crossplane via the `writeConnectionSecretToRef` does not use the expected syntax.
So we use the SecretGen controller with a `SecretTemplate` to generate a secret that does.

## Create a connection details secret

The Services Toolkit needs a Kubernetes Secret with a format that adheres to the [Service Binding](https://servicebinding.io/) specification.

Unfortunately, the secret that the **Account** manage resource generates does not conform.
We use a **SecretTemplate** that maps the **Account** secret to a secret usable by the automatic binding.

### SecretGen RBAC permissions

The **SecretGen Controller** needs permissions in the secret's namespace.
So we create a `ServiceAccount` with the appropriate permissions and then the `SecretTemplate`.

```sh title="secretgen-rbac.yml"
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-gen-reader
  namespace: ${UNIQUE_NAME}
rules:
- apiGroups:
  - \"\"
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
  resourceNames:
  - ${UNIQUE_NAME}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${UNIQUE_NAME}-role-binding
  namespace: ${UNIQUE_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: secret-gen-reader
subjects:
- kind: ServiceAccount
  name: ${UNIQUE_NAME}
  namespace: ${UNIQUE_NAME}
" > secretgen-rbac.yml
```

```sh
kubectl apply -f secretgen-rbac.yml
```

### Secret Template

And then we can create a **SecretTemplate** that transforms the secret from the Crossplane **Account**
to a secret that the Services Toolkit can bind.

```sh title="secret-template.yml"
echo "apiVersion: secretgen.carvel.dev/v1alpha1
kind: SecretTemplate
metadata:
  name: ${UNIQUE_NAME}-bindable
  namespace: ${UNIQUE_NAME}
spec:
  serviceAccountName: ${UNIQUE_NAME}
  inputResources:
  - name: creds
    ref:
      apiVersion: v1
      kind: Secret     
      name: ${UNIQUE_NAME}
  template:
    metadata:
      labels:
        app.kubernetes.io/component: ${UNIQUE_NAME}
        app.kubernetes.io/instance: ${UNIQUE_NAME}
        services.apps.tanzu.vmware.com/class: azure-mongodb
    type: mongodb
    stringData:
      type: mongodb
      database: ${UNIQUE_NAME}
    data:
      uri: '\$(.creds.data.attribute\\.connection_strings\\.0)'
" > secret-template.yml
```

```sh
kubectl apply -f secret-template.yml
```

!!! Warning "Resource Claim Policy"
    If we create our Claim in one namespace and the claimable resource in another,
    we need a **ResourceClaimPolicy**.

    See below how to create one!

We verify the SecretTemplate's secret exists by running the following command:

```sh
kubectl get secret -n $UNIQUE_NAME
```

This should give you two secrets: (where `trp-mongodb-docs-test` will be your `$UNIQUE_NAME`)

```sh
NAME                             TYPE                                DATA   AGE
trp-mongodb-docs-test            connection.crossplane.io/v1alpha1   8      24m
trp-mongodb-docs-test-bindable   mongodb                             3      94s
```

## ResourceClaim Policy (optional)

We determine the Developer namespace
configured in the Tanzu Application Platform (TAP) installation.
If in doubt, assume it is `default`.

```sh
export TAP_DEV_NAMESPACE=default
```

Then you create a **ResourceClaimPolicy** ensuring applications deployed in TAP
can use the Service Toolkit claim.

```sh title="resource-claim-policy.yml"
echo "apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaimPolicy
metadata:
  name: default-can-claim-azure-mongodb
  namespace: ${UNIQUE_NAME}
spec:
  subject:
    kind: Secret
    group: \"\"
    selector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: azure-mongodb
  consumingNamespaces: [ \"${TAP_DEV_NAMESPACE}\" ] 
" > resource-claim-policy.yml
```

Verify the status of the **ResourceClaimPolicy**:

```sh
kubectl apply -f resource-claim-policy.yml -n ${UNIQUE_NAME}
```

## Next Steps

!!! Success

    You can return to the [main guide:material-launch:](./index.md#once-resources-are-ready) to continue with the Services Toolkit sections.

    You should come back for the cleanup commands; see below.

## Cleanup

!!! Danger

    These commands delete the resources in Azure.

    Crossplane uses finalizers on its resources.
    This ensures that the `kubectl delete` blocks until it confirms
    the resources are removed at the provider level.

```sh
kubectl delete -f resource-claim-policy.yml || true
kubectl delete -f secret-template.yml || true
kubectl delete -f collection.yml || true
kubectl delete -f database.yml || true
kubectl delete -f account.yml || true
kubectl delete -f resourcegroup.yml || true
kubectl delete namespace ${UNIQUE_NAME} || true
```

!!! Warning
    If you are done with this Crossplane Provider,
    or want to try out the Crossplane package solution,
    you have to delete the **Provider** and **ProviderConfig** resources as well.

!!! Info
    **ProviderConfig** resources are owned by the **Provider** installed at the time.
    So installing the Azure Provider again via a package dependency, for example,
    would be blocked because the **ProviderConfig** is owned by the previous **Provider** installation.

    Resources, such as the MongoDB Database, using the **ProviderConfig** block its deletion.
    
    A **ProviderConfig** resource belongs to the **Provider** and has a unique _Group_.
    So to avoid possible conflicts with other **ProviderConfigs**, we delete it via its full name.
    
    ```sh
    kubectl delete providerconfigs.azure.upbound.io default
    kubectl delete providers.pkg.crossplane.io upbound-provider-azure
    ```
