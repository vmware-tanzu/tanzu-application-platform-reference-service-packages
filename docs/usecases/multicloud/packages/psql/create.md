---
title: Creating the Postgresql Multicloud Crossplane package
---

## Why Multicloud

There are various reasons why companies are running applications in multiple clouds.
We count data centers as local or private clouds.

It is increasingly common for companies to run Kubernetes clusters in multiple locations - some clusters in the data center and others in AWS, for example.

When (service) consumers do not care about the specific performance parameters of a database, you can simplify onboarding and relocation pain by providing a generic API.

This package is an example of such a generic API.
It holds as long as the consumers want _a database_ and there is no need (yet) to fine-tune it.

Good examples are PoCs, preview environments, or applications where the performance bottleneck lies elsewhere.

## Why This Package

There are several contributing factors as to why this package exists.

* **Multicloud Messaging**: VMware is going big on multicloud. We wanted a package that shows how to leverage the Tanzu Application Platform (TAP) and other technologies (such as Crossplane) across multiple cloud environments.
* **Power of YTT**: We are proud of our Carvel tool suite. We want to show how maintaining complex Crossplane Compositions is more manageable using **YTT**.
* **Compare Crossplane to Cloud Controllers**: Each major public cloud provider has their Kubernetes Controller for managing resources in their respective cloud. We wanted to compare the _producer_ side of things between those packages we did before.

We stuck to the classic example of a PostgreSQL database.
Something you can run anywhere in a myriad of ways.
So the attention can be on using Crossplane and managing it with **YTT**.

## Crossplane XRD & Compositions

At the time of writing, the (Crossplane) package has four implementations, or **Compositions**.

* **Helm**
* **FlexibleServer** for Azure
* **RDS Private** for AWS, only privately (within VPC) available
* **RDS Public** for AWS, public available

While there is significant overlap between these packages, there are also a lot of differences.

This means the case of ***"I want to run a PostgreSQL database; I don't care where or how"*** is easily supported.
The package ensures sane defaults for every runtime environment for trivial (or hello world) installations.

Unfortunately, for anything more complex, the configuration of the public clouds shatters the illusion of a single API (the Crossplane XRD).
You cannot use this package for managing databases for non-trivial applications running in production.

Still, it serves its purpose of showing the Multicloud potential, the power of YTT, and how Crossplane compares to the cloud-specific controllers.

### Solving For Random Password

An interesting problem encountered early was the need for a secure admin password.

There are various ways of generating a password in Kubernetes, for instance, our own [SecretGen Controller](https://github.com/vmware-tanzu/carvel-secretgen-controller/blob/develop/docs/secret-template.md).

The challenge is that we need the following:

* deterministic name of the secret the password is stored in
* password is stored in the **ConnectionDetails** secret

Most alternatives, such as the **SecretGen Controller**, do not expose the password so we can get it into the **ConnectionDetails**.

Our current solution is the use of **Terraform**.
There is an official **Terraform** Provider, and **Terraform** can generate a random password.

The Terraform Provider also supports ***outputs***, which the Crossplane uses as values for the **ConnectionSecret**.
We can then promote this value to the **ConnectionDetails**.

Below is the snippet showing the example.
The **Patches** part is cut; we'll dive into that next.

??? Example "Terraform Password snippet"
    ```yaml
    base:
      apiVersion: tf.upbound.io/v1beta1
      kind: Workspace
      spec:
        forProvider:
          module: |
            resource "random_password" "password" {
              length  = 64
              special = false
            }

            output "password" {
              value     = random_password.password.result
              sensitive = true
            }
          source: Inline
        writeConnectionSecretToRef:
          namespace: #@ crossplaneNamespace
    connectionDetails:
    - fromConnectionSecretKey: password
    ```

### Creating a complete ConnectionDetails secret

We use Crossplane to create and manage data stores in public cloud infrastructure.
To consume these data stores with **Tanzu Application Platform** (TAP), we use the **ServiceBinding** and a _mapping_ solution with the **ServicesToolkit** (STK).

The **ServiceBinding** spec gives us a clear goal of what we need to generate.
We need a secret with specific keys depending on the data store type, e.g., Postgres.

!!! Info "Postgres required keys"

    The [Service Binding specification](https://servicebinding.io/) defines how a service such as PostgreSQL can be bound to an application.

    For a list of keys that is required, one can also look at the [Spring Cloud Bindings](https://github.com/spring-cloud/spring-cloud-binding) (Java) library.

    You can view the list for [PostgreSQL here](https://github.com/spring-cloud/spring-cloud-bindings#postgresql-rdbms).

For **STK**, we also need some labels on this (Kubernetes) **secret** so it can create a **ClusterInstanceClass**.

When using Compositions, Crossplane generates at least two secrets.
The data for those secrets depends on the `spec.connectionSecretKeys` entries in the **CompositeResourceDefinition** (XRD).
I will name the secrets to explain this. Both of these secrets represent the **ConnectionDetails** conceptual secret.

1. **Composition Secret**: It creates a "placeholder" secret for collecting the expected entries from the various Composition Resources
1. **Claim Secret**: When the Composition has collected all entries, it creates a secret in the namespace of the (Crossplane) **Claim** (e.g., `PostgreSQLInstance` CR)

!!! Example "Instruct Crossplane to create Composition Secret"
    We specify the `spec.writeConnectionSecretsToNamespace` to instruct Crossplane to create the _CompositionSecret_ and in which namespace.

    ```yaml hl_lines="6"
    apiVersion: apiextensions.crossplane.io/v1
    kind: Composition
    metadata:
    ...
    spec:
      writeConnectionSecretsToNamespace: #@ data.values.crossplane.namespace
      ...
      resources:
    ```

Some resources defined in the **Composition** have their own **ConnectionSecret**, from where it copies the values to the **ConnectionDetails** secret.
An example to illustrate this:

!!! Example "Terraform Password - Connection Secret"
    The Terraform provider exposes the `output` in the Module as something Crossplane can write to a _ConnectionSecret_.
    We tell Crossplane to create this secret by setting `writeConnectionSecretToRef.namespace` and `writeConnectionSecretToRef.name`.

    We then instruct Crossplane to copy the key `password` from the _ConnectionSecret_ to the **ConnectionDetails**.
    Again, the **ConnectionDetails** repre

    ```yaml hl_lines="13 18 19 23 24"
    name: password
    base:
      apiVersion: tf.upbound.io/v1beta1
      kind: Workspace
      spec:
        forProvider:
          module: |
            resource "random_password" "password" {
              length  = 64
              special = false
            }

            output "password" {
              value     = random_password.password.result
              sensitive = true
            }
          source: Inline
        writeConnectionSecretToRef:
          namespace: #@ crossplaneNamespace 
          # we set the name in a patch, excluded from the example for brevity
        patches:
        ...
        connectionDetails:
         - fromConnectionSecretKey: password
    ```

Assuming that this Composition succeeds, we end up with three secrets:

1. Composition Secret
1. Composition Resource Secret (Terraform Password)
1. Claim Secret

Depending on the number of **Composition** ***Resources*** that have secrets, we can end up with a whole bunch of them.

We decided to use Crossplane's **Patch** system to reduce the number of secrets.
We are reducing the proliferation of possibly sensitive data.

To re-iterate our main goal: we need a (Kubernetes) ***Secret*** with all the data keys for the ServiceBinding specification and labels for the STK mapping.
Any other secret is a potential problem, so the fewer, the better.

The most straightforward secret to manipulate is the **Composition Secret**.
This secret is a placeholder, so it doesn't impact anything.

!!! Example "Terraform Password - Modifying Composition Secret"

    We use Crossplane's _patches_ mechanism to "merge" the **Composition Secret** into the **Claim Secret**.

    This is done by taking the **Claim's** _name_ and _namespace_ and overriding the `spec.writeConnectionSecretToRef` fields of the Composition.
    You access these fields via `- type: ToCompositeFieldPath`.

    ```yaml
    patches:
    - type: ToCompositeFieldPath
      fromFieldPath: metadata.labels[crossplane.io/claim-name]
      toFieldPath: spec.writeConnectionSecretToRef.name
    - type: ToCompositeFieldPath
      fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
      toFieldPath: spec.writeConnectionSecretToRef.namespace
    ```

The **Composition** does not own all Secrets. It can only merge secrets it owns.
If you try to merge a secret it doesn't own; you will get an error (in the resource's events) saying it cannot update the secret because it doesn't own it.

An example of this is the **Connection Secret** of the **Terraform Password** resource.
To help understand what this secret is, we patch it.

!!! Example "Terraform Password - Rename Connection Secret"

    Here we patch the name of the **Connection Secret** to use the ***UID*** of the **Composition**.
    
    In addition, we use the `transforms` option to _add_ further information to the name.
    This helps us understand what this Secret is and to what resource it belongs.

    ```yaml
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.uid
      toFieldPath: spec.writeConnectionSecretToRef.name
      transforms:
        - type: string
          string:
            type: Format
            fmt: '%s-postgresql-admin'
    ```

### Solve For STK Metadata

The **Claim Secret** we end up with has all the data we write to the **Connection Details**.
It has the name of the Claim and exists in the Claim namespace.

This is enough for any application to use and leverage with a service binding library (e.g., Spring applications).
Unfortunately, this (Kubernetes) secret is relatively sterile, containing no Annotations or Labels.

The **Services Toolkit** (STK) needs specific fields or labels on the object to map it to a **ClusterInstanceClass**.
We need **ClusterInstanceClasses**, to create **STK Claims** which **TAP** can consume.

There are several ways we can tackle this.

* Use a **SecretGen Controller's** ***SecretTemplate*** to create a copy _with_ the desired labels
* Specify the labels in the **Crossplane Claim** (see below)
* Create a **Crossplane** ***Managed Resource*** that merges with the **Claim Secret**, adding the desired labels

The first solution is out, as we want fewer secrets, not more.

The second solution is not nice for our users, as it requires additional work and understanding.
We prefer to use our packages to reduce our users' burden (and cognitive load), not increase it.

!!! Example "Add labels via Crossplane Claim"

    Here's an example of adding additional metadata to the **Claim Secret**.
  
    ```yaml
    publishConnectionDetailsTo:
      name: trp-cosmosdb-mongo-bindable-08
      configRef:
        name: default
      metadata:
        labels:
          services.apps.tanzu.vmware.com/class: azure-mongodb
    ```

Consequently, there is only one option we like.
We create another Crossplane Composition **Resource**.

!!! Example "Secret with labels resource"

    As you can see, we use the **Crossplane Kubernetes** Provider to create a Kubernetes **Secret** resource.

    This secret is an empty shell, as we set `spec: {}`.
    We do add our labels and patch the name and namespace.

    We set the ***name*** and ***namespace*** to the values of the **Claim**.
    Which guarantees it has the same values as the **Claim Secret**.

    **Crossplane** merges this _empty secret_ with the **Claim Secret**.
    And thus, our **Claim Secret** ends up having our desired labels.

    ```yaml
    name: connectionSecret
    base:
      apiVersion: kubernetes.crossplane.io/v1alpha1
      kind: Object
      spec:
        forProvider:
          manifest:
            apiVersion: v1
            kind: Secret
            spec: {}
            metadata:
              labels:
                services.apps.tanzu.vmware.com/class: multicloud-psql
    patches:
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.labels[crossplane.io/claim-name]
      toFieldPath: spec.forProvider.manifest.metadata.name
    - type: FromCompositeFieldPath
      fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
      toFieldPath: spec.forProvider.manifest.metadata.namespace
    ```

More than a single label is required to achieve what we want with the STK.
Ideally, we have several dynamic labels to differentiate between different implementations.

For example, we would like an infrastructure label to create **ClusterInstanceClasses** for Azure and AWS.
This leads us to the next topic we want to explain: how do we manage multiple Compositions with significant overlap?

## Manage Compositions with YTT

The four **Compositions** share several resources. Some are the same (e.g., the Terraform Password), while others have minor variations.

Let's explain how we tackled the shared values with **YTT** templating.

### Templating

For more information on YTT, [read the docs](https://carvel.dev/ytt/docs/v0.44.0/) or look at the [Playground](https://carvel.dev/ytt/#playground).

In contrast to tools such as Helm and Kustomize, **YTT** works with the YAML structure.
This means we can create a schema and validate the data we are working with (more on that in the next paragraph).

We'll stick to the base templating in this package (and later the Library feature).

For the most part, we stick to templating from direct _data values_.
These data values come from input into the templating process.

You can supply these in several ways:

* data values file
* raw YAML file
* a schema file's default values (see next paragraph)
* input flags when executing the YTT CLI's template command

We supply all our values with a schema file.
When we run the **YTT** templating, we use the values from the Schema file and apply the same value to all the templates.

The templates we have are the **XRD** and the **Compositions**, each in their respective file.

Below are two snippets as examples.

!!! Example "XRD template snippet"

    The ***CompositeResourceDefinition*** or **XRD**.
    It defines our custom resources and the API for all our compositions.

    ```yaml
    #@ load("@ytt:data", "data")
    ---
    apiVersion: apiextensions.crossplane.io/v1
    kind: CompositeResourceDefinition
    metadata:
      name: #@ data.values.xrd.names.plural + "." + data.values.xrd.group
    spec:
      group: #@ data.values.xrd.group
      names: #@ data.values.xrd.names
      claimNames: #@ data.values.xrd.claimNames
    ```

!!! Example "Composition (Helm) template snippet"
    The example below is the top section of the Helm **Composition**.
    
    It implements the API defined by the **XRD**.
    Via the reuse of the same data values, we guarantee it is always correct.
    And due to the reuse, we specify these fundamental values only once.

    ```yaml
    #@ load("@ytt:data", "data")
    ---
    apiVersion: apiextensions.crossplane.io/v1
    kind: Composition
    metadata:
      name: #@ data.values.providers.helm.name + "-" + data.values.cloudServiceBindingType
      labels:
        crossplane.io/xrd: #@ data.values.xrd.names.plural + "." + data.values.xrd.group
        provider: #@ data.values.providers.helm.name
        database: #@ data.values.cloudServiceBindingType
    spec:
      writeConnectionSecretsToNamespace: #@ data.values.crossplane.namespace
      compositeTypeRef:
        apiVersion: #@ data.values.xrd.group + "/" + data.values.xrd.version
        kind: #@ data.values.xrd.names.kind
    ```

Now that you've seen how we reuse the data values, it is good to see where we define the structure and default values.

We do so in a ***Values Schema***.

### Schema

In this ***Values Schema***, we define the structure of the data values used by the YTT templating.

We need to specify the keys; the values are optional.
There are two reasons to specify the values:

1. to clarify the data type, although for Strings, `""` will do
1. to set a default value

!!! Example "values-schema.ytt.yml"
    We limited the values for brevity, though this is enough to show what you can do with it.

    First, we have to let **YTT** know this is a values schema.
    We do so with `#@data/values-schema`.

    Then we provide YAML ***keys*** in our desired structure.

    In our case, we only have String values, and because these are only used to generate the **Crossplane** source files, we only need a little documentation. 
    For all the things you can do with the schema, [read the docs](https://carvel.dev/ytt/docs/v0.44.0/how-to-write-schema/).

    ```yaml
    #@data/values-schema
    ---
    xrd:
      group: multi.ref.services.apps.tanzu.vmware.com
      names:
        kind: XPostgreSQLInstance
        plural: xpostgresqlinstances
      claimNames:
        kind: PostgreSQLInstance
        plural: postgresqlinstances
      version: v1alpha1

    providers:
      helm:
        name: helm
        image: xpkg.upbound.io/crossplane-contrib/provider-helm
        version: ">=v0.12.0"

    crossplane:
      #@schema/title "CrossplaneNamespace"
      #@schema/desc "The namespace where crossplane controller is installed"
      namespace: upbound-system
      version: '^v1.10'

    #@schema/title "StoreConfig"
    #@schema/desc "Details of the StoreConfig"
    storeConfig:
      #@schema/title "StoreConfig Name"
      #@schema/desc "The name of the StoreConfig"
      name: "default"
    ```

### Solving For Re-usable Snippets

In the templating section, you can see how we reuse values from the schema to avoid duplication and misconfiguration.

Even so, the number of shared data structures between the **Compositions** is significant.
The solution for the **ConnetionDetails**, for example, is something each **Composition** requires.

So there is a need for even more reuse.
Not just the data values, but entire data structures, for example, the Composition ***Resources***.

For that purpose, we use the **YTT** features [Load](https://carvel.dev/ytt/docs/v0.44.0/lang-ref-load/) and [Functions](https://carvel.dev/ytt/docs/v0.44.0/lang-ref-def/).
It lets you create functions in separate files you import into other YTT files.

!!! Info "YTT Library"
    We could also have opted to use a **YTT** [Library](https://carvel.dev/ytt/docs/v0.44.0/lang-ref-ytt-library/).

    Which does practically the same thing but requires more steps to use.
    So we opted for the solution below.

To use this, we do the following:

1. Create a file named `<name>.lib.yml`
1. Add ***Functions*** in this file that generate the Crossplane Composition Resource snippets
1. Load the file and the desired functions in the YTT _data_ file (a) file starting with `#@ load("@ytt:data", "data")`)
1. Use the functions as if they are defined in this YTT data file

Let's look at some examples to clarify what we did.
First, it's a function in a _library_ module.

!!! Example "shared.lib.yml"

    For clarity, we removed some lines and highlighted the noteworthy lines.

    We **start** a function with `#@ def <name>(<input parameters>)`.

    We **end** a function with `#@ end`.

    We can use any defined input parameters directly by name.
    We determine the value by the order in which the caller supplies them.

    In this case, we have one parameter, `infra`.
    This lets us create a dynamic label on the secret based on the type of infrastructure the **Composition** implements (e.g., `azure`, `aws`, `kubernetes`).

    ```yaml hl_lines="1 15 18" title="shared.lib.yml"
    #@ def labelsForSecret(infra):
    name: connectionSecret
    base:
      apiVersion: kubernetes.crossplane.io/v1alpha1
      kind: Object
      spec:
        forProvider:
          manifest:
            apiVersion: v1
            kind: Secret
            spec: {}
            metadata:
              labels:
                services.apps.tanzu.vmware.com/class: multicloud-psql
                services.apps.tanzu.vmware.com/infra: #@ infra
    patches:
    ...
    #@ end
    ```

We use the library as follows:

1. We import it using the `#@ load()` feature. Using the relative path of the file and the functions we want to use.
    ```yaml
    #@ load("shared.lib.yml", "labelsForSecret")
    ```
1. Then, we call the function where we want its _output_ to be.
    ```yaml
    resources:
    - #@ labelsForSecret("aws")
    ```

!!! Important
    By default, a function returns the data structure that it defines.

    If you want to return a single value, you can do so via the `return` statement like this:

    ```yaml
    #@ def TLSSecretName(domain):
    #@ return str(domain).replace(".", "-") + "-tls"
    #@ end
    ```

The functions can use everything **YTT** has to offer.

This makes it an excellent place to handle specific logic for **Crossplane Compositions**.
For example, in the case of the AWS RDS instance, we have private and public variants.

This means that while most values for the RDS instance definition are the same, some change if it needs to be public.

!!! Example "AWS Composition Public/Private Switch"

    When we make the RDS instance publicly available, we need to set `spec.forProvider.publiclyAccessible` to true.
    
    We also need to tell **Crossplan** which ***SubnetGroup*** it has to use.
    When we make the RDS instance public, we create the ***SubnetGroup*** ourselves and let **Crossplane** manage the reference:

    ```yaml
    #@ if/end publiclyAccessible: 
    dbSubnetGroupNameSelector:
      matchControllerRef: true
    ```
    _ps. `#@ if/end` means it does an if/else/end expression for a single line only_
    
    If private, we expect you to supply the name of an existing one.
    We can use the `not` keyword to reverse the `if/end`, so we end up with two variations of the same snippet.

    ```yaml
    #@ if/end not publiclyAccessible: 
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.aws.dbSubnetGroupName
      toFieldPath: spec.forProvider.dbSubnetGroupName
    ```

    ```yaml hl_lines="13 19 25" title="aws-composition.lib.yml"
    #@ def rdsInstance(crossplaneNamespace, providerConfigRef, publiclyAccessible):
    name: rdsinstance
    base:
      apiVersion: rds.aws.upbound.io/v1beta1
      kind: Instance
      spec:
        forProvider:
          engine: postgres
          instanceClass: db.t3.micro
          passwordSecretRef: 
            key: password
            namespace: #@ crossplaneNamespace
          publiclyAccessible: #@ publiclyAccessible
          skipFinalSnapshot: true
          storageEncrypted: false
          allocatedStorage: 10
          vpcSecurityGroupIdSelector:
            matchControllerRef: true
          #@ if/end publiclyAccessible: 
          dbSubnetGroupNameSelector:
            matchControllerRef: true
        providerConfigRef:
          name: #@ providerConfigRef
    patches:
    #@ if/end not publiclyAccessible: 
    - type: FromCompositeFieldPath
      fromFieldPath: spec.parameters.aws.dbSubnetGroupName
      toFieldPath: spec.forProvider.dbSubnetGroupName
    ...
    #@ end
    ```

Let's look at the two AWS examples (private and public) to see how this works out for the **Composition** files.

#### AWS Private Example

```yaml title="aws-composition-private.ytt.yml"
#@ load("@ytt:data", "data")
---
#@ load("aws-composition.lib.yml", "rdsInstance", "securityGroup", "securityGroupRule")
#@ load("shared.lib.yml", "labelsForSecret", "tfProviderConfig", "tfWorkspace")

apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: #@ data.values.providers.aws.name + "-" + data.values.cloudServiceBindingType + "-private"
  labels:
    crossplane.io/xrd: #@ data.values.xrd.names.plural + "." + data.values.xrd.group
    provider: #@ data.values.providers.aws.name
    database: #@ data.values.cloudServiceBindingType
    connectivity: "private"
spec:
  writeConnectionSecretsToNamespace: #@ data.values.crossplane.namespace
  compositeTypeRef:
    apiVersion: #@ data.values.xrd.group + "/" + data.values.xrd.version
    kind: #@ data.values.xrd.names.kind
  resources:
  - #@ labelsForSecret("aws")
  - #@ tfProviderConfig(data.values.crossplane.namespace)
  - #@ tfWorkspace(data.values.crossplane.namespace)
  - #@ rdsInstance(data.values.crossplane.namespace, data.values.providers.aws.configRef, False)
  - #@ securityGroup()
  - #@ securityGroupRule()
```

#### AWS Public Example

!!! Info "Convenience Variables"

    YTT supports the use of convenience variables.

    Below you can see we make ample use of them to make the subnet parameters clearer to understand and separate.

```yaml title="aws-composition-public.ytt.yml"
#@ load("@ytt:data", "data")
---
#@ load("aws-composition.lib.yml",  "rdsInstance", "securityGroup", "securityGroupRule", "subnet", "routeTableAssociation", "routeTable", "route", "subnetGroup")
#@ load("shared.lib.yml", "labelsForSecret", "tfProviderConfig", "tfWorkspace")

#@ subnetASuffix = '-a'
#@ subnetAFormat = 'subnet-a-%s'
#@ availabilityZoneAFormat = '%sa'
#@ cidrBlockFieldA = 'spec.parameters.aws.public.subnetACidrBlock'

#@ subnetBSuffix = '-b'
#@ subnetBFormat = 'subnet-b-%s'
#@ availabilityZoneBFormat = '%sb'
#@ cidrBlockFieldB = 'spec.parameters.aws.public.subnetBCidrBlock'

apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: #@ data.values.providers.aws.name + "-" + data.values.cloudServiceBindingType + "-public"
  labels:
    crossplane.io/xrd: #@ data.values.xrd.names.plural + "." + data.values.xrd.group
    provider: #@ data.values.providers.aws.name 
    database: #@ data.values.cloudServiceBindingType
    connectivity: "public"
spec:
  writeConnectionSecretsToNamespace: #@ data.values.crossplane.namespace
  compositeTypeRef:
    apiVersion: #@ data.values.xrd.group + "/" + data.values.xrd.version
    kind: #@ data.values.xrd.names.kind
  resources:
  - #@ labelsForSecret("aws")
  - #@ tfProviderConfig(data.values.crossplane.namespace)
  - #@ tfWorkspace(data.values.crossplane.namespace)
  - #@ rdsInstance(data.values.crossplane.namespace, data.values.providers.aws.configRef, True)
  - #@ securityGroup()
  - #@ securityGroupRule()
  - #@ routeTable()
  - #@ subnetGroup()
  - #@ subnet(subnetASuffix, subnetAFormat, availabilityZoneAFormat, cidrBlockFieldA)
  - #@ routeTableAssociation(subnetASuffix, subnetAFormat)
  - #@ subnet(subnetBSuffix, subnetBFormat, availabilityZoneBFormat, cidrBlockFieldB)
  - #@ routeTableAssociation(subnetBSuffix, subnetBFormat)
  - #@ route('route-%s')
```
