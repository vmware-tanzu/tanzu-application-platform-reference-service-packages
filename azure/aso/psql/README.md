# Azure Service Operator - FlexibleServer for PostgreSQL

Status: Experimental

## Description

This is a [Carvel Package] using the [Azure Service Operator v2] to manage Azure FlexibleServer for PostrgreSQL instances.

[Azure Service Operator v2]: https://github.com/Azure/azure-service-operator/blob/v2.0.0-beta.2/README.md
[Carvel Package]: https://carvel.dev/kapp-controller/docs/develop/packaging/

## Use

For detailed instructions, follow the guide [Services Toolkit Documentation on FlexibleServer using ASO v2](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-consuming_azure_flexibleserver_psql_with_azure_operator.html)

## Bundle

For more information on customizing the bundle see [here][bundle], specifically
the [values-schema]. Alternatively you can also see the configuration options
with the tanzu CLI once the [package repo has been installed][repo-install] on
your cluster:

```sh
tanzu package available get \
  --values-schema psql.azure.references.services.apps.tanzu.vmware.com/0.0.1-alpha
```

[bundle]: ../../../bundles/azure/aso/psql
[values-schema]: ../../../bundles/azure/aso/psql/bundle/config/00-schema.yml
[repo-install]: ../../../README.md#quick-start
