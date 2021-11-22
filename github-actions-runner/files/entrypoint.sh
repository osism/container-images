#!/usr/bin/env bash

SECRET_TOKEN=$(python3 get_token.py --org="${SECRET_GITHUB_ORG}" --app-id="${SECRET_GITHUB_APP_ID}" --key-path="${SECRET_KEY_PATH}" --api-url "${SECRET_GITHUB_API_URL}")
./config.sh --name "${SECRET_NAME}" --token "${SECRET_TOKEN}" --url "${SECRET_GITHUB_URL}/${SECRET_GITHUB_ORG}" --unattended --replace
./run.sh &
wait $!
