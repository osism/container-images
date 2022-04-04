#!/usr/bin/env bash

if [[ $# -lt 1 ]]; then
    echo "usage: PLAYBOOK [ANSIBLEARGS...]"
    exit 1
fi

cd /opt/configuration/environments/manager

playbook=$1
shift

ANSIBLE_USER=${ANSIBLE_USER:-dragon}

if [[ ! -e id_rsa.operator ]]; then

    ansible-playbook \
        -i localhost, \
        -e @../secrets.yml \
        osism.manager.keypair "$@"
fi

if [[ $playbook == "netbox" || $playbook == "traefik" ]]; then

    ansible-playbook \
        --private-key id_rsa.operator \
        -i hosts \
        -e @../images.yml \
        -e @../configuration.yml \
        -e @../secrets.yml \
        -e @../infrastructure/images.yml \
        -e @../infrastructure/configuration.yml \
        -e @../infrastructure/secrets.yml \
        -e @images.yml \
        -e @configuration.yml \
        -e @secrets.yml \
        -u "$ANSIBLE_USER" \
        osism.manager."$playbook" "$@"

else

    ansible-playbook \
        --private-key id_rsa.operator \
        -i hosts \
        -e @../images.yml \
        -e @../configuration.yml \
        -e @../secrets.yml \
        -e @images.yml \
        -e @configuration.yml \
        -e @secrets.yml \
        -u "$ANSIBLE_USER" \
        osism.manager."$playbook" "$@"

fi
