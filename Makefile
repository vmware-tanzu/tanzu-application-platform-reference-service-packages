LOCAL_VERSION = $(shell git describe --tags --always)
PACKAGE_VERSION ?= "0.0.0-${LOCAL_VERSION}"
PACKAGE_REPOSITORY ?= "vmware-tanzu-labs/trp-azure-psql"
PACKAGE_REGISTRY ?= "ghcr.io"
CLOUD_NAME = azure

PACKAGES_DIR = ./packages
PACKAGE_DIR = ${PACKAGES_DIR}/${PACKAGE_NAME}
PACKAGE_BUILD_BASE_DIR = ./package-build
PACKAGE_BUILD_DIR = ${PACKAGE_BUILD_BASE_DIR}/${PACKAGE_NAME}
PACKAGE_METADATA_DIR = ${PACKAGE_DIR}/package-metadata
PACKAGES_REPO_STAGING_DIR = ./packages-repo
TEMPLATES_DIR = ${PACKAGE_DIR}/package-templates

PACKAGE_TEST_DATA_DIR_NAME = test-data
REPOSITORY_DIR = ../tap-reference-packages-repository
REPOSITORY_CLOUD_DIR = ${REPOSITORY_DIR}/repository/packages/${CLOUD_NAME}

SHELL := $(shell which bash)

KDEV_SA_NAME=development
KDEV_SA_NAMESPACE=default

DEV_PACKAGE_NAME ?= ${PACKAGE_NAME}
DEV_NAMESPACE ?= default

# validate-input:
# 	@# echo "PACKAGE_NAME is ${PACKAGE_NAME}"
# 	@# echo "PACKAGES_DIR is ${PACKAGES_DIR}"
# 	@# echo ""${PACKAGES_DIR}/${PACKAGE_NAME}" is directory:" $(shell [ -d "${PACKAGES_DIR}/${PACKAGE_NAME}" ] && echo "true" || echo "false")
# 	@[ -z "${PACKAGE_NAME}" ] && (echo "PACKAGE_NAME is empty" && exit 1)
# 	@[ -d "${PACKAGES_DIR}/${PACKAGE_NAME}" ] || $(shell echo "${PACKAGES_DIR}/${PACKAGE_NAME} directory does not exist" && exit 2)

clean:
	rm -f ${PACKAGE_DIR}/package-kdev.yml  || true
	rm -f ${PACKAGE_DIR}/package-build.yml || true
	rm -f ${PACKAGE_DIR}/package-resources.yml || true
	rm -rf ${PACKAGE_BUILD_DIR} || true
	rm -rf ${PACKAGE_DIR}/carvel-artifacts/  || true
	rm -rf ${PACKAGE_DIR}/bundle-*   || true
	rm -rf ${PACKAGES_REPO_STAGING_DIR} || true
	mkdir -p ${PACKAGES_REPO_STAGING_DIR}

dev: clean
	kubectl create namespace ${DEV_PACKAGE_NAME} || true
	ytt -f ${PACKAGE_DIR}/config -f ${PACKAGE_DIR}/test-data | kbld -f - | kapp deploy -a ${DEV_PACKAGE_NAME} -n ${DEV_NAMESPACE} --debug -y -f -

dev-cleanup:
	kapp delete -a ${DEV_PACKAGE_NAME} -n ${DEV_NAMESPACE} -y

kdev-prepare: clean
	yq e '... comments="" | .spec.template.spec.template[] |= select(.ytt != null).ytt.paths += "test-data"' ${PACKAGE_DIR}/package.yml > ${PACKAGE_DIR}/package-kdev.yml
	cd ${PACKAGE_DIR} && ytt -f package-kdev.yml -f package-metadata.yml -f package-install.yml > package-resources.yml

kdev: kdev-prepare
	cd ${PACKAGE_DIR} && kctrl dev -f package-resources.yml -l

kdev-cleanup: kdev-prepare
	cd ${PACKAGE_DIR} && kctrl dev -f package-resources.yml -l --delete

imgpkg-push-prepare:
	mkdir -p ${PACKAGE_BUILD_DIR}/.imgpkg
	cp -a ${PACKAGE_DIR}/config ${PACKAGE_BUILD_DIR}
	kbld -f ${PACKAGE_BUILD_DIR}/config/ --imgpkg-lock-output ${PACKAGE_BUILD_DIR}/.imgpkg/images.yml

imgpkg-push: imgpkg-push-prepare
	imgpkg push -b ${PACKAGE_REGISTRY}/${PACKAGE_REPOSITORY}:${PACKAGE_VERSION} -f ${PACKAGE_BUILD_DIR}/

release-prepare:
	cd ${PACKAGE_DIR} && ytt -f package.yml -f package-metadata.yml -f package-install.yml > package-resources.yml
	cd ${PACKAGE_DIR} && ytt -f package-build.ytt.yml -f package-build-schema.yml \
		-v package_fqdn=$(shell yq e .metadata.name ${PACKAGE_DIR}/package-metadata.yml) \
		-v repository=${PACKAGE_REPOSITORY} -v registry=${PACKAGE_REGISTRY} > package-build.yml
	mkdir -p ${PACKAGE_DIR}/.imgpkg
	kbld -f ${PACKAGE_DIR}/config/ --imgpkg-lock-output ${PACKAGE_DIR}/.imgpkg/images.yml

# Does not use the version, and thus cannot be used until kctrl fixes that
kctrl-release: release-prepare
	kctrl package release --chdir "${PACKAGE_DIR}" --version="${PACKAGE_VERSION}" --repo-output="${PWD}/${PACKAGES_REPO_STAGING_DIR}" -y

create-kdev-sa:
	kubectl create serviceaccount ${KDEV_SA_NAME} -n ${KDEV_SA_NAMESPACE} || true
	kubectl delete clusterrolebinding kdev-cluster-admin || true
	kubectl create clusterrolebinding kdev-cluster-admin --clusterrole=cluster-admin --serviceaccount=${KDEV_SA_NAMESPACE}:${KDEV_SA_NAME}

repo-prepare:
	mkdir -p ${REPOSITORY_CLOUD_DIR}

repo-package-copy: repo-prepare
	cp -a ${PACKAGES_REPO_STAGING_DIR}/packages/$(shell yq e .metadata.name ${PACKAGE_DIR}/package-metadata.yml)/ ${REPOSITORY_CLOUD_DIR}/${PACKAGE_NAME}

crossplane-ytt:
	mkdir -p ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/src/
	ytt -f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/crossplane.ytt.yml \
		-f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/schema.ytt.yml > ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/src/crossplane.yml
	ytt -f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/definition.ytt.yml \
		-f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/schema.ytt.yml > ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/src/definition.yml
	ytt -f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/composition.ytt.yml \
		-f ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/ytt/schema.ytt.yml > ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/src/composition.yml

crossplane-build: crossplane-ytt
	rm ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/package/*.xpkg || true
	mkdir -p ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/package
	up xpkg build \
		--package-root ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/src \
		--examples-root ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/claim-examples \
		--output ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/package/crossplane-${PACKAGE_NAME}.xpkg

crossplane-push:
	up xpkg push --package ${PACKAGE_PROVIDER}/crossplane/${PACKAGE_NAME}/package/crossplane-${PACKAGE_NAME}.xpkg \
		${PACKAGE_REGISTRY}/${PACKAGE_REPOSITORY}:${PACKAGE_VERSION} \
		--domain ${PACKAGE_REGISTRY}