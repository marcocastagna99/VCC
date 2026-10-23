#!/bin/sh
set -eu # fail on error

CONFIG="/config/configuration.yml"
MARKER="/config/.authelia-configured"
LOCK_DIR="/config/.authelia_init_lock"
SECRET_FILE="/run/secrets/jwks_key"

# TODO[VCC-006]: Create entrypoint for authelia. It should support replicated deployments

# wait until database is alive
# Authelia image comes with netcat (nc) installed and apt is not available
echo "Waiting for the PostgreSQL database on port 5432..."
while ! echo "" | nc -w 1 db 5432 > /dev/null 2>&1; do
    echo "PostgreSQL is unavailable - sleeping..."
    sleep 2
done
echo "Database is alive and responding!"

# Check if Authelia has been configured before
if [ ! -f "$MARKER" ]; then
    # Try to create a lock directory atomically. If successful, this replica is the Leader.
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "First run detected (Leader). Starting configuration..."
        
        # Inject jwks key from secrets
        echo "Injecting jwks key from secrets"
        # keep space indentation for yaml
        JWKS_KEY=$(sed 's/^/          /' "$SECRET_FILE")
        sed -i '/JWKS_PRIVATE_KEY_CONTENT/{
            r /dev/stdin
            d
        }' "$CONFIG" <<EOF
$JWKS_KEY
EOF

        echo "Initialize Authelia database schema"
        authelia storage migrate up -c "$CONFIG"
        
        # Mark Authelia as configured
        touch "$MARKER"
        echo "Database initialized and marker file created by the Leader."
    else
        # If mkdir fails, another replica is doing the initialization. We are a Follower.
        echo "Initialization in progress by another replica. Waiting..."
        while [ ! -f "$MARKER" ]; do
            sleep 2
        done
        echo "Initialization completed by the Leader. Proceeding."
    fi
else
    echo "Marker file found. Skipping database initialization."
fi

# Execute the original entrypoint
echo "Starting Authelia..."
exec authelia "$@"