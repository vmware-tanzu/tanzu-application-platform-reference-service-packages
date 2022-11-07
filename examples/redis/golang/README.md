# Sample Redis App

Sample Redis App's purpose is testing AWS Elasticache reference package using this [Golang service binding](github.com/bzhtux/servicebinding/bindings) module.

## Docker build image

To containerize this sample Redis app use the `Dockerfile` below:

```docker
# builder
FROM golang:alpine AS build-env
LABEL maintainer="Yannick Foeillet <yfoeillet@vmware.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add build-base git mercurial gcc curl
RUN mkdir -p /go/src/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang
ADD . /go/src/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang
WORKDIR /go/src/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang 
RUN go get -v -u ./...
RUN go build -o redis-app cmd/main.go


# final image
FROM alpine
LABEL maintainer="Yannick Foeillet <yfoeillet@vmware.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add curl jq
RUN adduser -h /app -s /bin/sh -u 1000 -D app
RUN mkdir -p /config
COPY config/redis.yaml /config/
WORKDIR /app
COPY --from=build-env /go/src/vmware-tanzu/tanzu-application-platform-reference-service-packages/examples/redis/Golang/redis-app /app/
USER 1000
ENTRYPOINT ./redis-app
```

Build it running the following command:

```shell
docker buildx build . --platform linux/amd64 --tag <IMAG NAME>:<IMAGE TAG>
```


## Out Of the Box images

Github Actions automate the build of the sample_apps-redis app. All images can be retrieved [here](https://github.com/bzhtux/sample_apps/pkgs/container/sample_apps-redis/versions).

```text

```

```shell
docker pull ghcr.io/bzhtux/sample_apps-redis:<version>
```

## Test it locally

### Create a kind cluster

```yaml
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
```

Now use this new cluster changing the  kubernetes context as below:

```shell
kubectl cluster-info --context kind-kind
```

### Namespace

Create a new `namespace` to deploy the sample_apps-redis with a Redis DB:

```shell
kubectl create namespace redis-app
```

Update kubernetes conntext to use this new namespace:

```shell
kubectl config set-context --current --namespace=redis-app
```

### Deploy Redis using helm

Add bitnami helm repo:

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Then install Redis:

```shell
helm install redis bitnami/redis
```

Redis can be accessed on the following DNS names from within your cluster:

* `redis-master.redis-app.svc.cluster.local for read/write operations (port 6379)`
* `redis-replicas.redis-app.svc.cluster.local for read-only operations (port 6379)`

To get your password run the following command:

```shell
export REDIS_PASSWORD=$(kubectl get secret --namespace redis-app redis -o jsonpath="{.data.redis-password}" | base64 -d)
```

Write down the Redis host from peevious output:

```text
[...]
redis-master.redis-app.svc.cluster.local
[...]
```

Get the Redis password:

```shell
kubectl get secret --namespace redis-app redis -o jsonpath="{.data.redis-password}" | base64 -d
```

### Use Contour as the Ingress controller

Deploy Contour components:

```shell
kubectl apply -f https://projectcontour.io/quickstart/contour.yaml
```

Apply kind specific patches to forward the hostPorts to the ingress controller, set taint tolerations and schedule it to the custom labelled node.

```json
{
  "spec": {
    "template": {
      "spec": {
        "nodeSelector": {
          "ingress-ready": "true"
        },
        "tolerations": [
          {
            "key": "node-role.kubernetes.io/control-plane",
            "operator": "Equal",
            "effect": "NoSchedule"
          },
          {
            "key": "node-role.kubernetes.io/master",
            "operator": "Equal",
            "effect": "NoSchedule"
          }
        ]
      }
    }
  }
}
```

```shell
kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Equal","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```

### Ingress usage

The following example creates a simple http service and an Ingress object to route to this services.

```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: redis-app-svc
spec:
  selector:
    app: redis-app
    app.kubernetes.io/name: redis-app
  ports:
  # Default port used by the image
  - port: 8080
```

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-apps-ingress
spec:
  ingressClassName: contour
  rules:
  - host: goredis.127.0.0.1.nip.io
    http:
      paths:
      - backend: 
          service:
            name: redis-app-svc
            port:
              number: 8080
        pathType: Prefix
        path: /
```

### Define Redis configuration

Define connection informations and crededentials within the k8s/01.secret.yaml as below:

```shell
export REDIS_HOST=$(echo -n "redis-master.redis-app.svc.cluster.local" | base64)
export REDIS_USER=$(echo -n "default" | base64)
export REDIS_PASS=$(echo -n "${REDIS_PASSWORD}" | base64)
export REDIS_PORT=$(echo -n "6379" |  base64)
export REDIS_DB=$(echo -n "0" | base64)
export REDIS_SSL=$(echo -n "false" | base64)
export REDIS_TYPE=$(echo -n "redis" | base64)
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
data:
  host: ${REDIS_HOST}
  port: ${REDIS_PORT}
  username: ${REDIS_USER}
  password: ${REDIS_PASS}
  database: ${REDIS_DB}
  sslenabled: ${REDIS_SSL}
  type: ${REDIS_TYPE}
```

### Deploy in k8s kind


Apply secret first:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: Secret
metadata:
  name: redis-secret
data:
  host: ${REDIS_HOST}
  port: ${REDIS_PORT}
  username: ${REDIS_USER}
  password: ${REDIS_PASS}
  database: ${REDIS_DB}
  sslenabled: ${REDIS_SSL}
  type: ${REDIS_TYPE}
EOF
```

Then apply the deployment :

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-app
spec:
  selector:
    matchLabels:
      app: redis-app
      app.kubernetes.io/name: redis-app
  template:
    metadata:
      labels:
        app: redis-app
        app.kubernetes.io/name: redis-app
    spec:
      containers:
      - name: redis-app
        image: ghcr.io/bzhtux/sample_apps-redis:v0.0.7
        volumeMounts:
        - name: services-bindings
          mountPath: "/bindings"
          readOnly: true
        env:
          - name: SERVICE_BINDING_ROOT
            value: "/bindings"
      volumes:
      - name: services-bindings
        projected:
          sources:
          - secret:
              name: redis-secret
              items:
                - key: host
                  path: redis/host
                - key: port
                  path: redis/port
                - key: username
                  path: redis/username
                - key: password
                  path: redis/password
                - key: database
                  path: redis/database
                - key: sslenabled
                  path: redis/ssl
                - key: type
                  path: redis/type
EOF
```

Now configure a k8s service:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: Service
metadata:
  name: redis-app-svc
spec:
  ports:
  - name: redis-app
    port: 8080
    targetPort: 8080
  selector:
    app: redis-app
    app.kubernetes.io/name: redis-app
EOF
```

And finish with setting an ingress:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-apps-ingress
spec:
  ingressClassName: contour
  rules:
  - host: goredis.127.0.0.1.nip.io
    http:
      paths:
      - backend: 
          service:
            name: redis-app-svc
            port:
              number: 8080
        pathType: Prefix
        path: /
EOF
```

Test the deployment:

```shell
curl -sL http://goredis.127.0.0.1.nip.io/ | jq .
{
  "message": "Alive",
  "status": "Up"
}
```

Set up `APP_HOST` and `APP_PORT` for running some test commands:

```shell
export APP_HOST="goredis.127.0.0.1.nip.io"
export APP_PORT="80"
```

Add a new key:

```shell
curl -sL -X POST -d '{"key": "key1", "value": "val1"}'  http://"${APP_HOST}":"${APP_PORT}"/add | jq .
```

Expected result:

```json
{
  "data": {
    "key": "key1",
    "value": "val1"
  },
  "message": "New key has been recorded successfuly",
  "status": "OK"
}
```

Try to add twice the same key (expect a conflict):

```shell
curl -sL -X POST -d '{"key": "key1", "value": "val1"}'  http://"${APP_HOST}":"${APP_PORT}"/add | jq .
```

Expected result:

```json
{
  "message": "Key already exists: key1",
  "status": "Conflict"
}
```

Get the fresh added key:

```shell
curl -sL http://"${APP_HOST}":"${APP_PORT}"/get/key1 | jq .
```

Expected result:

```json
{
  "data": {
    "key": "key1",
    "value": "val1"
  },
  "message": "Key was found",
  "status": "Ok"
}
```

Now delete the key1:

```shell
curl -sL -X DELETE http://"${APP_HOST}":"${APP_PORT}"/del/key1 | jq .
```

Expected result:

```json
{
  "message": "Key was successfuly deleted: key1",
  "status": "Ok"
}
```

If everything is ok, safely remove the kind cluster:

```shell
kind delete cluster --name=kind
```
