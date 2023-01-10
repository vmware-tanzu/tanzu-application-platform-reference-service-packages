---
title: Helm provider
description: How to install and configure Crossplane Helm provider
Hero: Install Crossplane Helm provider
---

The [Helm provider](https://marketplace.upbound.io/providers/crossplane-contrib/provider-helm/latest) is a community provider.
As the name suggests, it lets you manage Helm chart installations with Crossplane.

## Install

You can install the provider via the [up](https://docs.upbound.io/cli/) CLI or a Kubernetes manifest.

=== "Upbound CLI"
    ```sh
    up controlplane provider install \
      xpkg.upbound.io/crossplane-contrib/provider-helm:v0.12.0
    ```

=== "Kubernetes Manifest"
    ```sh
    cat <<EOF | kubectl apply -f -
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-helm
    spec:
      package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.12.0
    EOF
    ```

Once created, you can wait for the provider to become healthy.

```sh
kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io crossplane-contrib-provider-helm
```

## Configure

The Helm provider needs Kubernetes credentials to install Helm charts.
The following is required if installing in the same cluster as the provider.

```sh
cat <<EOF | kubectl apply -f -
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF
```

For options, look at the documentation and the [examples](https://marketplace.upbound.io/providers/crossplane-contrib/provider-helm/v0.12.0/resources/helm.crossplane.io/ProviderConfig/v1beta1).

## Give Service Account permissions

The Helm provider needs several RBAC permissions.
It does so via a generated **Service Account**, which you can find like this:

```sh
SA=$(kubectl -n upbound-system get sa -o name | grep provider-helm | sed -e 's|serviceaccount\/|upbound-system:|g')
```

You can give it the specific RBAC configuration you want or the `cluster-admin` cluster role, as in the example below.

!!! Danger
    Do not do this in production environments.

    In production environments, ensure the Service Accounts have only the permissions you need.

    ```sh
    kubectl create clusterrolebinding provider-helm-admin-binding --clusterrole cluster-admin --serviceaccount="${SA}" || true
    ```