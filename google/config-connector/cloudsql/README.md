# Google Config Connector - CloudSQL PSQL Instance

Status: Experimental

## Description

This is a using the [Config Connector] to manage Google Cloud SQL PostrgreSQL
instances as a [Carvel Package].

[Config Connector]: https://cloud.google.com/config-connector/docs/overview
[Carvel Package]: https://carvel.dev/kapp-controller/docs/develop/packaging/

<!-- TODO update when published -->
<!--
## Use

For detailed instructions follow the guide [Services Toolkit Documentation on
Config Connector using Cloud SQL][stk]

[stk]: https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html
-->

## Bundle

For more information on customizing the bundle see [here][bundle], specifically
the [values-schema]. Alternatively you can also see the configuration options
with the tanzu CLI once the [package repo has been installed][repo-install] on
your cluster:

```shell
tanzu package available get \
  --values-schema psql.google.references.services.apps.tanzu.vmware.com/0.0.1-alpha
```

[bundle]: ../../../bundles/google/config-connector/cloudsql
[values-schema]: ../../../bundles/google/config-connector/cloudsql/bundle/config/00-schema.yml
[repo-install]: ../../../README.md#quick-start
