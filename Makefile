# LOCAL_VERSION = $(shell git describe --tags --always)
# PACKAGE_VERSION ?= "0.0.0-${LOCAL_VERSION}"
# PACKAGE_REPOSITORY ?= "vmware-tanzu-labs/trp-azure-psql"
# PACKAGE_REGISTRY ?= "ghcr.io"
# CLOUD_NAME = azure
# 
# PACKAGES_DIR ?= ./packages
# PACKAGE_DIR ?= ${PACKAGES_DIR}/${PACKAGE_NAME}
# RELEASE_DIR = ${PACKAGE_DIR}/.release
# 
# PACKAGE_BUILD_BASE_DIR = ./package-build
# PACKAGE_BUILD_DIR = ${PACKAGE_BUILD_BASE_DIR}/${PACKAGE_NAME}
# 
# PACKAGE_TEST_DATA_DIR_NAME = test-data
# REPOSITORY_DIR = ../tap-reference-packages-repository
# REPOSITORY_CLOUD_DIR = ${REPOSITORY_DIR}/repository/packages/${CLOUD_NAME}
# 
# SHELL := $(shell which bash)
# 
# KDEV_SA_NAME=development
# KDEV_SA_NAMESPACE=default
# 
# DEV_PACKAGE_NAME ?= ${PACKAGE_NAME}
# DEV_NAMESPACE ?= default



# clean:
# 	rm -f ${PACKAGE_DIR}/package-kdev.yml  || true
# 	rm -f ${PACKAGE_DIR}/package-build.yml || true
# 	rm -f ${PACKAGE_DIR}/package-resources.yml || true
# 	rm -rf ${PACKAGE_BUILD_DIR} || true
# 	rm -rf ${PACKAGE_DIR}/carvel-artifacts/  || true
# 	rm -rf ${PACKAGE_DIR}/bundle-*   || true
# 	rm -rf ${PACKAGES_REPO_STAGING_DIR} || true
# 	mkdir -p ${PACKAGES_REPO_STAGING_DIR}
# 
# dev: clean
# 	kubectl create namespace ${DEV_PACKAGE_NAME} || true
# 	ytt -f ${PACKAGE_DIR}/config -f ${PACKAGE_DIR}/test-data | kbld -f - | kapp deploy -a ${DEV_PACKAGE_NAME} -n ${DEV_NAMESPACE} --debug -y -f -
# 
# dev-cleanup:
# 	kapp delete -a ${DEV_PACKAGE_NAME} -n ${DEV_NAMESPACE} -y
# 
# kdev-prepare: clean
# 	yq e '... comments="" | .spec.template.spec.template[] |= select(.ytt != null).ytt.paths += "test-data"' ${PACKAGE_DIR}/package.yml > ${PACKAGE_DIR}/package-kdev.yml
# 	cd ${PACKAGE_DIR} && ytt -f package-kdev.yml -f package-metadata.yml -f package-install.yml > package-resources.yml
# 
# kdev: kdev-prepare
# 	cd ${PACKAGE_DIR} && kctrl dev -f package-resources.yml -l
# 
# kdev-cleanup: kdev-prepare
# 	cd ${PACKAGE_DIR} && kctrl dev -f package-resources.yml -l --delete
# 
# create-kdev-sa:
# 	kubectl create serviceaccount ${KDEV_SA_NAME} -n ${KDEV_SA_NAMESPACE} || true
# 	kubectl delete clusterrolebinding kdev-cluster-admin || true
# 	kubectl create clusterrolebinding kdev-cluster-admin --clusterrole=cluster-admin --serviceaccount=${KDEV_SA_NAMESPACE}:${KDEV_SA_NAME}
# 
# repo-prepare:
# 	mkdir -p ${REPOSITORY_CLOUD_DIR}
# 
# repo-package-copy: repo-prepare
# 	cp -a ${PACKAGES_REPO_STAGING_DIR}/packages/$(shell yq e .metadata.name ${PACKAGE_DIR}/package-metadata.yml)/ ${REPOSITORY_CLOUD_DIR}/${PACKAGE_NAME}



# imgpkg-push-prepare:
# 	mkdir -p ${PACKAGE_BUILD_DIR}/.imgpkg
# 	cp -a ${PACKAGE_DIR}/config ${PACKAGE_BUILD_DIR}
# 	kbld -f ${PACKAGE_BUILD_DIR}/config/ --imgpkg-lock-output ${PACKAGE_BUILD_DIR}/.imgpkg/images.yml
# 
# imgpkg-push: imgpkg-push-prepare
# 	imgpkg push -b ${PACKAGE_REGISTRY}/${PACKAGE_REPOSITORY}:${PACKAGE_VERSION} -f ${PACKAGE_BUILD_DIR}/

PACKAGES_BASEDIR ?= packages
PACKAGE_DIR ?= ${PACKAGES_BASEDIR}/${PACKAGE_PROVIDER}/${PACKAGE_PACKAGING}/${PACKAGE_NAME}

CARVEL_REPO_DIR ?= repository

#TODO purge older versions according to a TBD retention policy

kctrl-release-prepare:
	ytt --data-values-file ${PACKAGE_DIR}/package-metadata.yml -f config/carvel/package-resources -f ${PACKAGE_DIR}/package-metadata.yml -v version=${PACKAGE_VERSION} > ${PACKAGE_DIR}/package-resources.yml
	ytt --data-values-file ${PACKAGE_DIR}/package-metadata.yml -f config/carvel/package-build -v registry=${PACKAGE_REGISTRY} -v repository=${PACKAGE_REPOSITORY} > ${PACKAGE_DIR}/package-build.yml

kctrl-release: kctrl-release-prepare
	kctrl package release --chdir "${PACKAGE_DIR}" --version="${PACKAGE_VERSION}" --tag="${PACKAGE_VERSION}" --repo-output="${PWD}/${CARVEL_REPO_DIR}" -y

kctrl-repo-release-prepare:
	mkdir -p ${CARVEL_REPO_DIR}
	ytt -f config/carvel/pkgrepo-build -v name=${CARVEL_REPO_NAME} -v registry=${CARVEL_REPO_REGISTRY} -v repository=${CARVEL_REPO_REPOSITORY} > ${CARVEL_REPO_DIR}/pkgrepo-build.yml

kctrl-repo-release: kctrl-repo-release-prepare
	kctrl package repository release --chdir ${CARVEL_REPO_DIR} -v ${CARVEL_REPO_VERSION} -y

# yq -i '.spec.fetch.imgpkgBundle.image=(.spec.fetch.imgpkgBundle.image|split("@")|.[0])+":"+.metadata.annotations."kctrl.carvel.dev/repository-version"' ${REPO_BASEDIR}/package-repository.yml

crossplane-ytt:
	rm -rf ${PACKAGE_DIR}/.src || true
	mkdir -p ${PACKAGE_DIR}/.src

	ytt -f ${PACKAGE_DIR}/ytt > ${PACKAGE_DIR}/.src/crossplane.yml

crossplane-build: crossplane-ytt
	rm -rf ${PACKAGE_DIR}/.package || true
	mkdir -p ${PACKAGE_DIR}/.package

	up xpkg build \
		--package-root ${PACKAGE_DIR}/.src \
		--examples-root ${PACKAGE_DIR}/claim-examples \
		--output ${PACKAGE_DIR}/.package/crossplane.xpkg

crossplane-push: crossplane-build
	up xpkg push --package ${PACKAGE_DIR}/.package/crossplane.xpkg \
		${PACKAGE_REGISTRY}/${PACKAGE_REPOSITORY}:${PACKAGE_VERSION} \
