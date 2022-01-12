#!/usr/bin/env bash
set -x

# Available environment variables
#
# DOCKER_REGISTRY
# REPOSITORY
# VERSION

DOCKER_REGISTRY=${DOCKER_REGISTRY:-quay.io}
REVISION=$(git rev-parse HEAD)
VERSION=${VERSION:-latest}

if [[ -n $DOCKER_REGISTRY ]]; then
    REPOSITORY="$DOCKER_REGISTRY/$REPOSITORY"
fi

if [[ $DOCKER_SLIM == "true" ]]; then
    docker tag "$REPOSITORY.slim" "$REPOSITORY:$VERSION"
else
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
fi

docker push "$REPOSITORY:$VERSION"
docker rmi "$REPOSITORY:$VERSION"
