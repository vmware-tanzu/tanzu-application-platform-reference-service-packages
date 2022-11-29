#!/usr/bin/env bash

SECRET_NAME=$1
CREDS=$2
CROSSPLANE_NAMESPACE=${CROSSPLANE_NAMESPACE:-upbound-system}

if [ ! -x ${CREDS} ]; then
    echo ">> Create Azure Config Secret - secret name=${SECRET_NAME}"
    kubectl create secret generic ${SECRET_NAME} -n ${CROSSPLANE_NAMESPACE} --from-literal=creds=${CREDS}
fi
