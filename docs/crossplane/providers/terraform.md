---
title: UXP Terraform provider
description: How to install and configure Upbound's Crossplane Terraform provider
Hero: Install Crossplane UXP Terraform provider
---

In December 2022, Upbound released an official provider for [Terraform](https://marketplace.upbound.io/providers/upbound/provider-terraform/latest).
We recommend you use Upbound's provider over the community version.

## Install

You can install the provider via the [up](https://docs.upbound.io/cli/) CLI or a Kubernetes manifest.

=== "Upbound CLI"
    ```sh
    up controlplane provider install \
      xpkg.upbound.io/upbound/provider-terraform:v0.2.0
    ```

=== "Kubernetes Manifest"
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-terraform
    spec:
      package: xpkg.upbound.io/upbound/provider-terraform:v0.2.0
    EOF
    ```

Once created, you can wait for the provider to become healthy.

```sh
kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io provider-terraform
```

## Give Service Account permissions

The Terraform provider needs several RBAC permissions.
It does so via a generated **Service Account**, which you can find like this:

```sh
SA=$(kubectl -n upbound-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|upbound-system:|g')
```

You can give it the specific RBAC configuration you want or the `cluster-admin` cluster role, as in the example below.

!!! Danger
    Do not do this in production environments.

    In production environments, ensure the Service Accounts have only the permissions you need.

    ```sh
    kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}"
    ```
