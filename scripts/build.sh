#!/usr/bin/env bash
set -x

# Available environment variables
#
# BUILD_OPTS
# DOCKER_REGISTRY
# IMAGE
# REPOSITORY
# VERSION

# Set default values

BUILD_OPTS=${BUILD_OPTS:-}
CREATED=$(date --rfc-3339=ns)
DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
REVISION=$(git rev-parse HEAD)
VERSION=${VERSION:-latest}

if [[ -n $DOCKER_REGISTRY ]]; then
    REPOSITORY="$DOCKER_REGISTRY/$REPOSITORY"
fi

pushd $IMAGE
if [[ $IMAGE == "sonic-vs" ]]; then
    # URL from https://sonic.software/
    wget -q -O docker-sonic-vs.gz "https://artprodcus3.artifacts.visualstudio.com/Af91412a5-a906-4990-9d7c-f697b81fc04d/be1b070f-be15-4154-aade-b1d3bfb17054/_apis/artifact/cGlwZWxpbmVhcnRpZmFjdDovL21zc29uaWMvcHJvamVjdElkL2JlMWIwNzBmLWJlMTUtNDE1NC1hYWRlLWIxZDNiZmIxNzA1NC9idWlsZElkLzY4NTMzNi9hcnRpZmFjdE5hbWUvc29uaWMtYnVpbGRpbWFnZS52cw2/content?format=file&subpath=/target/docker-sonic-vs.gz"
    docker load --input docker-sonic-vs.gz
    docker tag docker-sonic-vs:latest $DOCKER_REGISTRY/$REPOSITORY:$REVISION
elif [[ $IMAGE == "cephclient" ]]; then
    if [[ $VERSION == "quincy" ]]; then
        DEBIAN_VERSION=bullseye
    else
	DEBIAN_VERSION=bookworm
    fi

    docker buildx build \
      --load \
      --build-arg "VERSION=$VERSION" \
      --build-arg "DEBIAN_VERSION=$DEBIAN_VERSION" \
      --tag "$REPOSITORY:$REVISION" \
      --label "org.opencontainers.image.created=$CREATED" \
      --label "org.opencontainers.image.revision=$REVISION" \
      --label "org.opencontainers.image.version=$VERSION" \
      $BUILD_OPTS .
else
    docker buildx build \
      --load \
      --build-arg "VERSION=$VERSION" \
      --tag "$REPOSITORY:$REVISION" \
      --label "org.opencontainers.image.created=$CREATED" \
      --label "org.opencontainers.image.revision=$REVISION" \
      --label "org.opencontainers.image.version=$VERSION" \
      $BUILD_OPTS .
fi
popd
