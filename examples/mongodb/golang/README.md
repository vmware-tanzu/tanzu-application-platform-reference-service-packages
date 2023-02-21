# Sample MongoDB App

## Docker build image

Build a new docker image locally with the sample mongodb app:

```shell
docker buildx build . --platform linux/amd64 --tag <IMAG NAME>:<IMAGE TAG>
```

And then push this new image or use a CI system to build and push based on whateveer trigger.

```shell
docker push <IMAG NAME>:<IMAGE TAG>
```

## Out Of the Box images

Github Actions automate the build of the sample_apps-mongo app. All images can be found and pull from:

```text
https://github.com/bzhtux/sample_apps/pkgs/container/sample_apps-mongodb/versions
```

```shell
docker pull ghcr.io/bzhtux/sample_apps-mongo:<version>
```

## Test it locally

### Create a kind cluster

```yaml
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mongodb-service-binding
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
- role: worker
EOF
```

Now use this new cluster changing the  kubernetes context as below:

```shell
kubectl cluster-info --context kind-mongodb-service-binding
```

### Namespace

Create a new `namespace` to deploy the sample_apps-mongo :

```shell
kubectl create namespace mongo-app
```

Update kubernetes conntext to use this new namespace:

```shell
kubectl config set-context --current --namespace=mongo-app
```

### Deploy MongoDB using helm

Add bitnami helm repo:

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Then install MongoDB:

```shell
helm install mongodb bitnami/mongodb
```

MongoDB can be accessed on the following DNS names from within your cluster:

* `mongodb.mongo-app.svc.cluster.local`

To get your password run the following command:

```shell
export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace mongo-app mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)
```

Write down the MongoDB host from previous output:

```text
[...]
mongodb.mongo-app.svc.cluster.local
[...]
```

Get the MongoDB password:

```shell
kubectl get secret --namespace mongo-app mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d
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
apiVersion: v1
kind: Service
metadata:
  name: mongo-app-svc
spec:
  ports:
  - name: mongo-app
    port: 8080
    targetPort: 8080
  selector:
    app: mongo-app
    app.kubernetes.io/name: mongo-app
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
  - host: gomongo.127.0.0.1.nip.io
    http:
      paths:
      - backend:
          service:
            name: mongo-app-svc
            port:
              number: 8080
        pathType: Prefix
        path: /
```

### Define MongoDB configuration

Define connection informations and crededentials within the k8s/01.secret.yaml as below:

```shell
export MONGO_HOST=$(echo -n "mongodb-0.mongodb-svc.mongo-app.svc.cluster.local" | base64)
export MONGO_USERNAME=$(echo -n "gomongo" | base64)
export MONGO_PASSWORD=$(echo -n "X015TW9uZ29TZWNyZXRQYXNzXw==")
export MONGO_PORT=$(echo -n 27017 |  base64)
export MONGO_TYPE=$(echo -n mongodb | base64)
export MONGO_DB=$(echo -n gomongo | base64)
```

### Deploy in k8s kind

```yaml
cat <<EOF | kubectl apply -f-
---
apiVersion: v1
kind: Secret
metadata:
  name: gomongo
data:
  host: $MONGO_HOST
  port: $MONGO_PORT
  username: $MONGO_USERNAME
  password: $MONGO_PASSWORD
  database: $MONGO_DB
  uri: ""
  type: $MONGO_TYPE
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gomongo
spec:
  strategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: gomongo
      app.kubernetes.io/name: gomongo
  template:
    metadata:
      labels:
        app: gomongo
        app.kubernetes.io/name: gomongo
    spec:
      containers:
      - name: gomongo
        image: bzhtux/gomongo-arm64:0.0.2
        imagePullPolicy: Always
        volumeMounts:
        - name: services-bindings
          mountPath: /bindings
          readOnly: true
        env:
        - name: SERVICE_BINDING_ROOT
          value: /bindings
      volumes:
      - name: services-bindings
        projected:
          sources:
          - secret:
              name: gomongo
              items:
              - key: host
                path: mongodb/host
              - key: port
                path: mongodb/port
              - key: username
                path: mongodb/username
              - key: password
                path: mongodb/password
              - key: database
                path: mongodb/database
              - key: uri
                path: mongodb/uri
              - key: type
                path: mongodb/type
---
apiVersion: v1
kind: Service
metadata:
  name: gomongo
spec:
  ports:
  - name: gomongo
    port: 8080
    targetPort: 8080
  selector:
    app: gomongo
    app.kubernetes.io/name: gomongo
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gomongo
spec:
  ingressClassName: contour
  rules:
  - host: gomongo.127.0.0.1.nip.io
    http:
      paths:
      - backend:
          service:
            name: gomongo
            port:
              number: 8080
        pathType: Prefix
        path: /
EOF
```

Test the deployment:

```shell
curl -sL http://gomongo.127.0.0.1.nip.io/ | jq .
{
  "message": "Alive",
  "status": "Up"
}
```

Run the following tests:

```json
curl -sL -X POST -d '{"Title": "Hello world ", "Author":"bzhtux"}' http://gomongo.127.0.0.1.nip.io/add | jq .
{
  "data": {
    "Book Author": "bzhtux",
    "Book title": "Hello world",
    "ID": "63515b321a0c3cb17aa08a5b",
    "result": {
      "InsertedID": "63515b321a0c3cb17aa08a5b"
    }
  },
  "message": "New book added to books' collection",
  "status": "OK"
}
curl -sL -X POST -d '{"Title": "Hello world", "Author":"bzhtux"}' http://127.0.0.1.nip.io/add | jq .
{
  "message": "Book Hello world already exists.",
  "status": "Conflict"
}
curl -sL http://gomongo.127.0.0.1.nip.io:8080/get/byID/63515b321a0c3cb17aa08a5b | jq .
{
  "data": {
    "Author": "bzhtux",
    "ID": "63515b321a0c3cb17aa08a5b",
    "Title": "Hello world"
  },
  "message": "Got doc from mongoDB",
  "status": "Ok"
}
curl -sL -X DELETE http://gomongo.127.0.0.1.nip.io/del/byName/Hello%20world | jq .
{
  "message": "Doc deleted from mongoDB",
  "status": "Ok"
}
```
