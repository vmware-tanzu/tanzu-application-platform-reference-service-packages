---
title: Consume MongoDB via Crossplane
description: How to create and consume an Azure MongoDB instance via Crossplane
---

This guide describes using the Services Toolkit to allow Tanzu Application Platform workloads to
consume Azure MongoDB (via CosmosDB).

This particular topic makes use of [Universal Crossplane (UXP)](https://www.upbound.io/products/universal-crossplane) by UpBound to manage resources in Azure.

## Prerequisites

* [UpBound's Universal Crossplane](../../../../../../crossplane/) installed
* [Tanzu Application Platform (TAP)](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install.html) 1.3.0 or higher installed
* [Tanzu CLI with TAP plugins](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-tanzu-cli.html#cli-and-plugin)

!!! Note
    To test the automated binding of external services to applications,
    you need TAP installed.
    In addition, you need the Services Toolkit(STK) resources (_ClusterInstanceClass_, _Claim_),
    created.

    If you want to test the Crossplane bindings without TAP,
    skip the sections creating STK resources. 
    Instead of creating a TAP workload, we have an example **Deployment** (the Kubernetes CR),
    The expected secret is hard coded in the section [Test Claim Without TAP:material-format-section:](#test-claim-without-tap).

## Create service instances that are compatible with Tanzu Application Platform

For the sake of creating a MongoDB instance, we need to construct the following resources:

* Account
* MongoDatabase
* MongoCollection
* Secret containing the connection details in a supported format (Service Bindings)

We also recommend, especially while testing or doing a PoC, creating a specific **Resource Group** for these resources.


!!! Success

    To instantiate the resources, we can either directly create the [Crossplane instances:material-launch:](./consume-instance.md),
    or we can use a [Crossplane package:material-launch:](./consume-package.md) that uses Crossplane's [Compositions](https://crossplane.io/docs/v1.10/concepts/composition.html).

    Once your path of choice has reached the point the resources are created, 
    it will redirect you back here.

## Once Resources Are Ready

Once we have the **MongoDB** instance and the appropriate secret (adhering to Service Bindings), we can create a (STK) **Claim**.

We create the following:

* ClusterInstanceClass
* Reader ClusterRole for Services Toolkit
* ResourceClaim
* TAP workload to test the database instance

## Create a Cluster Instance Class for Azure MongoDB

We will create a generic _class_ of bindable resources.
So applications can be made aware of the specific name of the resources,
or their bindable secret, to claim them.

```sh title="cluster-instance-class.yml"
echo "apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: azure-mongodb
spec:
  description:
    short: azure mongodb
  pool:
    kind: Secret
    group: \"\"
    labelSelector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: azure-mongodb
" > cluster-instance-class.yml
```

```sh
kubectl apply -f cluster-instance-class.yml
```

### Services Toolkit Reader Cluster Role

We make sure the STK controller can read the secrets anywhere.
Feel free to limit this role to specific named resources via the `resourceNames` property.

```sh title="reader-cluster-role.yml"
echo "apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: stk-secret-reader
  labels:
    servicebinding.io/controller: \"true\"
rules:
- apiGroups:
  - \"\"
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
" > reader-cluster-role.yml
```

```sh
kubectl apply -f reader-cluster-role.yml
```

## Discover, Claim, and Bind to an Azure MongoDB instance

First, confirm we have claimable class instances.

```sh
export RESOURCE_NAMESPACE=${UNIQUE_NAME:-"default"}
export RESOURCE_NAME=
```

!!! Hint
    If you use the `instance` path to create the resources,
    the `RESOURCE_NAMESPACE` will be `$UNIQUE_NAME`. Else, it will be `default`.

    If you used the `instance` path, `RESOURCE_NAME` is also `$UNIQUE_NAME`,
    else if you use the package path, it is `$INSTANCE_NAME`.


```sh
tanzu services claimable list --class azure-mongodb \
  -n ${RESOURCE_NAMESPACE}
```

Which should yield:

```sh
NAME                            NAMESPACE              KIND    APIVERSION
trp-mongodb-docs-test-bindable  trp-mongodb-docs-test  Secret  v1
```

We have to create the claim in the namespace of the consuming application.
So set this variable to the namespace where you create TAP workloads.

```sh
export TAP_DEV_NAMESPACE=default
```

We then create the associated resource claim:

=== "Using Tanzu CLI"
    ```sh
    tanzu service claim create azure-mongodb-claim-01 \
    --namespace ${TAP_DEV_NAMESPACE} \
    --resource-name ${RESOURCE_NAME}-bindable \
    --resource-namespace ${RESOURCE_NAMESPACE} \
    --resource-kind Secret \
    --resource-api-version v1
    ```

=== "Using Kubernetes Manifest"
    ```sh title="resource-claim.yml"
    echo "apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ResourceClaim
    metadata:
      name: azure-mongodb-claim-01
      namespace: ${TAP_DEV_NAMESPACE}
    spec:
      ref:
        apiVersion: v1
        kind: Secret
        name: ${RESOURCE_NAME}-bindable
        namespace: ${RESOURCE_NAMESPACE}
    " > resource-claim.yml
    ```

    ```sh
    kubectl apply -f resource-claim.yml
    ```

To verify your claim is ready, you run this command:

```sh
tanzu service claim list -o wide 
```

Which should yield the following:

```sh
NAME                    READY  REASON  CLAIM REF
azure-mongodb-claim-01  True   Ready   services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:azure-mongodb-claim-01
```

You can now claim it with a TAP workload.

### Test Claim With TAP Workload

We can now create a TAP workload that uses our resource claim.

The runtime will fail once or twice as it takes time for the secret with the connection details to be mounted into the container. So wait for  `deployment-0002` or `0003`. 

=== "Tanzu CLI"
    ```sh
    tanzu apps workload create spring-boot-mongo-01 \
      --namespace ${TAP_DEV_NAMESPACE} \
      --git-repo https://github.com/joostvdg/spring-boot-mongo.git \
      --git-branch main \
      --type web \
      --label app.kubernetes.io/part-of=spring-boot-mongo-01 \
      --annotation autoscaling.knative.dev/minScale=1 \
      --build-env BP_JVM_VERSION=17 \
      --service-ref db=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:azure-mongodb-claim-01 \
      --yes
    ```

=== "Kubernetes Manifest"
    ```sh
    echo "apiVersion: carto.run/v1alpha1
    kind: Workload
    metadata:
      labels:
        app.kubernetes.io/part-of: spring-boot-mongo-01
        apps.tanzu.vmware.com/workload-type: web
      name: spring-boot-mongo-01
      namespace: ${TAP_DEV_NAMESPACE}
    spec:
      build:
        env:
        - name: BP_JVM_VERSION
          value: \"17\"
      params:
      - name: annotations
        value:
          autoscaling.knative.dev/minScale: \"1\"
      serviceClaims:
      - name: db
        ref:
          apiVersion: services.apps.tanzu.vmware.com/v1alpha1
          kind: ResourceClaim
          name: azure-mongodb-claim-01
      source:
        git:
          ref:
            branch: main
          url: https://github.com/joostvdg/spring-boot-mongo.git
    " > workload.yml
    ```

    ```sh
    kubectl apply -f workload.yml
    ```

To see the logs:
```sh
tanzu apps workload tail spring-boot-mongo-01
```

To get the status:

```sh
tanzu apps workload get spring-boot-mongo-01
```

Tap creates the deployment when the build and config writer workflows are complete.

To see their pods:

```sh
kubectl get pod -l app.kubernetes.io/part-of=spring-boot-mongo-01
```

Then you can wait for the application to be ready via the `kubectl` CLI.

```sh
kubectl wait --for=condition=ready \
  pod -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-mongo-01 \
  --timeout=180s \
  --namespace ${TAP_DEV_NAMESPACE}
```

Ensure there is only one deployment active:

```sh
kubectl get pod --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-mongo-01
```

Which should list a single deployment with Ready 2/2:

```sh
NAME                                                    READY   STATUS    RESTARTS   AGE
spring-boot-mongo-01-00002-deployment-8cd56bdc8-gb44n   2/2     Running   0          6m11s
```

We then collect the name of the **Pod**or copy it yourself from the command-line output.

```sh
POD_NAME=$(kubectl get pod \
  --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-mongo-01 \
   -o jsonpath="{.items[0].metadata.name}")
```

Continue with [testing the application:material-format-section:](#test-application)

### Test Claim Without TAP

Here's the same application we use as TAP workload, but with a hardcoded **Deployment**.

```sh
kubectl apply -f https://raw.githubusercontent.com/joostvdg/spring-boot-mongo/main/kubernetes/raw/deployment.yaml 
```

As the Deployment is hard coded, it doesn't know the name of your bindable secret.
So let's patch that; first, create a patch file.

```sh title="spring-boot-mongo-deployment-patch.yml"
echo "
---
spec:
  template:
    spec:
      volumes:
      - name: secret-volume
        projected:
          defaultMode: 420
          sources:
          - secret:
              name: "${RESOURCE_NAME}-bindable"
" > spring-boot-mongo-deployment-patch.yml
```

And second, patch the deployment to update the secret name:

```sh
kubectl patch --type merge deploy spring-boot-mongo\
 --patch-file='spring-boot-mongo-deployment-patch.yml' \
 --namespace ${TAP_DEV_NAMESPACE}
```

We wait for the **Pod** to become ***Ready***.

```sh
kubectl wait --for=condition=ready pod \
  --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/name=spring-boot-mongo \
   --timeout=60s
```

Once that happens, we copy the **Pod**'s name to test the application.

```sh
POD_NAME=$(kubectl get pod \
  --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/name=spring-boot-mongo \
   -o jsonpath="{.items[0].metadata.name}")
```

### Test Application

Use the `kubectl` CLI to create a port forward.

```sh
kubectl port-forward pod/${POD_NAME} --namespace ${TAP_DEV_NAMESPACE} 8080
```

And then open another terminal to test the application:

```sh
curl -s "http://localhost:8080"
```

Which should return an empty list `[]`.
Add a value that gets stored in the MongoDB instance.

```sh
curl --header "Content-Type: application/json" \
     --request POST --data '{"name":"Alice"}' \
     http://localhost:8080/create
```

Making another GET request should return the stored entry:

```sh
curl -s "http://localhost:8080"
```

!!! Success
    We have gone through all the steps. You can now clean up all the resources.

## Cleanup

```sh
kubectl delete ResourceClaim azure-mongodb-claim-01 \
  --namespace ${TAP_DEV_NAMESPACE}
```

=== "TAP Workload"

    ```sh
    kubectl delete workload spring-boot-mongo-01
    ```

=== "Deployment without TAP"

    ```sh
    kubectl delete deploy spring-boot-mongo || true
    ```

Once you have cleaned up the resources related to this guide,
visit the specific sub-guides for their cleanup commands.

* [Via Crossplane instances:material-launch:](./consume-instance.md#cleanup) cleanup commands
* [Via Crossplane package:material-launch:](./consume-package.md#cleanup-resources) cleanup commands
