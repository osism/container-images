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
if [[ $IMAGE == "cephclient" ]]; then
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
