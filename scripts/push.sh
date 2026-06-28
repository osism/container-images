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

pip3 install dtrack-auditor
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin

generate_sbom() {
    local repository="$1"
    local version="$2"

    /usr/local/bin/syft scan "$repository:$version" -o cyclonedx-json@1.6 > sbom.json
    dtrackauditor \
      -p $(basename $repository) \
      -v "$version" \
      -f sbom.json \
      -a
}

sign_image() {
    local repository="$1"
    local version="$2"

    cosign sign --yes --key env://COSIGN_PRIVATE_KEY "$repository:$version"
}

docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"

if [[ $IMAGE != "netbox" && $IMAGE != "ceph-daemon" && $IMAGE != "pulp-minimal" ]]; then
    # push e.g. osism/cephclient:pacific
    docker push "$REPOSITORY:$VERSION"
    generate_sbom $REPOSITORY $VERSION
    sign_image $REPOSITORY $VERSION
fi

if [[ $IMAGE == "cgit" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" /usr/libexec/cgit/cgi-bin/cgit --version | head -n1 | awk '{ print $2 }' | sed 's/v*//')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
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
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi
fi

# push e.g. osism/rsync:3.2.7
if [[ $IMAGE == "rsync" ]]; then
    version=$(docker run --entrypoint /usr/bin/rsync --rm "$REPOSITORY:$VERSION" --version | head -n 1 | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi
fi

# push e.g. osism/ara-server:1.7.5-r1
#
# Tag = <upstream ara version>-r<osism revision>, revision from
# ara-server/osism-revision. The image carries OSISM patches (0018 migration,
# run.sh) that change without an upstream version bump; the -rN revision mints
# a fresh immutable tag so a fix is not swallowed by the skip-if-exists guard
# below. Bump osism-revision when the ara-server layer changes. Renovate needs
# regex versioning (osism/renovate-config) to track -rN. See the commit that
# introduced this for the full rationale.
if [[ $IMAGE == "ara-server" ]]; then
    ara_version=$(docker run --rm "$REPOSITORY:$VERSION" ara --version | awk '{ print $2 }')
    osism_revision=$(cat ara-server/osism-revision) || { echo "missing ara-server/osism-revision"; exit 1; }
    version="${ara_version}-r${osism_revision}"
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi

    # always push a latest osism/ara-server image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    generate_sbom $REPOSITORY latest
    sign_image $REPOSITORY latest
fi

# push e.g. osism/openstackclient:5.5.0
if [[ $IMAGE == "openstackclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" openstack --version | awk '{ print $2 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi

    docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:$VERSION"
    docker push "$REPOSITORY:$VERSION"
    generate_sbom $REPOSITORY $VERSION
    sign_image $REPOSITORY $VERSION
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

	if [[ "$VERSION" == "v17" ]]; then
            docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:quincy"
            docker push "$REPOSITORY:quincy"
	elif [[ "$VERSION" == "v18" ]]; then
            docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:reef"
            docker push "$REPOSITORY:reef"
	elif [[ "$VERSION" == "v19" ]]; then
            docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:squid"
            docker push "$REPOSITORY:squid"
	fi

        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi

    # push e.g. osism/ceph-daemon:pacific
    version=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$REPOSITORY:$REVISION" | grep -P "^CEPH_VERSION=" | sed 's/[^=]*=//')
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
    docker push "$REPOSITORY:$version"
    generate_sbom $REPOSITORY $version
    sign_image $REPOSITORY $version
fi

# push e.g. osism/cephclient:16.2.5
if [[ $IMAGE == "cephclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" ceph --version | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        generate_sbom $REPOSITORY $version
        sign_image $REPOSITORY $version
    fi
fi

# push e.g. osism/netbox:3.4.8
if [[ $IMAGE == "netbox" ]]; then
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${VERSION}" > /dev/null; then
        echo "The image ${REPOSITORY}:${VERSION} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
        docker push "$REPOSITORY:$VERSION"
        generate_sbom $REPOSITORY $VERSION
        sign_image $REPOSITORY $VERSION
    fi

    # always push a latest osism/netbox image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    generate_sbom $REPOSITORY latest
    sign_image $REPOSITORY latest
fi

# push e.g. osism/pulp:3.4.8
if [[ $IMAGE == "pulp" ]]; then
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${VERSION}" > /dev/null; then
        echo "The image ${REPOSITORY}:${VERSION} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
        docker push "$REPOSITORY:$VERSION"
        generate_sbom $REPOSITORY $VERSION
        sign_image $REPOSITORY $VERSION
    fi

    # always push a latest osism/pulp image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    generate_sbom $REPOSITORY latest
    sign_image $REPOSITORY latest
fi

docker rmi "$REPOSITORY:$VERSION"
