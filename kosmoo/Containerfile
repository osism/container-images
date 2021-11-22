ARG GO_VERSION=1.16
FROM golang:$GO_VERSION-alpine as build

ARG VERSION=1.0.8

RUN apk add --no-cache \
      bash \
      git \
      make \
    && mkdir -p "${GOPATH}/src/github.com/daimler"

WORKDIR ${GOPATH}/src/github.com/daimler
RUN git clone --depth 1 --branch v${VERSION} https://github.com/daimler/kosmoo.git

WORKDIR ${GOPATH}/src/github.com/daimler/kosmoo
RUN make build

FROM alpine:3

COPY --from=build /go/src/github.com/daimler/kosmoo/kosmoo /usr/bin/kosmoo

ENTRYPOINT ["/usr/bin/kosmoo", "-cloud-conf", "/etc/cloud.conf", "-kubeconfig", "/etc/kubeconfig"]
EXPOSE 9183

LABEL "org.opencontainers.image.documentation"="https://docs.osism.de" \
      "org.opencontainers.image.licenses"="ASL 2.0" \
      "org.opencontainers.image.source"="https://github.com/osism/container-image-kosmoo" \
      "org.opencontainers.image.url"="https://www.osism.de" \
      "org.opencontainers.image.vendor"="Betacloud Solutions GmbH"
