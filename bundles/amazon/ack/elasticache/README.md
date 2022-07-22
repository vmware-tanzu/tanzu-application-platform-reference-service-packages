# AWS Controllers for Kubernetes - Elasticache Redis Instance

Status: Experimental

## Use

Create a `CacheSubnetGroup`, for example:

```yaml
---
apiVersion: elasticache.services.k8s.aws/v1alpha1
kind: CacheSubnetGroup
metadata:
  name: my-cache-subnet-group
  namespace: ack-system
spec:
  cacheSubnetGroupDescription: For use with Redis Service Instances
  cacheSubnetGroupName: my-cache-subnet-group
  subnetIDs:
  - ...
```

Then run something like:

```console
ytt -f bundles/amazon/ack/elasticache/bundle/config/ \
  -v name=redis-test-1 \
  -v cacheSubnetGroupName=my-cache-subnet-group \
  --data-value-yaml vpcSecurityGroupIDs=[sg-foo] | \
  kubectl apply -f-
```

## Customize

To customize the configuration of this Package Bundle modify the contents of `bundle` directory and follow the [Build](#build) steps.

## Build

>**Note**: This will be automated in the future

To alter this Package, modify the contents and perform the following steps to build the Package Bundle image. These steps use the following:

* [kbld](https://carvel.dev/kbld)
* [imgpkg](https://carvel.dev/imgpkg)

1. Build a new Package bundle image:

```
export REPO_HOST=<YOUR_IMAGE_REPO> #! e.g. ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages
export BUNDLE_TAG=<YOUR_BUNDLE_TAG> #! e.g. latest

pushd bundle
    kbld -f config/ --imgpkg-lock-output=.imgpkg/images.yml
    imgpkg push -b ${REPO_HOST}/psql.aws.references.services.apps.tanzu.vmware.com:$BUNDLE_TAG -f .
popd
```

1. Take the SHA produced by `imgpkg` and update `repository/packages/amazon/elasticache/package.yaml` by modifying `template.spec.fetch[0].imgpkgBundle.image` value.
