#!/bin/bash

# In this script, commands can be added that are to be executed
# after the initialisation of Netbox and before the start of
# Netbox.

# The initialisation of additional objects has been outsourced to
# a plug-in and must still be executed separately.
if [[ $INITIALIZERS_ENABLED == "True" ]]; then
    python3 /opt/netbox/netbox/manage.py load_initializer_data --path /opt/netbox/initializers
fi

exec /opt/netbox/launch-netbox.sh
