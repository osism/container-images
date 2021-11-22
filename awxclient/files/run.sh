#!/usr/bin/env sh

ansible-playbook -i localhost, -e project=$1 -e job=$2 -e kolla_action=$3 /run.yml
