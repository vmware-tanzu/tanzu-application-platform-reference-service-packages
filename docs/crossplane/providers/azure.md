---
title: UXP Azure provider
description: How to install and configure Upbound's Crossplane Azure provider
Hero: Install Crossplane UXP Azure provider
---

Upbound's Azure Provider is an Azure provider for Crossplane that is developed and supported by Upbound.

It can be deployed on top of a Kubernetes cluster with Crossplane using the Upbound CLI
(see [here](../index.md) for details about installation) or a YAML manifest.

## Installation

You can check available releases on [project's GitHub repository](https://github.com/upbound/provider-azure/releases)
or using [`gh`](https://cli.github.com/) like

```sh
gh release list --repo upbound/provider-azure
```

Store the desired release in the `PROVIDER_AZURE_RELEASE` variable.

!!! Note
    === "Upbound CLI"
        Do make sure you have installed the `up` CLI, as described [here](../index.md), and execute
        ```sh
        up controlplane provider install xpkg.upbound.io/upbound/provider-azure:${PROVIDER_AZURE_RELEASE}
        ```

    === "YAML manifest"
        ```sh
        kubectl apply -f - <<EOF
        apiVersion: pkg.crossplane.io/v1
        kind: Provider
        metadata:
          name: provider-azure
        spec:
          package: xpkg.upbound.io/upbound/provider-azure:${PROVIDER_AZURE_RELEASE}
        EOF
        ```

Ensure the provider is installed and healthy by running the following:

```sh
kubectl get provider
```

Which should yield something like the following:

```sh
NAME             INSTALLED   HEALTHY   PACKAGE                                          AGE
provider-azure   True        True      xpkg.upbound.io/upbound/provider-azure:v0.17.0   2m35s
```

Before we can use the provider, we need to supply it with credentials.
We can use a **Service Provider** or a **Managed Service Identity**.

### Verify Provider

The installation of the Crossplane Azure provider results in the availability of
new Kubernetes APIs for interacting with Azure resources from within the TAP cluster.

The total number of available resources is relatively high,
so let us focus on the resources related to CosmosDB.

```sh
kubectl api-resources --api-group cosmosdb.azure.upbound.io
```

Running this command prints the following APIs:

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

## Create & Configure Service Provider

Before proceeding, we need an Azure subscription, an Azure account with sufficient privileges, and the `az` (Azure) CLI.
You can find how to install the CLI [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

Login to Azure via its CLI (`az`).

```sh
az login
```

If you're not sure about your subscription id, you can run the following command:

```sh
az account show --query "{subscriptionId:id, tenantId:tenantId}"
```

```sh
SUBSCRIPTION_ID=
```

Then create a Service Principle (`sp`), which has sufficient permissions to create all the necessary resources in Azure.

For example:

```sh
az ad sp create-for-rbac \
  --sdk-auth \
  --role Owner \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}"
```

!!! warning
    You probably do not want to give it the role `Owner` if this is a production account.

Save the output as `azure-credentials.json` and create a Kubernetes secret in the `upbound-system` (assuming you use **uxp**).

```sh
kubectl create secret generic azure-secret \
  -n upbound-system \
  --from-file=creds=./azure-credentials.json
```

We then create a `ProviderConfig`, pointing to this credential.

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

## Create & Configure Managed Service Identity

*TBD*