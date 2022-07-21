# AWS Controllers for Kubernetes - RDS PSQL Instance

Status: Experimental

## Use

For detailed instructions, follow the guide [Services Toolkit Documentation on RDS using ACK](https://docs.vmware.com/en/draft/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-consuming_aws_rds_with_ack.html)

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

1. Take the SHA produced by `imgpkg` and update `repository/amazon/ack/rds/package.yaml` by modifying `template.spec.fetch[0].imgpkgBundle.image` value.
