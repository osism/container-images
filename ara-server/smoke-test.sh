#!/usr/bin/env bash
# Start a freshly built ara-server image and check that it serves the API.
#
# The build alone does not prove that the server starts: a dependency can
# build fine and fail only at import time (gunicorn 26 without its gevent
# extra built and pushed for months, then crashed on start). This runs the
# image as deployed (run.sh, migrations, gunicorn with the default gevent
# workers, login required) on SQLite and checks the API answers with and
# without credentials.
#
# Usage: ara-server/smoke-test.sh IMAGE
# DOCKER selects the container CLI (default: docker).

set -euo pipefail

IMAGE=${1:?usage: $0 IMAGE}
DOCKER=${DOCKER:-docker}
NAME=ara-server-smoke-$$
TIMEOUT=${TIMEOUT:-180}
USERNAME=ara
PASSWORD=smoke-test-password
URL=http://localhost:8000/api/v1/playbooks

cleanup() {
    "$DOCKER" rm -f "$NAME" > /dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*"
    echo "--- container logs ---"
    "$DOCKER" logs "$NAME" 2>&1 | tail -n 50 || true
    exit 1
}

# HTTP status of an API request made inside the container (curl is in the
# image), so no host port is needed.
status() {
    "$DOCKER" exec "$NAME" curl -s -o /dev/null -w '%{http_code}' "$@" "$URL" || true
}

"$DOCKER" run -d --name "$NAME" \
    -e "ARA_ALLOWED_HOSTS=['*']" \
    -e ARA_READ_LOGIN_REQUIRED=true \
    -e ARA_WRITE_LOGIN_REQUIRED=true \
    -e "ARA_API_USERNAME=$USERNAME" \
    -e "ARA_API_PASSWORD=$PASSWORD" \
    "$IMAGE" > /dev/null

deadline=$((SECONDS + TIMEOUT))
while true; do
    state=$("$DOCKER" inspect -f '{{.State.Status}}' "$NAME")
    [[ $state == running ]] || fail "container is $state"
    code=$(status)
    [[ $code == 401 ]] && break
    ((SECONDS < deadline)) || fail "API not up after ${TIMEOUT}s (last status: ${code:-none})"
    sleep 2
done
echo "ok: unauthenticated request rejected (401)"

code=$(status -u "$USERNAME:$PASSWORD")
[[ $code == 200 ]] || fail "authenticated request returned $code, expected 200"
echo "ok: authenticated request accepted (200)"

code=$(status -u "$USERNAME:wrong-password")
[[ $code == 401 ]] || fail "wrong password returned $code, expected 401"
echo "ok: wrong password rejected (401)"
