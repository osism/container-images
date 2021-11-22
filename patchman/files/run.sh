#!/usr/bin/env bash

# Available environment variables
#
# PATCHMAN_PASSWORD
# PATCHMAN_USERNAME
# PATCHMAN_HOST
# PATCHMAN_PORT

# Set default values

PATCHMAN_PASSWORD=${PATCHMAN_PASSWORD:-password}
PATCHMAN_USERNAME=${PATCHMAN_USERNAME:-patchman}
PATCHMAN_HOST=${PATCHMAN_HOST:-0.0.0.0}
PATCHMAN_PORT=${PATCHMAN_PORT:-8000}

patchman-manage collectstatic --noinput
patchman-manage makemigrations
patchman-manage migrate --run-syncdb
patchman-manage loaddata /fixtures.json

result=$(echo "from django.contrib.auth import get_user_model; User = get_user_model(); print(User.objects.filter(username='$PATCHMAN_USERNAME').count()>0)" | patchman-manage shell | tail -n 1)
if [[ $result == "False" ]]; then
    echo "from django.contrib.auth.models import User; User.objects.create_superuser('$PATCHMAN_USERNAME', '$PATCHMAN_USERNAME@patchman.local', '$PATCHMAN_PASSWORD')" | patchman-manage shell
fi

exec gunicorn patchman.wsgi --bind $PATCHMAN_HOST:$PATCHMAN_PORT --workers 5
