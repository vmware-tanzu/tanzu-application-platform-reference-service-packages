# Sample PostgreSQL App

Sample Redis App's purpose is testing AWS Elasticache reference package using this [Golang service binding](https://github.com/vmware-tanzu/tanzu-application-platform-reference-service-packages/blob/example-elasticache/examples/elasticache/github.com/bzhtux/servicebinding/bindings) module.

## Docker build image

To containerize this simple PostgreSQL app, use the `Dockerfile` below:

```docker
# builder
FROM golang:alpine AS build-env
LABEL maintainer="Yannick Foeillet <yfoeillet@vmware.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add build-base git mercurial gcc curl
RUN mkdir -p /go/src/github.com/bzhtux/postgres
ADD . /go/src/github.com/bzhtux/postgres
WORKDIR /go/src/github.com/bzhtux/postgres
RUN go get ./...
RUN go build -o postgres-app cmd/main.go


# final image
FROM alpine
LABEL maintainer="Yannick Foeillet <yfoeillet@vmware.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add curl jq
RUN adduser -h /app -s /bin/sh -u 1000 -D app
RUN mkdir -p /config
COPY config/postgres.yaml /config/
WORKDIR /app
COPY --from=build-env /go/src/github.com/bzhtux/postgres/postgres-app /app/
USER 1000
ENTRYPOINT ./postgres-app
```
Build it with the following command:

```shell title="Build docker image"
docker buildx build . --platform linux/amd64 --tag <IMAG NAME>:<IMAGE TAG>
```

## Out Of the Box images

Github Actions automate the build of the sample_apps-postgres app. All images can be retrieved from [here](https://github.com/bzhtux/sample_apps/pkgs/container/sample_apps-postgres/versions)

Pull the latest version:

```shell
docker pull ghcr.io/bzhtux/sample_apps-postgres:latest
```

## Test it locally

### Create a kind cluster

Create a kind cluster with extraPortMappings and node-labels.

* extraPortMappings allow the local host to make requests to the Ingress controller over ports 80/443
* node-labels only allow the ingress controller to run on a specific node(s) matching the label selector

```yaml title="Create a kind cluster"
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: postgresql-sample-app
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

Use this new cluster with `kubectl` changing the  kubernetes `kubeconfig` context as below:

```shell title="switch k8s context"
kubectl cluster-info --context postgresql-sample-app
```

### Namespace

Create a new `namespace` to deploy the sample_apps-postgres with a postgreSQL DB:

```shell title="Create a new namepsace"
kubectl create namespace pg-app
```

Update the kubernetes `kubeconfig` context to use this new namespace:

```shell title="Use this new namespace with the current k8s context"
kubectl config set-context --current --namespace=pg-app
```

### Deploy PostgreSQL using helm

Add bitnami helm repo:

```shell title="Add bitnami help repo"
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Then install PostgreSQL:

```shell title="Install bitnami help chart for postgresql"
helm install pg bitnami/postgresql
```

PostgreSQL can be accessed on port `5432` with the following DNS names from within your cluster:

`pg-postgresql.pg-app.svc.cluster.local - Read/Write connection`

To get the `postgres` password run the following command:

```shell title="Get Postgres password"
export POSTGRES_PASSWORD=$(kubectl get secret --namespace pg-app pg-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
```

### PostgreSQL requirements

Prepare PostgreSQL with username, password, database and extension required by the `sample_apps-postgres` application:

First connect to fresh deployed database running the following command:

```shell title="Connect to PostgreSQL DB"
kubectl get secret --namespace pg-app pg-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d
kubectl exec -ti pg-postgresql-0 -- psql --host pg-postgresql -U postgres -d postgres -p 5432 -W
```
Then run the SQL commands as below:

```shell title="SQL commands"
postgres=# CREATE USER sample_user ;
CREATE ROLE
postgres=# ALTER ROLE sample_user WITH PASSWORD 'sample_password' ;
ALTER ROLE
postgres=# CREATE DATABASE sampledb WITH OWNER sample_user ;
CREATE DATABASE
postgres=# GRANT ALL PRIVILEGES ON DATABASE sampledb TO sample_user ;
GRANT
postgres=# CREATE EXTENSION IF NOT EXISTS "uuid-ossp" ;
CREATE EXTENSION
postgres=# \dx
                            List of installed extensions
   Name    | Version |   Schema   |                   Description
-----------+---------+------------+-------------------------------------------------
 plpgsql   | 1.0     | pg_catalog | PL/pgSQL procedural language
 uuid-ossp | 1.1     | public     | generate universally unique identifiers (UUIDs)
(2 rows)
```

### Use Contour as the Ingress controller

Install Contour components:

```shell title="Install Contour components"
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

```shell title="Install kind specific patch"
kubectl patch daemonsets -n projectcontour envoy -p '{"spec":{"template":{"spec":{"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/control-plane","operator":"Equal","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```

### Ingress usage

The following example creates a simple http service and an Ingress object to route to this services.

```yaml title="PG service manifest"
---
apiVersion: v1
kind: Service
metadata:
  name: pg-app-svc
spec:
  ports:
  - name: pg-app
    port: 8080
    targetPort: 8080
  selector:
    app: pg-app
    app.kubernetes.io/name: pg-app
```

```yaml title="PG ingress manifest"
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sample-apps-ingress
spec:
  ingressClassName: contour
  rules:
  - host: app-pg.127.0.0.1.nip.io
    http:
      paths:
      - backend: 
          service:
            name: pg-app-svc
            port:
              number: 8080
        pathType: Prefix
        path: /
```

### Define PostgreSQL configuration

Provide the correct informations in the `k8s/01.secret.yaml` file :

```shell
export PG_USER=$(echo -n "sample_user" | base64)
export PG_PASS=$(echo -n "sample_password" | base64)
export PG_DB=$(echo -n "sampledb" | base64)
export PG_PORT=$(echo -n "5432" |  base64)
export PG_HOST=$(echo -n "pg-postgresql.pg-app.svc.cluster.local" | base64)
export PG_TYPE=$(echo -n "postgresql" | base64)
export PG_SSL=$(echo -n "true" | base64)
```

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: pg-app-secret
data:
  host: $PG_HSOT
  port: $PG_PORT
  username: $PG_USER
  password: $PG_PASS
  database: $PG_DB
  sslenabled: $PG_SSL
  type: $PG_TYPE
```

### Deploy in k8s kind

Create a secret for the sample postgresql application as shown below:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: Secret
metadata:
  name: pg-app-secret
data:
  host: $PG_HSOT
  port: $PG_PORT
  username: $PG_USER
  password: $PG_PASS
  database: $PG_DB
  sslenabled: $PG_SSL
  type: $PG_TYPE
EOF
```

Then create the deployment as below:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pg-app
spec:
  selector:
    matchLabels:
      app: pg-app
      app.kubernetes.io/name: pg-app
  template:
    metadata:
      labels:
        app: pg-app
        app.kubernetes.io/name: pg-app
    spec:
      containers:
      - name: pg-app
        image: ghcr.io/bzhtux/sample_apps-postgres:v0.0.7
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
              name: pg-app-secret
              items:
                - key: host
                  path: pg/host
                - key: port
                  path: pg/port
                - key: username
                  path: pg/username
                - key: password
                  path: pg/password
                - key: database
                  path: pg/database
                - key: sslenabled
                  path: pg/ssl
                - key: type
                  path: pg/type
EOF
```

Configure a service to access the application with ingress:

```yaml
cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: Service
metadata:
  name: pg-app-svc
spec:
  ports:
  - name: pg-app
    port: 8080
    targetPort: 8080
  selector:
    app: pg-app
    app.kubernetes.io/name: pg-app
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
  - host: gopg.127.0.0.1.nip.io
    http:
      paths:
      - backend: 
          service:
            name: pg-app-svc
            port:
              number: 8080
        pathType: Prefix
        path: /
EOF
```
### Test it !

Set up `APP_HOST` and `APP_PORT` for running some test commands:

```shell
export APP_HOST="gopg.127.0.0.1.nip.io"
export APP_PORT="80"
```

```shell
curl -sL http://gopg.127.0.0.1.nip.io/ | jq .
{
  "message": "Alive",
  "status": "Up"
}
```

Add a new book in DB:

```shell
curl -sL -X POST -d '{"title": "The Hitchhiker'\'s' Guide to the Galaxy", "author": "Douglas Adams"}'  http://"${APP_HOST}":"${APP_PORT}"/add | jq .
{
  "data": {
    "ID": 1
    "Author": "Douglas Adams"
    "Title": "The Hitchhiker's Guide to the Galaxy"
  },
  "message": "New book has been recorded",
  "status": "Accepted"
}
```

Add the same book twice (conflict expected):

```json
curl -sL -X POST -d '{"title": "The Hitchhiker'\'s' Guide to the Galaxy", "author": "Douglas Adams"}'  http://"${APP_HOST}":"${APP_PORT}"/add | jq .
{
  "data": {
    "ID": 1
  },
  "message": "A Book already exists with title: The Hitchhiker's Guide to the Galaxy",
  "status": "Conflict"
}
```

Get book by ID:

```json
curl -sL http://"${HOST}":"${PORT}"/get/"${bookID}" | jq .data
{
  "Author": "Douglas Adams",
  "ID": "1",
  "Title": "The Hitchhiker's Guide to the Galaxy"
}
```

Delete book by ID:

```json
curl -sL -X DELETE http://"${HOST}":"${PORT}"/del/"${bookID}" | jq .
{
  "message": "Book with ID 1 was successfuly deleted",
  "status": "Deleted"
}
```

If everything is ok, safely remove the kind cluster:

```shell
kind delete cluster --name=postgresql-sample-app
```