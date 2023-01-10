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
