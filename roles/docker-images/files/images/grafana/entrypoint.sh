#!/bin/sh
set -eu # fail on error

# Update system certificates (we have root permissions at this point)
echo "Updating CA certificates..."
update-ca-certificates

# Fix permissions to avoid write errors on mounted volumes
chown -R grafana:root /var/lib/grafana

# TODO[VCC-010]: Create entrypoint for grafana. It should support replicated deployments

# Wait until database is alive. Grafana image comes with netcat (nc)
echo "Waiting for the PostgreSQL database on port 5432..."
while ! nc -w 1 db 5432 > /dev/null 2>&1; do
    echo "PostgreSQL is unavailable - sleeping..."
    sleep 2
done
echo "Database is alive and responding!"

MARKER="/var/lib/grafana/.grafana-configured"
LOCK_DIR="/var/lib/grafana/.grafana_init_lock"

# Check if Grafana has been configured before
if [ ! -f "$MARKER" ]; then
    # Try to create lock directory atomically (Leader election) as the grafana user!
    if su-exec grafana mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "First run detected (Leader). Initializing Grafana..."
        
        # We touch the marker immediately. Grafana will auto-migrate the DB 
        # when the main process starts below.
        su-exec grafana touch "$MARKER"
        echo "Marker file created by the Leader."
    else
        # Follower node
        echo "Initialization in progress by another replica. Waiting..."
        while [ ! -f "$MARKER" ]; do
            sleep 2
        done
        # Give the leader a small head start to ensure DB tables are actually created
        # before followers try to access them simultaneously.
        sleep 5
        echo "Initialization marker found. Proceeding as Follower."
    fi
else
    echo "Marker file found. Skipping initialization lock."
fi

echo "Starting Grafana application..."

# Privilege Drop: switch to the grafana user to run the main process
exec su-exec grafana /run.sh "$@"