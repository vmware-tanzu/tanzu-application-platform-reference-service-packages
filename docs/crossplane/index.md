---
title: Install Crossplane
description: How to install and configure Crossplane
---

## Install Crossplane via Upbound CLI

Download the `up` cli

```sh
curl -sL "https://cli.upbound.io" | sh
sudo mv up /usr/local/bin/
```

Check the installed version:

```sh
up --version
```

Switch to the proper Kubernetes context and run the following command in order to install Upbound Universal Crossplane (UXP):

```sh
up uxp install
```

Verify all UXP pods are Running with kubectl get pods -n upbound-system.
This may take up to five minutes depending on your Kubernetes cluster.

```sh hl_lines="1"
$ k get pods -n upbound-system
NAME                                       READY   STATUS    RESTARTS      AGE
crossplane-65444df64-7wcb2                 1/1     Running   0             92s
crossplane-rbac-manager-69498f955b-2npkl   1/1     Running   0             92s
upbound-bootstrapper-5c9864b546-lngkw      1/1     Running   0             92s
xgql-6485cf5748-src2w                      1/1     Running   3 (70s ago)   92s
```

!!! note
    RESTARTS for the xgql pod are normal during initial installation.
