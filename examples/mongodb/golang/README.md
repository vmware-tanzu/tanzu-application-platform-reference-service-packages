# Sample MongoDB App

## Docker build image

Build a new docker image locally with the sample redis app:

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
https://github.com/bzhtux/sample_apps/pkgs/container/sample_apps-redis/versions
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

Then install Redis:

```shell
helm install mongodb bitnami/mongodb
```

```text
** Please be patient while the chart is being deployed **

MongoDB&reg; can be accessed on the following DNS name(s) and ports from within your cluster:

    mongodb.mongo-app.svc.cluster.local

To get the root password run:

    export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace mongo-app mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 -d)

To connect to your database, create a MongoDB&reg; client container:

    kubectl run --namespace mongo-app mongodb-client --rm --tty -i --restart='Never' --env="MONGODB_ROOT_PASSWORD=$MONGODB_ROOT_PASSWORD" --image docker.io/bitnami/mongodb:6.0.3-debian-11-r0 --command -- bash

Then, run the following command:
    mongosh admin --host "mongodb" --authenticationDatabase admin -u root -p $MONGODB_ROOT_PASSWORD

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace mongo-app svc/mongodb 27017:27017 &
    mongosh --host 127.0.0.1 --authenticationDatabase admin -p $MONGODB_ROOT_PASSWORD
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

### Define Redis configuration

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
```

## Kapp and Kapp-controller

### Deploy kapp

```shell
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/v0.42.0/release.yml -y
```

### Create a carvel package for the App

Create a `config.yml` file like this:

```yaml
cat > config.yml << EOF
#@ load("@ytt:data", "data")
#@ load("@ytt:base64", "base64")

#@ def labels():
go-mongo: ""
app: #@ data.values.app.name
app.kubernetes.io/name: #@ data.values.app.name
#@ end
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: #@ data.values.app.name
spec:
  strategy:
    type: RollingUpdate
  selector:
    matchLabels: #@ labels()
  template:
    metadata:
      labels: #@ labels()
    spec:
      containers:
      - name: #@ data.values.app.name
        image: ghcr.io/bzhtux/sample_apps-mongo:v0.0.7
        imagePullPolicy: Always
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
              name: #@ data.values.app.name
              items:
                #@ for/end i in data.values.service.secret:
                - key: #@ i
                  path: #@ data.values.service.secret.type+"/" + i
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: #@ data.values.app.name
spec:
  ingressClassName: contour
  rules:
    - host: #@ data.values.app.name + ".bzhtux-lab.net"
      http:
        paths:
          - backend:
              service:
                name: #@ data.values.app.name
                port:
                  number: #@ data.values.app.port
            pathType: Prefix
            path: /
---
apiVersion: v1
kind: Secret
metadata:
  name: #@ data.values.app.name
data:
  host: #@ base64.encode(data.values.service.name + "-svc." + data.values.service.namespace + ".svc.cluster.local")
  port: #@ base64.encode(str(data.values.service.secret.port))
  username: #@ base64.encode(data.values.service.secret.username)
  password: #@ base64.encode(data.values.service.secret.password)
  database: #@ base64.encode(data.values.service.secret.database)
  uri: #@ base64.encode(data.values.service.secret.username + ":" + data.values.service.secret.password + "@" + data.values.service.name + "-svc." + data.values.service.namespace + ".svc.cluster.local" + ":" + str(data.values.service.secret.port))
  type: #@ base64.encode(data.values.service.secret.type)
---
apiVersion: v1
kind: Service
metadata:
  name: #@ data.values.app.name
spec:
  ports:
  - name: #@ data.values.app.name
    port: #@ data.values.app.port
    targetPort: #@ data.values.app.port
  selector: #@ labels()
EOF
```

And now the `values.yml` to let `ytt` to replace the template placeholders with values:

```yaml
#@data/values
---
namespace: "mongo-demo"
app:
  name: "go-mongo"
  port: 8080
  service:
    name: "mongo-svc"
    port: 8080
service:
  name: "mongo-mongodb"
  namespace: "mongo-demo"
  secret:
    host: "mongo-mongodb.mongo-demo.svc.cluster.local"
    port: 27017
    username: "root"
    password: "AcY2CdZV7p"
    database: "gomongo"
    uri: "mongodb://"
    type: "mongodb"
```

Once we have the configuration figured out, let’s use kbld to record which container images are used:

```shell
ytt -f package-contents/config/values.yml -f package-contents/config/config.yml | kbld -f- --imgpkg-lock-output package-contents/.imgpkg/images.yml
```

Now we can publish our bundle to our registry:

```shell
imgpkg push -b ghcr.io/bzhtux/carvel-packages/go-mongo:1.0.1 -f package-contents/
``

### Create the CR

Make a conformant metadata.yml file:

```yaml
cat > metadata.yml << EOF
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: PackageMetadata
metadata:
  # This will be the name of our package
  name: go-mongo.vmware.com
spec:
  displayName: "Sample Golang Mongo App"
  longDescription: "Sample Golang Mongo App for service binding and Tanzu Application Platform"
  shortDescription: "Sample Golang Mongo App for demoing"
  categories:
  - demo
EOF
```
In order to create the Package CR with our OpenAPI Schema, we will export from our ytt schema:

```shell
ytt -f package-contents/config/values.yml --data-values-schema-inspect -o openapi-v3 > schema-openapi.yml
```

That command creates an OpenAPI document, from which we really only need the components.schema section for our Package CR.

```yaml
cat > package-template.yml << EOF
#@ load("@ytt:data", "data")  # for reading data values (generated via ytt's data-values-schema-inspect mode).
#@ load("@ytt:yaml", "yaml")  # for dynamically decoding the output of ytt's data-values-schema-inspect
---
apiVersion: data.packaging.carvel.dev/v1alpha1
kind: Package
metadata:
  name: #@ "go-mongo.vmware.com." + data.values.version
spec:
  refName: go-mongo.vmware.com
  version: #@ data.values.version
  releaseNotes: |
        Initial release of the simple app package
  valuesSchema:
    openAPIv3: #@ yaml.decode(data.values.openapi)["components"]["schemas"]["dataValues"]
  template:
    spec:
      fetch:
      - imgpkgBundle:
          image: #@ "ghcr.io/bzhtux/carvel-packages/go-mongo:" + data.values.version
      template:
      - ytt:
          paths:
          - "config/"
      - kbld:
          paths:
          - ".imgpkg/images.yml"
          - "-"
      deploy:
      - kapp: {}
EOF
```
