---
title: Consuming Postgresql Multicloud
---

## Why Multicloud

There are various reasons why companies are running applications in multiple clouds.
We count data centers as local or private clouds.

It is increasingly common for companies to run Kubernetes clusters in multiple locations - some clusters in the data center and others in AWS, for example.

When (service) consumers do not care about the specific performance parameters of a database, you can simplify onboarding and relocation pain by providing a generic API.

This package is an example of such a generic API.
It holds as long as the consumers want _a database_ and there is no need (yet) to fine-tune it.

Good examples are PoCs, preview environments, or applications where the performance bottleneck lies elsewhere.

## Pre-requisites

This package supports three platforms; Kubernetes, Azure, and AWS.
Therefore, we split the prerequisites into shared requirements and cloud-specific (Azure and AWS, respectively).

### Shared

!!! Warning "Terraform provider configuration included"
    The package creates a **ProviderConfig** for the Terraform provider for you. To ensure it is unique, it has the UID from Composite Resource (`XPostgreSQLInstance`) as the name.

    So when installing the **Terraform Provider** (to meet the prerequisites), there is no need to create a **ProviderConfig**.

* Kubernetes 1.23+
* [Crossplane 1.10+](/tanzu-application-platform-reference-service-packages/crossplane/)
* [Crossplane Kubernetes provider (Community)](/tanzu-application-platform-reference-service-packages/crossplane/providers/kubernetes/)
* [Crossplane Terraform provider (Upbound official)](/tanzu-application-platform-reference-service-packages/crossplane/providers/terraform/)

### Kubernetes

* [Crossplane Helm provider (Community)](/tanzu-application-platform-reference-service-packages/crossplane/providers/helm/)

### Azure

When wanting to consume the Azure FlexibleServer variant, you also need the following:

* Azure credentials
* [Crossplane Azure provider (Upbound official)](/tanzu-application-platform-reference-service-packages/crossplane/providers/azure/)

### AWS

* AWS credentials
* [Crossplane AWS provider (Upbound official)](/tanzu-application-platform-reference-service-packages/crossplane/providers/aws/)

## Install Crossplane Package

We start by setting some environment variables and installing our Crossplane package (Configuration CR).

```sh
CONFIG_NAME="trp-multicloud-psql"
CONFIG_IMAGE="ghcr.io/vmware-tanzu-labs/trp-multicloud-psql"
CONFIG_VERSION="0.1.0-rc-4"
CROSSPLANE_NAMESPACE="upbound-system"
```

```sh
cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: ${CONFIG_NAME}
spec:
  ignoreCrossplaneConstraints: true
  package: ${CONFIG_IMAGE}:${CONFIG_VERSION}
  packagePullPolicy: Allways
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 3
  skipDependencyResolution: true
EOF
```

We then wait until the Configuration object is healthy.

```sh
kubectl wait --for=condition=Healthy configuration ${CONFIG_NAME}
```

Verify the configuration exists and is valid.

```sh
kubectl get configuration
```

You can debug the installation if something is wrong via the ConfigurationRevision object(s).

```sh
kubectl describe configurationrevisions.pkg.crossplane.io
```

## Create Crossplane Claim

The package contains four Crossplane Compositions or four implementations.

The supported implementations are:

* **Helm**: installs and configures a [Bitnami PostgreSQL](https://artifacthub.io/packages/helm/bitnami/postgresql) helm chart install
* **FlexibleServer**: creates and configures an Azure FlexibleServer with Postgresql, including a firewall rule, a database, and a **ResourceGroup**
* **RDS Private**: creates and configures an AWS RDS instance, which is only available within the configured VPC
* **RDS Public**:  creates and configures an AWS RDS instance, which is publicly available, and does this by creating more AWS network resources (not recommended)

### Helm

First, define the name of the claim, the crossplane namespace, and the storage class to use.

```sh
CLAIM_NAME="postgresql-0001"
STORAGE_CLASS="default"
```

We can then create the Crossplain CR to claim (or request) an instance:

Notice the highlighted lines.
That is how we select which one of the four implementations we request.

```sh hl_lines="10 11 12"
cat <<EOF | kubectl apply -f -
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  namespace: default
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: helm
  parameters:
    location: local
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: ${STORAGE_CLASS}
EOF
```

!!! Tip
    Make sure you update the `STORAGE_CLASS` variable to a storage class available in your cluster.

    To get a list of available storage classes, run the following:

    ```sh
    kubectl get storageclass
    ```

!!! Success
    
    Verify the claim exists:

    ```sh
    kubectl get postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com $CLAIM_NAME
    ```

    It should return something like this:

    ```sh
    NAME              ADDRESS                                                        LOCATION         VERSION   CONNECTION-DETAILS   SYNCED   READY   CONNECTION-SECRET   AGE
    postgresql-0001   postgresql-0001-cmrpp-84lrw.upbound-system.svc.cluster.local   upbound-system   12.13.0                        True     False                       85s
    ```

    You can continue with [Verify Package Installation](#verify-package-installation).

### FlexibleServer (Azure)

First, define the name of the claim, the crossplane namespace, and the storage class to use.

```sh
CLAIM_NAME="postgresql-0001"
LOCATION="West Europe"
```

And then create the Crossplane claim.

```sh hl_lines="9 10 11"
cat <<EOF | kubectl apply -f -
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: azure
  parameters:
    location: ${LOCATION}
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: "default"
    firewallRule:
      startIpAddress: "0.0.0.0"
      endIpAddress: "255.255.255.255"
EOF
```

!!! Warning "Public instance"
    The firewall rule, in the claim, is a "special" rule.
    If defined like this, Azure will make the instance public for the whole internet.

    ```yaml
    firewallRule:
      startIpAddress: "0.0.0.0"
      endIpAddress: "255.255.255.255"
    ```

    There is another distinctive case.
    If you want the instance to be accessible _only_ within Azure, use the following:

    ```yaml
    firewallRule:
      startIpAddress: "0.0.0.0"
      endIpAddress: "0.0.0.0"
    ```

To take a look at the Crossplane managed resources for Azure, you can run the command below:

```sh
kubectl get resourcegroups.azure.upbound.io,flexibleserverdatabases.dbforpostgresql.azure.upbound.io,flexibleserverfirewallrules.dbforpostgresql.azure.upbound.io,flexibleservers.dbforpostgresql.azure.upbound.io
```

!!! Success
    
    Verify the claim exists

    ```sh
    kubectl get postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com $CLAIM_NAME
    ```

    It should return something like this:

    ```sh
    NAME              ADDRESS                                                        LOCATION         VERSION   CONNECTION-DETAILS   SYNCED   READY   CONNECTION-SECRET   AGE
    postgresql-0001   postgresql-0001-cmrpp-84lrw.upbound-system.svc.cluster.local   upbound-system   12.13.0                        True     False                       85s
    ```

    You can continue with [Verify Package Installation](#verify-package-installation).

### RDS - Private  (AWS)

!!! Info
    With the Azure FlexibleServer, we can get away with configuring the firewall rule.

    The AWS network configuration is more complex and involves more resources.
    So we decided to split them into two separate Compositions.

The RDS Private implementation generates a minimal amount of AWS resources.
This works in a Kubernetes cluster (such as EKS) within the same VPC and Subnet Group.

Define the name of the claim, the crossplane namespace, and the AWS networking config (VPC and Subnet Group).

```sh
CLAIM_NAME="postgresql-0001"
LOCATION="eu-central-1"
VPC_ID=""
SUBNET_GROUP_NAME=""
```

Because the AWS provider has two implementations (private and public), we use a second label, as you can see in the highlighted labels.

```sh hl_lines="9 10 11 12"
cat <<EOF | kubectl apply -f -
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: aws
      connectivity: "private"
  parameters:
    location: ${LOCATION}
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: gp2
    aws:
      vpcId: ${VPC_ID}
      dbSubnetGroupName: ${SUBNET_GROUP_NAME}
      cidrBlocks:
        - 0.0.0.0/0
EOF
```

In addition to using an existing VPC and SubnetGroup specified, the package also creates the following AWS resources:

* Security Group
* Security Group Rule
* RDS Instance

!!! Success
    
    Verify the claim exists:

    ```sh
    kubectl get postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com $CLAIM_NAME
    ```

    It should return something like this:

    ```sh
    NAME              ADDRESS                                                        LOCATION         VERSION   CONNECTION-DETAILS   SYNCED   READY   CONNECTION-SECRET   AGE
    postgresql-0001   postgresql-0001-cmrpp-84lrw.upbound-system.svc.cluster.local   upbound-system   12.13.0                        True     False                       85s
    ```

    You can continue with [Verify Package Installation](#verify-package-installation).


### RDS - Public (AWS)

The RDS Public implementation generates all the additional AWS networking resources to enable public (outside of AWS) access to the RDS instance.

Define the name of the claim, the crossplane namespace, and the AWS networking config.

```sh
CLAIM_NAME="postgresql-0001"
LOCATION="eu-central-1"
VPC_ID=""
SUBNET_GROUP_NAME=""
INTERNET_GATEWAY_ID=""
SUBNET_A_CIDR=""
SUBNET_B_CIDR=""
```

For public access, we need additional AWS resources.
Due to the complexities and permissions involved, the package requires the **(Internet) Gateway** for the specified **VPC** to exist.

```sh hl_lines="12 24 25 26 27"
cat <<EOF | kubectl apply -f -
apiVersion: multi.ref.services.apps.tanzu.vmware.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: ${CLAIM_NAME}
  labels:
    services.apps.tanzu.vmware.com/claimable: "true"
spec:
  compositionSelector:
    matchLabels:
      provider: aws
      connectivity: "public"
  parameters:
    location: ${LOCATION}
    version: "12"
    database: demo
    collation: en_GB.utf8
    storageClass: gp2
    aws:
      vpcId: ${VPC_ID}
      dbSubnetGroupName: ${SUBNET_GROUP_NAME}
      cidrBlocks:
        - 0.0.0.0/0
      public:
        gatewayId: ${INTERNET_GATEWAY_ID}
        subnetACidrBlock: ${SUBNET_A_CIDR}
        subnetBCidrBlock: ${SUBNET_B_CIDR}
EOF
```

In addition to using an existing VPC and SubnetGroup specified, the package also creates the following AWS resources:

* Security Group
* Security Group Rule
* RDS Instance
* Route Table
* 2x Subnet (Subnet A and Subnet B)
* Route Table Association (one for each Subnet)
* Route

!!! Important
    As we cannot know what CIDR blocks your **Gateway** supports, we ask you to specify them.
    
    For example, we have a **Gateway** with `10.100.0.0/16`.
    To limit the range we give to the **Subnets**, we break the `10.100.255.0` in half (via `/25`).

    ```yaml
    public:
        gatewayId: ${INTERNET_GATEWAY_ID}
        subnetACidrBlock: "10.100.255.0/25"
        subnetBCidrBlock: "10.100.255.128/25"
    ```

!!! Success
    
    Verify the claim exists:

    ```sh
    kubectl get postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com $CLAIM_NAME
    ```

    It should return something like this:

    ```sh
    NAME              ADDRESS                                                        LOCATION         VERSION   CONNECTION-DETAILS   SYNCED   READY   CONNECTION-SECRET   AGE
    postgresql-0001   postgresql-0001-cmrpp-84lrw.upbound-system.svc.cluster.local   upbound-system   12.13.0                        True     False                       85s
    ```

    You can continue with [Verify Package Installation](#verify-package-installation).

### Verify Package Installation

Among other resources, this package creates the following:

* **ProviderConfig**: it uses the Terraform provider to generate a unique password. To save you the trouble, it configures the provider for you
* **PostgresqlInstances**: the claim type. You can track the end state of your request via this resource
* **XPostgresqlInstances**: the workhorse behind the scenes for the claim type. It tracks all the Kubernetes CRs related to the Claim request and is your best resource for debugging

```sh
kubectl get providerconfig,xpostgresqlinstances,postgresqlinstances
```

We assume our package always works, so run the following command to wait for it to be ready:

```sh
kubectl wait --for=condition=ready \
    postgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME} \
     --timeout=400s
```

!!! Failure "Wait times out"
    If the wait command times out, you can debug the cause via the **Composite Resource** (the X<ClaimNam> resource from Crossplane).

    ```sh
    kubectl describe xpostgresqlinstances.multi.ref.services.apps.tanzu.vmware.com/${CLAIM_NAME}
    ```

!!! Failure "Cannot render composed resource"
    If you get a warning like this in the **Composite Resource**:

    ```sh
    cannot render composed resource from resource template at index 1: cannot use dry-run create to name composed resource: workspaces.tf.crossplane.io is forbidden: User "system:serviceaccount:upbound-system:crossplane" cannot create resource "workspaces" in API group "tf.crossplane.io" at the cluster scope
    ```

    Sometimes the service account of Crossplane or a Crossplane Provider does not have enough permissions to create the resources.
    You can either fix this quickly and dirty (for PoCs) like below:

    ```sh
    kubectl create clusterrolebinding crossplane-admin-binding --clusterrole cluster-admin --serviceaccount="upbound-system:crossplane" || true   
    ```

    Or find the Service Account for the specific provider (they have generated names) and update its RBAC configuration concisely.

    ```sh
    SA=$(kubectl -n upbound-system get sa -o name | grep provider-terraform | sed -e 's|serviceaccount\/|upbound-system:|g')   
    ```

!!! Success
    If the wait commands returns with `Conditions met`, the package is ready.

    You can now continue with [test without TAP](#test-withouth-tap) or [test with TAP and STK](#test-with-tap-stk).

## Test Without TAP

Tanzu Application Platform (TAP) and the Services Toolkit (STK) are great tools for usage at scale.
It can be rather cumbersome to test a single service package.

So below is an example of a Kubernetes deployment that directly consumes the secret created by Crossplane.
It uses the [Service Bindings](https://servicebinding.io/) specification (Spring library) to translate the secret to the parameters needed by the database API.

### Install the Test application

```sh hl_lines="21 22 23 39 40 41 42 49"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spring-boot-postgres
  labels:
    app.kubernetes.io/name: spring-boot-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: spring-boot-postgres
  template:
    metadata:
      labels:
        app.kubernetes.io/name: spring-boot-postgres
    spec:
      containers:
        - name: spring-boot-postgres
          image: joostvdgtanzu/spring-boot-postgres-01:0.1.0
          env:
            - name: SERVICE_BINDING_ROOT
              value: "/bindings"
          ports:
            - containerPort: 8080
              name: http-web-svc
          livenessProbe:
            httpGet:
              port: 8080
              path: /actuator/health/liveness
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
          readinessProbe:
            httpGet:
              port: 8080
              path: /actuator/health/readiness
            initialDelaySeconds: 10
          volumeMounts:
            - mountPath: /bindings/db
              name: secret-volume
              readOnly: true
      volumes:
        - name: secret-volume
          projected:
            defaultMode: 420
            sources:
              - secret:
                  name: postgresql-0001
EOF
```

### Verify test application installation

Verify the deployment is applied correctly:

```sh
kubectl get deployment
```

If so, then you can wait on the application to be ready:

```sh
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=spring-boot-postgres \
    --timeout=300s
```

### Test database connection via application

As it can be complicated to deal with all the ways a service in Kubernetes can be exposed, we resort to `kubectl port-forward`.

Make sure you have two terminals (or tabs) open.
Run this in terminal one:

```sh
kubectl port-forward deployment/spring-boot-postgres 8080
```

And now, run this in terminal two:

```sh
curl -s "http://localhost:8080"
```

```sh
curl --header "Content-Type: application/json" \
     --request POST --data '{"name":"Piet"}'\
     http://localhost:8080/create
```

```sh
curl -s "http://localhost:8080"
```

You should see an empty result in the first call and a response with the name you specified in the second call in the final curl request.

### Delete deployment

```sh
kubectl delete deployment spring-boot-postgres
```

## Test with TAP & STK

Once we have the **Postgresql** instance and the appropriate secret (adhering to Service Bindings), we can create an (STK) **Claim**.

We create the following:

* ClusterInstanceClass
* Reader ClusterRole for Services Toolkit
* ResourceClaim
* TAP workload to test the database instance

### Create a Cluster Instance Class

We will create a generic _class_ of bindable resources.
So applications can be made aware of the specific name of the resources,
or their bindable secret, to claim them.

The multicloud package gives each composition several labels you can filter on.
You can create instance classes o

!!! Info
    The included (at this time of writing) labels are:

    * `services.apps.tanzu.vmware.com/class`: this is a static label and always says `multicloud-psql`
    * `services.apps.tanzu.vmware.com/infra`: this is a dynamic label [`Kubernetes`, `Azure`, `AWS`]
    * `services.apps.tanzu.vmware.com/location`: this is a dynamic label and depends on the `location` parameter when creating the Crossplane **claim**
    * `services.apps.tanzu.vmware.com/version`: this is a dynamic label and depends on the `version` parameter when creating the Crossplane **claim**


=== "For any multicloud-psql"
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ClusterInstanceClass
    metadata:
      name: multi-psql
    spec:
      description:
        short: multi psql
      pool:
        kind: Secret
        group: ""
        labelSelector:
          matchLabels:
            services.apps.tanzu.vmware.com/class: multicloud-psql
    EOF
    ```

=== "Limit to Kubernetes based"
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ClusterInstanceClass
    metadata:
      name: multi-psql-kubernetes
    spec:
      description:
        short: multicloud psql
      pool:
        kind: Secret
        group: ""
        labelSelector:
          matchLabels:
            services.apps.tanzu.vmware.com/class: multicloud-psql
            services.apps.tanzu.vmware.com/infra: kubernetes
    EOF
    ```

=== "Limit to Version 12"
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ClusterInstanceClass
    metadata:
      name: multi-psql-kubernetes-v12
    spec:
      description:
        short: multicloud psql
      pool:
        kind: Secret
        group: ""
        labelSelector:
          matchLabels:
            services.apps.tanzu.vmware.com/class: multicloud-psql
            services.apps.tanzu.vmware.com/infra: kubernetes
            services.apps.tanzu.vmware.com/version: "12"
    EOF
    ```

### Services Toolkit Reader Cluster Role

We make sure the STK controller can read the secrets anywhere.
Feel free to limit this role to specific named resources via the `resourceNames` property.

```sh
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
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
EOF
```

### Discover, Claim, and Bind to an instance

First, confirm we have claimable class instances.

```sh
export RESOURCE_NAMESPACE=default
export RESOURCE_NAME=${CLAIM_NAME}
export CLASS_NAME="multi-psql"
```

=== "For any multicloud-psql"
    ```sh
    export CLASS_NAME="multi-psql"
    ```

=== "Limit to Kubernetes based"
    ```sh
    export CLASS_NAME="multi-psql-kubernetes"
    ```

=== "Limit to Version 12"
    ```sh
    export CLASS_NAME="multi-psql-kubernetes-12"
    ```

```sh
tanzu services claimable list --class ${CLASS_NAME} \
  -n ${RESOURCE_NAMESPACE}
```

Which should yield:

```sh
NAME             NAMESPACE  KIND    APIVERSION  
postgresql-0001  default    Secret  v1 
```

We have to create the claim in the namespace of the consuming application.
So set this variable to the namespace where you create TAP workloads.

```sh
export TAP_DEV_NAMESPACE=default
```

We then create the associated resource claim:

=== "Using Tanzu CLI"
    ```sh
    tanzu service claim create multi-psql-claim-01 \
    --namespace ${TAP_DEV_NAMESPACE} \
    --resource-name ${RESOURCE_NAME} \
    --resource-namespace ${RESOURCE_NAMESPACE} \
    --resource-kind Secret \
    --resource-api-version v1
    ```

=== "Using Kubernetes Manifest"
    ```sh 
    cat <<EOF | kubectl apply -f -
    apiVersion: services.apps.tanzu.vmware.com/v1alpha1
    kind: ResourceClaim
    metadata:
      name: multi-psql-claim-01
      namespace: ${TAP_DEV_NAMESPACE}
    spec:
      ref:
        apiVersion: v1
        kind: Secret
        name: ${RESOURCE_NAME}
        namespace: ${RESOURCE_NAMESPACE}
    EOF
    ```

To verify your claim is ready, you run this command:

```sh
tanzu service claim list -o wide 
```

Which should yield the following:

```sh
NAME                 READY  REASON            CLAIM REF                                                                  
multi-psql-claim-01  True   Ready             services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:multi-psql-claim-01 
```

You can now claim it with a TAP workload.

### Test Claim With TAP Workload

We can now create a TAP workload that uses our resource claim.

The runtime will fail once or twice as it takes time before the service update with the secret mount lands. So wait for  `deployment-0002` or `0003`. 

=== "Tanzu CLI"
    ```sh
    tanzu apps workload create spring-boot-postgres-01 \
      --namespace ${TAP_DEV_NAMESPACE} \
      --git-repo https://github.com/joostvdg/spring-boot-postgres.git \
      --git-branch main \
      --type web \
      --label app.kubernetes.io/part-of=spring-boot-postgres-01 \
      --annotation autoscaling.knative.dev/minScale=1 \
      --build-env BP_JVM_VERSION=17 \
      --service-ref db=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:multi-psql-claim-01 \
      --yes
    ```

=== "Kubernetes Manifest"
    ```sh
    echo "apiVersion: carto.run/v1alpha1
    kind: Workload
    metadata:
      labels:
        app.kubernetes.io/part-of: spring-boot-postgres-01
        apps.tanzu.vmware.com/workload-type: web
      name: spring-boot-postgres-01
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
          url: https://github.com/joostvdg/spring-boot-postgres.git
    " > workload.yml
    ```

    ```sh
    kubectl apply -f workload.yml
    ```

To see the logs:
```sh
tanzu apps workload tail spring-boot-postgres-01
```

To get the status:

```sh
tanzu apps workload get spring-boot-postgres-01
```

Tap creates the deployment when the build and config writer workflows are complete.

To see their pods:

```sh
kubectl get pod -l app.kubernetes.io/part-of=spring-boot-postgres-01
```

Then you can wait for the application to be ready via the `kubectl` CLI.

```sh
kubectl wait --for=condition=ready \
  pod -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-postgres-01 \
  --timeout=180s \
  --namespace ${TAP_DEV_NAMESPACE}
```

Ensure there is only one deployment active:

```sh
kubectl get pod --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-postgres-01
```

Which should list a single deployment with Ready 2/2:

```sh
NAME                                                       READY   STATUS    RESTARTS   AGE
spring-boot-postgres-01-00002-deployment-8cd56bdc8-gb44n   2/2     Running   0          6m11s
```

We then collect the name of the **Pod** or copy it from the command-line output.

```sh
POD_NAME=$(kubectl get pod \
  --namespace ${TAP_DEV_NAMESPACE} \
  -l app.kubernetes.io/component=run,app.kubernetes.io/part-of=spring-boot-postgres-01 \
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
CLAIM_NAME="postgresql-0001"
CONFIG_NAME="trp-multicloud-psql"
```

!!! Danger "Delete TAP Workload"
    ```sh
    tanzu apps workload delete spring-boot-postgres-01 || true
    ```


!!! Danger "Delete STK Claim"
    ```sh
    tanzu service claim delete multi-psql-claim-01 || true
    kubectl delete ClusterInstanceClass multi-psql multi-psql-kubernetes multi-psql-kubernetes-12 || true
    ```


!!! Danger "Delete Crossplane Claim & Package"
    ```sh
    kubectl delete postgresqlinstances ${CLAIM_NAME} || true
    ```

    ```sh
    kubectl delete configuration ${CONFIG_NAME} || true
    ```

!!! Danger "Delete Crossplane resources"

    ```sh
    kubectl delete providerconfigs.helm.crossplane.io default || true
    kubectl delete providerconfigs.kubernetes.crossplane.io default || true

    kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-helm || true
    kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-kubernetes || true
    kubectl delete providers.pkg.crossplane.io crossplane-contrib-provider-terraform || true
    ```

This should not be required, but in case the resources for Azure are not cleaned up when deleting the package:

!!! Danger "Delete Azure Resources"
    ```sh
    kubectl delete flexibleserverconfigurations.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true
    kubectl delete flexibleserverdatabases.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true
    kubectl delete flexibleserverfirewallrules.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true

    FLEXIBLE_SERVER_NAME=$(kubectl get flexibleserver.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} -o name)
    kubectl patch ${FLEXIBLE_SERVER_NAME} -p '{"metadata":{"finalizers":null}}' --type=merge || true
    kubectl delete flexibleserver.dbforpostgresql.azure.upbound.io -l crossplane.io/claim-name=${CLAIM_NAME} --force --grace-period=0 || true
    ```