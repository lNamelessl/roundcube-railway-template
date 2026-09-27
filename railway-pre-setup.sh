#!/bin/sh
# Railway pre-setup hook: wait for Postgres before Roundcube's own setup runs.
# The stock entrypoint's /wait-for-it.sh is hard-capped at 30s and does not
# abort on initdb failure, so a cold Postgres would yield a container that is
# "up" with an uninitialized schema. We wait up to 120s here and exit 1 on
# timeout (container dies -> ON_FAILURE restart policy retries).

set -u

HOST="${ROUNDCUBEMAIL_DB_HOST:-}"
PORT="${ROUNDCUBEMAIL_DB_PORT:-5432}"
TYPE="${ROUNDCUBEMAIL_DB_TYPE:-}"

if [ -z "$HOST" ] || [ "$TYPE" != "pgsql" ]; then
    echo "railway-wait: no pgsql DB configured (type='$TYPE' host='$HOST') - skipping wait"
    exit 0
fi

export RAILWAY_WAIT_HOST="$HOST"
export RAILWAY_WAIT_PORT="$PORT"

elapsed=0
while [ "$elapsed" -lt 120 ]; do
    if php -r '$f = @fsockopen(getenv("RAILWAY_WAIT_HOST"), (int)getenv("RAILWAY_WAIT_PORT"), $errno, $errstr, 3); exit($f ? 0 : 1);' 2>/dev/null; then
        echo "railway-wait: $HOST:$PORT reachable after ${elapsed}s"
        exit 0
    fi
    sleep 3
    elapsed=$((elapsed + 3))
    echo "railway-wait: still waiting for $HOST:$PORT (${elapsed}s)..."
done

echo "railway-wait: $HOST:$PORT NOT reachable after 120s - failing container so Railway restarts it" >&2
exit 1
