# Tanzu Application Platform Service Reference Packages

>**Warning this repository contains references Packages that are not supported**

## Overview

This repository contains sample [Carvel Packages](https://carvel.dev/kapp-controller/docs/v0.38.0/packaging/) that create [Service Instances](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-api_projection_and_resource_replication-terminology_and_apis.html#terminology) (e.g. Databases, Message queues, caches etc) that are compatible with [Tanzu Application Platform (TAP)](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html).

## Prerequisites
These reference packages are compatible with the following:
* A Kubernetes Cluster with at least [Tanzu Application Platform](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html) 1.2.0 or higher.
* A Kubernetes Cluster configured with [Cluster Essentials for VMware Tanzu](https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/) 1.2.0 or higher. This explicitly relies on:
    * [carvel kapp-controller](https://github.com/vmware-tanzu/carvel-kapp-controller/)
    * [carvel secretgen-controller](https://github.com/vmware-tanzu/carvel-secretgen-controller/)(`>=0.9.0`)

## Quick start

Add the PackageRepository to your Kubernetes cluster:

```shell
tanzu package repository add tap-reference-service-packages \
    --url ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages:0.0.2 \
    -n tanzu-package-repo-global
```

or:

```shell
kubectl apply -f packagerepo.yaml
```

> **Note**: The global namespace of `kapp-controller` may be different from `tanzu-package-repo-global` if it has not been installed via cluster-essentials.

Follow the instructions for a specific Service Instance below:

## Service Instances

| Type               | Resource(s)                        | Description                | Status           |
| ------------------ | ---------------------------------- | -------------------------- | ---------------- |
| [Amazon RDS]       | DBInstance                         | Create RDS instances       | 🚧 Experimental  |
| [Google Cloud SQL] | SQLInstance, SQLDatabase, SQLUser  | Create Cloud SQL instances | 🚧 Experimental  |

[Amazon RDS]: ./amazon/ack/rds/README.md
[Google Cloud SQL]: ./google/config-connector/cloudsql/README.md

## Building the Package Repository

>**Note these steps will be automated in the future**

To publish a new Package Repository follow these instructions:

```shell
export REPO_HOST=ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages
export TAG=0.0.1-build.1

kbld -f repository/ --imgpkg-lock-output repository/.imgpkg/images.yml
imgpkg push -b ${REPO_HOST}:${TAG} -f repository
```

## Adding a new Service Instance Package Bundle to the Repository

> TODO

## Contributing

The tanzu-application-platform-reference-service-packages project team welcomes contributions from the community. Before you start working with this project please
read and sign our Contributor License Agreement (https://cla.vmware.com/cla/1/preview). If you wish to contribute code and you have not signed our
Contributor Licence Agreement (CLA), our bot will prompt you to do so when you open a Pull Request. For more detailed information, refer to 
[CONTRIBUTING.md](CONTRIBUTING.md).

## License
See [LICENSE](./LICENSE)
