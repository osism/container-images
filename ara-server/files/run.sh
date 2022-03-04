#!/usr/bin/env bash

# Available environment variables
#
# ARA_API_PASSWORD
# ARA_API_USERNAME
#
# https://ara.readthedocs.io/en/latest/api-configuration.html#overview

# Set default values

ARA_API_PASSWORD=${ARA_API_PASSWORD:-password}
ARA_API_USERNAME=${ARA_API_USERNAME:-ara}

export ARA_BASE_DIR=/var/lib/ara-server

cp /var/lib/ara-server/ara-server.yml /var/lib/ara-server/settings.yaml
chown unit:root /var/lib/ara-server/settings.yaml

until ara-manage migrate; do
    echo "database migration failed, trying again in 10 seconds"
    sleep 10
done

ara-manage collectstatic

result=$(echo "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(username='$ARA_API_USERNAME').count()>0)" | ara-manage shell | tail -n 1)
if [[ $result == "False" ]]; then
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('$ARA_API_USERNAME', '$ARA_API_USERNAME@ara-server.local', '$ARA_API_PASSWORD')" | ara-manage shell
fi

exec unitd \
  --no-daemon \
  --control unix:/var/run/control.unit.sock \
  --log /dev/stdout \
  --user unit \
  --group root
