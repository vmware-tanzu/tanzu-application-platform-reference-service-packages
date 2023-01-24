#!/usr/bin/env bash

PROVIDER_NAME="upbound-provider-terraform"

up controlplane provider install xpkg.upbound.io/upbound/provider-terraform:v0.2.0 --name ${PROVIDER_NAME} || true

kubectl wait --for=condition="Healthy" providers.pkg.crossplane.io ${PROVIDER_NAME}
kubectl wait --for=condition=Available=True apiservices.apiregistration.k8s.io v1alpha1.tf.crossplane.io
