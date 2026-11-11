#!/usr/bin/env bash
# Fail on any failed command, including inside pipes: a failed docker push
# must fail the workflow step. Before this, the script's status was that of
# the final docker rmi. No -u: the dnsmasq-osism and rsync workflows do not
# pass DOCKER_USERNAME/DOCKER_PASSWORD, which the skopeo checks below expand.
set -xeo pipefail

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

# SBOM tooling, installed and checked before anything is pushed: a failed
# install (e.g. a 504 from GitHub release downloads) then fails the step with
# nothing published, and a rerun starts clean.
pip3 install dtrack-auditor
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
/usr/local/bin/syft version > /dev/null
command -v dtrackauditor > /dev/null

# Called after sign_image. A failure fails the step. For a version tag that
# a rerun skips as already existing, the SBOM then has to be uploaded by hand.
generate_sbom() {
    local repository="$1"
    local version="$2"

    /usr/local/bin/syft scan "$repository:$version" -o cyclonedx-json@1.6 > sbom.json
    dtrackauditor \
      -p "$(basename "$repository")" \
      -v "$version" \
      -f sbom.json \
      -a
}

# Called right after each push. A rerun skips version tags that already
# exist, so a tag pushed but left unsigned by a failed run stays unsigned.
sign_image() {
    local repository="$1"
    local version="$2"

    cosign sign --yes --key env://COSIGN_PRIVATE_KEY "$repository:$version"
}

docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"

if [[ $IMAGE != "netbox" && $IMAGE != "ceph-daemon" && $IMAGE != "pulp-minimal" ]]; then
    # push e.g. osism/cephclient:pacific
    docker push "$REPOSITORY:$VERSION"
    sign_image $REPOSITORY $VERSION
    generate_sbom $REPOSITORY $VERSION
fi

if [[ $IMAGE == "cgit" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" /usr/libexec/cgit/cgi-bin/cgit --version | awk 'NR == 1 { print $2 }' | sed 's/v*//')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
    fi
fi

# push e.g. osism/dnsmasq-osism:2.90
if [[ $IMAGE == "dnsmasq-osism" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" --version | awk 'NR == 1 { print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
    fi
fi

# push e.g. osism/rsync:3.2.7
if [[ $IMAGE == "rsync" ]]; then
    version=$(docker run --entrypoint /usr/bin/rsync --rm "$REPOSITORY:$VERSION" --version | awk 'NR == 1 { print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
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
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
    fi

    # always push a latest osism/ara-server image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    sign_image $REPOSITORY latest
    generate_sbom $REPOSITORY latest
fi

# push e.g. osism/openstackclient:5.5.0
if [[ $IMAGE == "openstackclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" openstack --version | awk '{ print $2 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
    fi

    docker tag "$REPOSITORY:$VERSION" "$REPOSITORY:$VERSION"
    docker push "$REPOSITORY:$VERSION"
    sign_image $REPOSITORY $VERSION
    generate_sbom $REPOSITORY $VERSION

    # Publish :latest for the rolling/newest build. The workflow marks that
    # matrix entry with PUBLISH_LATEST=true rather than hardcoding a series
    # number here, so this stays correct when the rolling series advances
    # (2026.1 -> 2026.2 -> ...). "openstack_version: latest" deployments then
    # resolve to this client, matching the other OpenStack components (whose
    # :latest is the master build).
    if [[ "${PUBLISH_LATEST:-false}" == "true" ]]; then
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
        docker push "$REPOSITORY:latest"
        sign_image $REPOSITORY latest
        generate_sbom $REPOSITORY latest
    fi
fi

# push e.g. osism/ceph-daemon:20.2.4-r1 + osism/ceph-daemon:tentacle
#
# Version tag = <upstream ceph version>-r<osism revision>, revision from
# ceph-daemon/osism-revision. The image carries OSISM patches
# (ceph-daemon/patches/) that change without an upstream version bump; the -rN
# revision mints a fresh immutable tag so a patch is not swallowed by the
# skip-if-exists guard below, as for ara-server. Bump osism-revision when the
# ceph-daemon layer changes. The series tag (tentacle, ...) still follows every
# build.
if [[ $IMAGE == "ceph-daemon" ]]; then

    # push e.g. osism/ceph-daemon:20.2.4-r1
    ceph_version=$(docker run --rm --entrypoint=/usr/bin/ceph "$REPOSITORY:$VERSION" --version | awk '{ print $3 }')
    osism_revision=$(cat ceph-daemon/osism-revision) || { echo "missing ceph-daemon/osism-revision"; exit 1; }
    version="${ceph_version}-r${osism_revision}"
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version

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
    fi

    # push e.g. osism/ceph-daemon:pacific
    version=$(docker inspect --format='{{range .Config.Env}}{{println .}}{{end}}' "$REPOSITORY:$REVISION" | grep -P "^CEPH_VERSION=" | sed 's/[^=]*=//')
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
    docker push "$REPOSITORY:$version"
    sign_image $REPOSITORY $version
    generate_sbom $REPOSITORY $version
fi

# push e.g. osism/cephclient:16.2.5
if [[ $IMAGE == "cephclient" ]]; then
    version=$(docker run --rm "$REPOSITORY:$VERSION" ceph --version | awk '{ print $3 }')
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${version}" > /dev/null; then
        echo "The image ${REPOSITORY}:${version} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$version"
        docker push "$REPOSITORY:$version"
        sign_image $REPOSITORY $version
        generate_sbom $REPOSITORY $version
    fi
fi

# push e.g. osism/netbox:3.4.8
if [[ $IMAGE == "netbox" ]]; then
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${VERSION}" > /dev/null; then
        echo "The image ${REPOSITORY}:${VERSION} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
        docker push "$REPOSITORY:$VERSION"
        sign_image $REPOSITORY $VERSION
        generate_sbom $REPOSITORY $VERSION
    fi

    # always push a latest osism/netbox image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    sign_image $REPOSITORY latest
    generate_sbom $REPOSITORY latest
fi

# push e.g. osism/pulp:3.4.8
if [[ $IMAGE == "pulp" ]]; then
    if skopeo inspect --creds "${DOCKER_USERNAME}:${DOCKER_PASSWORD}" "docker://${REPOSITORY}:${VERSION}" > /dev/null; then
        echo "The image ${REPOSITORY}:${VERSION} already exists."
    else
        docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:$VERSION"
        docker push "$REPOSITORY:$VERSION"
        sign_image $REPOSITORY $VERSION
        generate_sbom $REPOSITORY $VERSION
    fi

    # always push a latest osism/pulp image
    docker tag "$REPOSITORY:$REVISION" "$REPOSITORY:latest"
    docker push "$REPOSITORY:latest"
    sign_image $REPOSITORY latest
    generate_sbom $REPOSITORY latest
fi

docker rmi "$REPOSITORY:$VERSION"
