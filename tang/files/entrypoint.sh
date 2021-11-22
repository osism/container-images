#!/bin/bash
set -e

if [ ! -f /var/db/tang/key-sig.jwk ]; then
    chmod -R 775 /var/db/tang
    /usr/lib/x86_64-linux-gnu/tangd-keygen /var/db/tang key-sig key-exc
    chmod 775 /var/db/tang/key-sig.jwk
    chmod 775 /var/db/tang/key-exc.jwk
fi

/usr/sbin/xinetd -dontfork

exec "$@"
