# Packages structure

This is the parent folder holding the configurations the reference packages will be built from.
In order for the CI/CD workflow to work, they must adhere to the following structure:

```text
packages
├── <PROVIDER>
│   └── <PACKAGING>
│       └── <NAME>
│           ├── ...
│           ├── ...
┆           ┆
```

- `PROVIDER`: the provider the package is built for (i.e. `aws`, `azure`, `gcp`, `multicloud`).
- `PACKAGING`: the packaging system used (currently it must be either `carvel` or `crossplane`).
- `NAME`: the package name.

All folder names must be lowercase.

An actual example, featuring AWS Elasticache package built with Carvel suite and a multicloud PostgreSQL package with Crossplane, looks like the following:

```text
packages
├── aws
│   └── carvel
│       └── elasticache
│           ├── config
│           │   ├── 00-schema.yml
│           │   ├── 01-replication-group.ytt.yml
│           │   └── 99-kapp-config.yml
│           └── package-metadata.yml
┆
└── multicloud
    └── crossplane
        └── postgresql
            ├── README.md
            ├── claim
            │   └── helm.yml
            ├── claim-examples
            │   └── helm-psql-12.yaml
            └── ytt
                ├── crossplane.ytt.yml
                ├── definition.ytt.yml
                ├── helm-composition.ytt.yml
                └── schema.ytt.yml
```

## Packaging

The contents of the `<PROVIDER>/<PACKAGING>/<NAME>` directory depends on the specific packaging system.

### Carvel

The `kctrl` utility from [Carvel suite](https://carvel.dev) is being used to author packages in combination with other tools in the suite (i.e. `ytt`).

The metadata files required to create the package are stored as [ytt templates](../config/carvel/)
to easily define a standard to create multiple packages.

**N.B. Each package MUST have its own `PackageMetadata` manifest stored in the
`package-metadata.yml` file, located in the package's main directory.**

This file will be included in the actual package as well as used for holding information
that is required to fill some fields in other template files, in a DRY fashion.

*DRY: Don't Repeat Yourself

The `config` directory inside the package home holds the ytt files that define the resources
that will be created by the package installation as well as the schema definition for the input values.

**N.B. The name of such a folder MUST be `config`, as it is hardcoded in the mentioned templates.**

The command used to build the package and publish it to the container registry is `make kctrl-release`,
which uses a few environment variables for configuration.
The following snippet defines a quick way of building all the `carvel` packages in the `packages` folder.
Additionally, it uploads the packages to the ghcr.io service in the `org/repository` repository (do adjust it to your own account),
in a hierarchy that reflects the filesystem.

```sh
PACKAGE_REGISTRY="ghcr.io"
for PACKAGE_DIR in $(find packages -type d -mindepth 3 -maxdepth 3); do
  if [[ $(cut -d/ -f3 <<<${PACKAGE_DIR}) == "carvel" ]]; then
    PACKAGE_REPOSITORY="org/repository/${PACKAGE_DIR#packages/}"
    make kctrl-release
  fi
done
```

You must be authenticated to ghcr.io and you must have the correct permissions to write packages to `org`.
The authentication credentials can be provided either via [Docker login][docker-login] or via [`imgpkg` environment variables][imgpkg-auth-env], for example:

```sh
export IMGPKG_REGISTRY_HOSTNAME="ghcr.io"
export IMGPKG_REGISTRY_USERNAME="my-username"
export IMGPKG_REGISTRY_PASSWORD="my-personal-access-token"
```

[imgpkg-auth-env]: https://carvel.dev/imgpkg/docs/v0.34.0/auth/#via-environment-variables
[docker-login]: https://docs.docker.com/engine/reference/commandline/login/
