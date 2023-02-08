#!/usr/bin/env bash

set -euo pipefail

pushd $(dirname $0)

SECRET_NAME=$1
TEST_APP_NAME=${2:-${SECRET_NAME}}
APP_NAMESPACE=${APP_NAMESPACE:-default}

echo ">> Installing Test Application"
MANIFEST="https://raw.githubusercontent.com/joostvdg/spring-boot-postgres/main/kubernetes/deployment.yaml"
curl -sSfL ${MANIFEST} | ytt -f - -f app-overlay.ytt.yml -v name=${TEST_APP_NAME} -v secret=${SECRET_NAME} | kubectl apply -n ${APP_NAMESPACE} -f -

kubectl -n ${APP_NAMESPACE} get deployments.apps

echo ">> Waiting on Test Application: ${TEST_APP_NAME}"
kubectl -n ${APP_NAMESPACE} get pods
kubectl -n ${APP_NAMESPACE} wait --for=condition=Ready pods -l app.kubernetes.io/name=${TEST_APP_NAME} --timeout=300s

kubectl -n ${APP_NAMESPACE} describe pods -l app.kubernetes.io/name=${TEST_APP_NAME} 
sleep 10

echo ">> Starting Port Forward"
kubectl -n ${APP_NAMESPACE} port-forward deployment/${TEST_APP_NAME} 8080 &
PORT_FORWARD_PID=$!
trap "echo '>> Killing Port Forward' && kill -9 ${PORT_FORWARD_PID}" EXIT

sleep 10

echo ">> Testing Application"
curl -sSfL "http://localhost:8080" && echo
echo -n ">> Writing record: " && curl -sSfL --header "Content-Type: application/json" --request POST --data '{"name":"Piet"}' http://localhost:8080/create && echo
echo -n ">> Writing record: " && curl -sSfL --header "Content-Type: application/json" --request POST --data '{"name":"Andrea"}' http://localhost:8080/create && echo

HTTP_RESULT=$(curl -sSfL "http://localhost:8080")
[ $(jq 'map(select(.name == "Piet")) | length'<<<$HTTP_RESULT) -eq 1 ]
[ $(jq 'map(select(.name == "Andrea")) | length'<<<$HTTP_RESULT) -eq 1 ]

echo "TEST PASSED"

popd
