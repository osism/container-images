#!/usr/bin/env bash
# Fail on any failed command: a failed download or load must fail the step.
set -xeo pipefail

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

cd $IMAGE

if [[ $IMAGE == "sonic-vs" ]]; then
    # SONiC publishes the VS image only as an artifact of its Azure DevOps
    # pipeline, and runs there are deleted after about 60 days unless kept,
    # so a fixed artifact URL breaks (build 737906 did). Look up the newest
    # successful build of the release branch $VERSION instead, the way
    # https://sonic.software/ (github.com/bluecmd/sonic-builds) does.
    api=https://dev.azure.com/mssonic/build/_apis/build
    definition=$(curl -sSf "$api/definitions?name=Azure.sonic-buildimage.official.vs&api-version=6.0" | jq -er '.value[0].id')
    build_id=$(curl -sSf "$api/builds?definitions=$definition&branchName=refs/heads/$VERSION&resultFilter=succeeded&\$top=1&api-version=6.0" | jq -er '.value[0].id')
    echo "Using SONiC VS build $build_id: https://dev.azure.com/mssonic/build/_build/results?buildId=$build_id"
    url=$(curl -sSf "$api/builds/$build_id/artifacts?artifactName=sonic-buildimage.vs&api-version=5.1" | jq -er '.resource.downloadUrl' | sed 's|format=zip|format=file\&subpath=/target/docker-sonic-vs.gz|')
    wget -q -O docker-sonic-vs.gz "$url"
    docker load --input docker-sonic-vs.gz
    docker tag docker-sonic-vs:latest $REPOSITORY:$VERSION
    # push.sh tags and pushes from the revision tag, as for the other images.
    docker tag docker-sonic-vs:latest $REPOSITORY:$REVISION
    exit 0
fi

if [[ $IMAGE == "netbox" ]]; then
    docker pull quay.io/netboxcommunity/netbox:$VERSION
fi

if [[ $IMAGE == "pulp" ]]; then
    docker pull quay.io/pulp/pulp-minimal:$VERSION
fi

if [[ $IMAGE == "cephclient" ]]; then
    if [[ $VERSION == "quincy" ]]; then
        DEBIAN_VERSION=bullseye
    else
	DEBIAN_VERSION=bookworm
    fi
    BUILD_OPTS="$BUILD_OPTS --build-arg DEBIAN_VERSION=$DEBIAN_VERSION"
elif [[ $IMAGE == "openstackclient" ]]; then
    if [[ $VERSION == "caracal" ]]; then
        PYTHON_VERSION=3.12
    else
	PYTHON_VERSION=3.13
    fi
    BUILD_OPTS="$BUILD_OPTS --build-arg PYTHON_VERSION=$PYTHON_VERSION"
    # ROLLING (set by the build matrix for the rolling series) selects the
    # OpenStack master requirements in the Containerfile.
    BUILD_OPTS="$BUILD_OPTS --build-arg ROLLING=${ROLLING:-false}"
fi

docker buildx build \
  --load \
  --build-arg "VERSION=$VERSION" \
  --tag "$REPOSITORY:$REVISION" \
  --label "org.opencontainers.image.created=$CREATED" \
  --label "org.opencontainers.image.revision=$REVISION" \
  --label "org.opencontainers.image.version=$VERSION" \
  $BUILD_OPTS .
