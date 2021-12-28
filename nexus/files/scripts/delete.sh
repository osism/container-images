#!/usr/bin/env bash

NEXUS_HOST=${NEXUS_HOST:-localhost}
NEXUS_PORT=${NEXUS_PORT:-8081}
NEXUS_PATH=${NEXUS_PATH:-}
NEXUS_USERNAME=${NEXUS_USERNAME:-admin}
NEXUS_PASSWORD=${NEXUS_PASSWORD:-password}

NAME=$1

# https://gist.github.com/rgl/f90ff293d56dbb0a1e0f7e7e89a81f42#gistcomment-3773747
HEALTH_CHECK_URL=http://${NEXUS_HOST}:${NEXUS_PORT}${NEXUS_PATH}/service/rest/v1/status STATUS=200 timeout --foreground -s TERM 120 bash -c \
    'while [[ ${STATUS_RECEIVED} != ${STATUS} ]];\
        do STATUS_RECEIVED=$(curl -s -o /dev/null -L -w "%{http_code}" ${HEALTH_CHECK_URL}) && \
        echo "received status: $STATUS_RECEIVED" && \
        sleep 1;\
    done;
    echo success with status: $STATUS_RECEIVED'

curl -v -X DELETE -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    "http://${NEXUS_HOST}:${NEXUS_PORT}${NEXUS_PATH}/service/rest/v1/script/${NAME}"
