TEST_APP_NAME=$1

echo ">> Waiting on Test Application: ${TEST_APP_NAME}"
kubectl get pod 
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=${TEST_APP_NAME} --timeout=60s

echo ">> Starting Port Forward"
kubectl port-forward deployment/${TEST_APP_NAME} 8080 &
PORT_FORWARD_PID=$!

sleep 10

echo ">> Testing Application"
curl -s "http://localhost:8080"
curl --header "Content-Type: application/json" --request POST --data '{"name":"Piet"}' http://localhost:8080/create
curl --header "Content-Type: application/json" --request POST --data '{"name":"Andrea"}' http://localhost:8080/create
HTTP_RESULT=$(curl -s "http://localhost:8080")
[ $(jq 'map(select(.name =="Piet")) | length'<<<$HTTP_RESULT) -eq 1 ]
[ $(jq 'map(select(.name =="Andrea")) | length'<<<$HTTP_RESULT) -eq 1 ]

echo ">> Killing Port Forward"
echo " > PORT_FORWARD_PID=$PORT_FORWARD_PID"
kill -9 $PORT_FORWARD_PID