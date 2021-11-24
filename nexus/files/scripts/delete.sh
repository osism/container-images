#!/usr/bin/env bash

NEXUS_HOST=${NEXUS_HOST:-localhost}
NEXUS_PORT=${NEXUS_PORT:-8081}
NEXUS_USERNAME=${NEXUS_USERNAME:-admin}
NEXUS_PASSWORD=${NEXUS_PASSWORD:-password}

NAME=$1

curl -v -X DELETE -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/script/${NAME}"
