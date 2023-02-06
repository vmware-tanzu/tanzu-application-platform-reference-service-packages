#!/usr/bin/env bash

set -euo pipefail

pushd $(dirname $0)

TEST_APP_NAME=${TEST_APP_NAME:-"spring-boot-mongo"}

echo ">> Installing Test Application"
MANIFEST="https://raw.githubusercontent.com/joostvdg/spring-boot-postgres/main/kubernetes/deployment.yaml"
curl -sSfL ${MANIFEST} | ytt -f - -f app-overlay.ytt.yml -v name=${TEST_APP_NAME} -v secret=${CLAIM_NAME} | kubectl apply -n default -f -
kubectl get deployment

echo ">> Waiting on Test Application: ${TEST_APP_NAME}"
kubectl get pod 
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=${TEST_APP_NAME} --timeout=300s

kubectl describe pod -l app.kubernetes.io/name=${TEST_APP_NAME} 
sleep 10

echo ">> Starting Port Forward"
kubectl port-forward deployment/${TEST_APP_NAME} 8080 &
PORT_FORWARD_PID=$!

sleep 10

echo ">> Testing Application"
curl -sSfL "http://localhost:8080" && echo
echo -n ">> Writing record: " && curl -sSfL --header "Content-Type: application/json" --request POST --data '{"name":"Piet"}' http://localhost:8080/create && echo
echo -n ">> Writing record: " && curl -sSfL --header "Content-Type: application/json" --request POST --data '{"name":"Andrea"}' http://localhost:8080/create && echo

HTTP_RESULT=$(curl -sSfL "http://localhost:8080")
[ $(jq 'map(select(.name == "Piet")) | length'<<<$HTTP_RESULT) -eq 1 ]
[ $(jq 'map(select(.name == "Andrea")) | length'<<<$HTTP_RESULT) -eq 1 ]

echo "TEST PASSED"

echo ">> Killing Port Forward"
echo " > PORT_FORWARD_PID=$PORT_FORWARD_PID"
kill -9 $PORT_FORWARD_PID

popd
