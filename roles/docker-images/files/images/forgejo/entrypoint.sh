#!/bin/sh
set -eu # fail on error

# Make forgejo trust our TLS certificate
update-ca-certificates

# TODO[VCC-008]: Create entrypoint for forgejo. It should support replicated deployments

# This helper allows to run stuff as the forgejo user
forgejo_cli() { sudo -u git forgejo --config /data/gitea/conf/app.ini "$@"; }

# Read secrets from Docker Swarm
ADMIN_PASS=$(cat /run/secrets/forgejo_admin_password)
OAUTH_SECRET=$(cat /run/secrets/forgejo_oauth_secret)
export PGPASSWORD=$(cat /run/secrets/forgejo_db_password)

# wait for the PostgreSQL database to be ready
echo "Waiting for the database to be ready..."
while ! psql -h db -U forgejo -d forgejo -c 'SELECT 1;'; do
    echo "PostgreSQL is unavailable - sleeping..."
    sleep 2
done
echo "Database is alive and responding!"

MARKER="/data/gitea/conf/app.ini"
LOCK_DIR="/data/.forgejo_init_lock"

# check if the configuration file exists to determine if this is the first run
if [ ! -f "$MARKER" ]; then
    # Try to create lock directory atomically (Leader election)
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "First run detected (Leader). Initializing Forgejo..."
        
        mkdir -p /data/gitea
        mkdir -p /data/queues
        mkdir -p /data/gitea/conf
        cp /conf/app.ini "$MARKER"
        
        # Fix permission for data directory
        chown -R git:git /data/gitea
        chown -R git:git /data/queues

        # DB migration
        echo "Migrating forgejo database..."
        forgejo_cli migrate

        # Create admin user using the secret variable
        echo "Creating admin user..."
        forgejo_cli admin user create \
            --admin \
            --username siteadmin \
            --password "$ADMIN_PASS" \
            --email admin@vcc.local \
            --must-change-password=false

        # wait for Authelia to be ready
        echo "Waiting for Authelia to be ready..."
        while ! curl -kfsS https://auth.vcc.local/api/health | grep -q '"status":"OK"'; do
            echo "Authelia is unavailable - sleeping..."
            sleep 2
        done
        echo "Authelia is alive!"

        # Configure OpenID Connect via Authelia using the secret variable
        echo "Configuring OpenID Connect via Authelia..."
        forgejo_cli admin auth add-oauth \
            --name authelia \
            --provider openidConnect \
            --key forgejo \
            --secret "$OAUTH_SECRET" \
            --auto-discover-url "https://auth.vcc.local/.well-known/openid-configuration"
            
        echo "Initialization complete."
    else
        # Follower node behavior
        echo "Initialization in progress by another replica. Waiting..."
        while [ ! -f "$MARKER" ]; do
            sleep 2
        done
        echo "Initialization completed by the Leader."
    fi
else
    echo "Configuration file found. Skipping initialization."
fi

echo "Starting Forgejo application..."
# exec "$@" will run the CMD specified in the Dockerfile
exec "$@"