#!/bin/sh

export ANSIBLE_DEPRECATION_WARNINGS=False
# Keep all caches off the read-only project mount.
export XDG_CACHE_HOME=/tmp/cache

if [ -e /zuul/.ansible-lint ]; then
    python3 /prepare-config.py
else
    cp /ansible-lint.yml /tmp/ansible-lint.yml
fi

cd /zuul
python3 -m ansiblelint -c /tmp/ansible-lint.yml --nocolor -R --offline
