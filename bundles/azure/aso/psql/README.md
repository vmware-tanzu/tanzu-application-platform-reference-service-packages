# Azure Service Operator - FlexibleServer for PostgreSQL

Status: Experimental

## Use

For detailed instructions, follow the guide [Services Toolkit Documentation on FlexibleServer using ASO v2](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-consuming_azure_flexibleserver_psql_with_azure_operator.html)

## Customize

To customize the configuration of this Package Bundle modify the contents of `bundle` directory and follow the [Build](#build) steps.

## Build

>**Note**: This will be automated in the future

To alter this Package, modify the contents and perform the following steps to build the Package Bundle image. These steps use the following:

* [kbld](https://carvel.dev/kbld)
* [imgpkg](https://carvel.dev/imgpkg)

1. Build a new Package bundle image:

```sh
export REPO_HOST=<YOUR_IMAGE_REPO> #! e.g. ghcr.io/vmware-tanzu/tanzu-application-platform-reference-service-packages
export BUNDLE_TAG=<YOUR_BUNDLE_TAG> #! e.g. latest

pushd bundle
    kbld -f config/ --imgpkg-lock-output=.imgpkg/images.yml
    imgpkg push -b ${REPO_HOST}/psql.azure.references.services.apps.tanzu.vmware.com:$BUNDLE_TAG -f .
popd
```

1. Take the SHA produced by `imgpkg` and update `repository/packages/azure/psql/package.yml` by modifying `template.spec.fetch[0].imgpkgBundle.image` value.
