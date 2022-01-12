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
docker buildx build \
    --load \
    --build-arg "VERSION=$VERSION" \
    --tag "$REPOSITORY:$REVISION" \
    --label "org.opencontainers.image.created=$CREATED" \
    --label "org.opencontainers.image.revision=$REVISION" \
    --label "org.opencontainers.image.version=$VERSION" \
    $BUILD_OPTS .
popd


if [[ $DOCKER_SLIM == "true" ]]; then
    curl -L -o ds.tar.gz https://downloads.dockerslim.com/releases/1.37.3/dist_linux.tar.gz
    tar -xvf ds.tar.gz
    ./dist_linux/docker-slim build --http-probe=false "$REPOSITORY:$REVISION"
fi
