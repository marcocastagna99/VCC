#!/bin/sh
set -eu # fail on error

# Make forgejo trust our TLS certificate
update-ca-certificates

# This helper allows to run stuff as the forgejo user
forgejo_cli() { sudo -u git forgejo --config /data/gitea/conf/app.ini "$@"; }

#wait for the PostgreSQL database to be ready
echo "Waiting for the database to be ready..."
export PGPASSWORD="$FORGEJO__database__PASSWD"

while ! psql -h db -U forgejo -d forgejo -c 'SELECT 1;'; do
    echo "PostgreSQL is unavailable - sleeping..."
    sleep 2
done
echo "Database is alive and responding!"

#check if the configuration file exists to determine if this is the first run
if [ ! -f /data/gitea/conf/app.ini ]; then
    echo "First run detected. Initializing Forgejo..."
    
    mkdir -p /data/gitea
    mkdir -p /data/queues
    mkdir -p /data/gitea/conf
    cp /conf/app.ini /data/gitea/conf/app.ini
    
    # Fix permission for data directory
    chown -R git:git /data/gitea
    chown -R git:git /data/queues

    # DB migration
    echo "Migrating forgejo database..."
    forgejo_cli migrate

    # Create admin user
    echo "Creating admin user..."
    forgejo_cli admin user create \
        --admin \
        --username siteadmin \
        --password admin \
        --email admin@vcc.local \
        --must-change-password=false

    #wait for Authelia to be ready
    echo "Waiting for Authelia to be ready..."
    while ! curl -kfsS https://auth.vcc.local/api/health | grep -q '"status":"OK"'; do
        echo "Authelia is unavailable - sleeping..."
        sleep 2
    done
    echo "Authelia is alive!"

    # Configure OpenID Connect via Authelia
    echo "Configuring OpenID Connect via Authelia..."
    forgejo_cli admin auth add-oauth \
        --name Authelia \
        --provider openidConnect \
        --key forgejo \
        --secret forgejo_secret \
        --auto-discover-url "https://auth.vcc.local/.well-known/openid-configuration"
else
    echo "Configuration file found. Skipping initialization."
fi


echo "Starting Forgejo application..."
# exec "$@" will run the CMD specified in the Dockerfile, which is /usr/bin/s6-svscan /etc/s6
exec "$@"