# builder
FROM golang:alpine AS build-env
LABEL maintainer="Yannick Foeillet <bzhtux@gmail.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add build-base git mercurial gcc curl
RUN mkdir -p /go/src/github.com/bzhtux/mongo
ADD . /go/src/github.com/bzhtux/mongo
WORKDIR /go/src/github.com/bzhtux/mongo
RUN go get -v -u ./...
RUN go build -o mongo-app cmd/main.go


# final image
FROM alpine
LABEL maintainer="Yannick Foeillet <bzhtux@gmail.com>"

# wokeignore:rule=he/him/his
RUN apk --no-cache add curl jq
RUN adduser -h /app -s /bin/sh -u 1000 -D app
RUN mkdir -p /config
COPY config/config.yml /config/
WORKDIR /app
COPY --from=build-env /go/src/github.com/bzhtux/mongo/mongo-app /app/
USER 1000
ENTRYPOINT ./mongo-app
