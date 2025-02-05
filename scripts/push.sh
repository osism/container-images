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

docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"

if [[ $IMAGE != "netbox" ]]; then
    # push e.g. osism/cephclient:pacific
    docker push "$REPOSITORY:$VERSION"
fi

if [[ $IMAGE == "cgit" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" /usr/libexec/cgit/cgi-bin/cgit --version | head -n1 | awk '{ print $2 }' | sed 's/v*//')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi
fi

# push e.g. osism/dnsmasq-osism:2.90
if [[ $IMAGE == "dnsmasq-osism" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" --version | head -n 1 | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi
fi

# push e.g. osism/ara-server:1.5.8
if [[ $IMAGE == "ara-server" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" ara --version | awk '{ print $2 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi

    # always push a latest osism/ara-server image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
fi

# push e.g. osism/openstackclient:5.5.0
if [[ $IMAGE == "openstackclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" openstack --version | awk '{ print $2 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi

    if [[ $VERSION == "antelope" ]]; then
        docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:2023.1"
        docker push "$REPOSITORY:2023.1"
    elif [[ $VERSION == "bobcat" ]]; then
        docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:2023.2"
        docker push "$REPOSITORY:2023.2"
    elif [[ $VERSION == "caracal" ]]; then
        docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:2024.1"
        docker push "$REPOSITORY:2024.1"
    elif [[ $VERSION == "dalmatian" ]]; then
        docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:2024.2"
        docker push "$REPOSITORY:2024.2"
    elif [[ $VERSION == "epoxy" ]]; then
        docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:2025.1"
        docker push "$REPOSITORY:2025.1"
    fi
fi

# push e.g. osism/ceph-daemon:12.2.13 + osism/ceph-daemon:pacific
if [[ $IMAGE == "ceph-daemon" ]]; then

    # push e.g. osism/ceph-daemon:12.2.13
    version=$(docker run --rm --entrypoint=/usr/bin/ceph "$REPOSITORY:$VERSION" --version | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi

    # push e.g. osism/ceph-daemon:pacific
    version=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$REPOSITORY:$REVISION" | grep -P "^CEPH_VERSION=" | sed 's/[^=]*=//')
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
    docker push "$REPOSITORY:$version"
fi

# push e.g. osism/cephclient:16.2.5
if [[ $IMAGE == "cephclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" ceph --version | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
    fi
fi

# push e.g. osism/netbox:3.4.8
if [[ $IMAGE == "netbox" ]]; then
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${VERSION}" > /dev/null; then
        echo "The image ${REPOSITORY}:${VERSION} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
        docker push "$REPOSITORY:$VERSION"
    fi

    # always push a latest osism/netbox image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
fi

docker rmi "$REPOSITORY:$VERSION"
