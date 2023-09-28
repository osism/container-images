#!/usr/bin/env bash

# Available environment variables
#
# ARA_API_PASSWORD
# ARA_API_USERNAME
# ARA_HOST
# ARA_PORT
# ARA_WORKERS
# ARA_WORKER_CLASS
#
# https://ara.readthedocs.io/en/latest/api-configuration.html#overview

# Set default values

ARA_API_PASSWORD=${ARA_API_PASSWORD:-password}
ARA_API_USERNAME=${ARA_API_USERNAME:-ara}
ARA_HOST=${ARA_HOST:-0.0.0.0}
ARA_PORT=${ARA_PORT:-8000}
ARA_THREADS=${ARA_THREADS:-1}
ARA_WORKERS=${ARA_WORKERS:-5}
ARA_WORKER_CLASS=${ARA_WORKER_CLASS:-gevent}
ARA_WORKER_CONNECTIONS=${ARA_WORKER_CONNECTIONS:-1000}

until ara-manage migrate; do
    echo "database migration failed, trying again in 10 seconds"
    sleep 10
done

result=$(echo "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(username='$ARA_API_USERNAME').count()>0)" | ara-manage shell | tail -n 1)
if [[ $result == "False" ]]; then
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('$ARA_API_USERNAME', '$ARA_API_USERNAME@ara-server.local', '$ARA_API_PASSWORD')" | ara-manage shell
fi

exec gunicorn \
  --threads $ARA_THREADS \
  --worker-class $ARA_WORKER_CLASS \
  --worker-connections $ARA_WORKER_CONNECTIONS \
  --workers $ARA_WORKERS \
  --bind $ARA_HOST:$ARA_PORT \
  ara.server.wsgi
