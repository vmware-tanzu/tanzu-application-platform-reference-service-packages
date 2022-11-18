---
title: Azure Packages Prerequisites
description: How to satisfy the Azure packages prerequisites
---


## SecretGen Controller

The [SecretGen Controller](https://github.com/vmware-tanzu/carvel-secretgen-controller) is part of the [Tanzu Cluster Essentials](https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/index.html).

If you install the **Cluster Essentials**, you can skip installing the **SecretGen Controller** yourself.

If you have not installed the **Cluster Essentials**, either follow its [installation docs](https://github.com/vmware-tanzu/carvel-secretgen-controller/blob/develop/docs/install.md)
or continue below.

In most cases, you can safely install the latest version of the **SecretGen Controller**:

```sh
kubectl apply -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/latest/download/release.yml
```

But, if that doesn't work, or you want to install a fixed version, take a look [at the releases](https://github.com/vmware-tanzu/carvel-secretgen-controller/releases).