---
title: AWS prerequisites
description: Prerequisites to be satisfied when running TAP on AWS
---

This is a list of prerequisites that must be satisfied in order to deploy a TAP Reference Package on AWS EKS
and consume it through TAP:

*[TAP]: Tanzu Application Platform

1. Install [`ytt`](https://carvel.dev/ytt/docs/latest/install), a templating tool for YAML that
   is being widely used in these guides.

1. Install the AWS CLI. For how to do so, see the
   [AWS documentation][aws-cli].

1. Log into AWS with your own credentials and assume a role with proper permissions
   to deal with EKS and Elasticache services.
   Check your AWS account number, user and assumed role running:

     ```sh
     aws sts get-caller-identity
     ```

1. Make sure you have an available EKS cluster and the related OIDC provider configured.
   In order to create a new one you can follow [this guide][create-eks].

1. Install Tanzu Application Platform v1.2.0 or later and Cluster Essentials v1.2.0 or later on the Kubernetes cluster.
   For more information, see [Installing Tanzu Application Platform][tap-install].

1. Verify that you have the appropriate versions by running:

     ```sh
     kubectl api-resources | grep secrettemplate
     ```

     This command returns the `SecretTemplate` API.
     If it does not work for you, you might not have Cluster Essentials for VMware Tanzu v1.2.0 or later installed.

1. **Only if you want to deploy reference packages based on ACK**:
   install the [AWS Controller for Kubernetes (ACK)][install-configure-ack] for the service(s) you are going to consume on AWS.

1. **Only if you want to deploy reference packages based on Crossplane**:
   install [Crossplane][install-crossplane] and the AWS provider.

[aws-cli]: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
[create-eks]: ./eks.md
[tap-install]: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.2/tap/GUID-install-intro.html
[install-configure-ack]: ./ack.md
[install-crossplane]: ../../../crossplane/
