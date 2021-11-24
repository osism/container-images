#!/usr/bin/env bash

NEXUS_HOST=${NEXUS_HOST:-localhost}
NEXUS_PORT=${NEXUS_PORT:-8081}
NEXUS_USERNAME=${NEXUS_USERNAME:-admin}
NEXUS_PASSWORD=${NEXUS_PASSWORD:-password}

curl -v -X POST -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --header "Content-Type: text/plain" "http://${NEXUS_HOST}:${NEXUS_PORT}/service/rest/v1/script/anonymous/run" -d true
