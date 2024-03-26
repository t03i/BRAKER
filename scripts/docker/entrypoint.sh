#!/bin/bash
set -e

# Check if PUID and PGID environment variables are set
if [ ! -z "${PUID}" ]; then
    echo "Setting custom user ID to ${PUID}."
    usermod -o -u "${PUID}" abc
fi

if [ ! -z "${PGID}" ]; then
    echo "Setting custom group ID to ${PGID}."
    groupmod -o -g "${PGID}" abc
fi

chown abc:abc /data /home/abc

exec gosu abc "$@"
