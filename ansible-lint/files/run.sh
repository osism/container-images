#!/bin/sh

if [ -e /zuul/.ansible-lint ]; then
    python3 /prepare-config.py
else
    cp /ansible-lint.yml /zuul/.ansible-lint
fi

mkdir -p /zuul/.ansible-lint-rules
cp /osism_* /zuul/.ansible-lint-rules

cd /zuul
python3 -m ansiblelint --nocolor -R --offline
