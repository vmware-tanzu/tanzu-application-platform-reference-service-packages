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

Add the Package Repository to your Kubernetes cluster:
```shell
tanzu package repository add tap-service-reference-packages --url ghcr.io/vmware-tanzu/tanzu-application-platform-reference-packages/tap-service-reference-package-repo:0.0.1 -n tanzu-package-repo-global
```
or:
```shell
kubectl apply -f packagerepo.yaml
```

> **Note**: The global namespace of `kapp-controller` may be different from `tanzu-package-repo-global` if it has not been installed via cluster-essentials.

Follow the instructions for a specific Service Instance below:

## Service Instances

| Type      | Resource | Description |   Status     | 
| ----------- | ----------- | ----------- | ----------- |
| [Amazon RDS](./amazon/ack/rds/README.md) | DBInstance       |     Create RDS instances        | 🚧 Experimental      |


## Building the Package Repository

>**Note these steps will be automated in the future**

To publish a new Package Repository follow these instructions:

```shell
export REPO_HOST=ghcr.io/tanzu-application-platform-reference-packages
export TAG=0.0.1-build.1

kbld -f repository/ --imgpkg-lock-output repository/.imgpkg/images.yml
imgpkg push -b ${REPO_HOST}/tap-service-reference-package-repo:${TAG} -f repository
```

## Adding a new Service Instance Package Bundle to the Repository

> TODO

## Contributing

The tanzu-application-platform-reference-packages project team welcomes contributions from the community. Before you start working with tanzu-application-platform-reference-packages, please
read our [Developer Certificate of Origin](https://cla.vmware.com/dco). All contributions to this repository must be
signed as described on that page. Your signature certifies that you wrote the patch or have the right to pass it on
as an open-source patch. For more detailed information, refer to [CONTRIBUTING.md](CONTRIBUTING.md).

## License
See [LICENSE](./LICENSE)