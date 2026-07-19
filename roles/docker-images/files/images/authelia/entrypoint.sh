#!/bin/sh
set -eu # fail on error

CONFIG="/config/configuration.yml"
MARKER="/config/.authelia-configured"

#wait for the PostgreSQL database to be ready
echo "Waiting for the PostgreSQL database on port 5432..."

while ! echo "" | nc -w 1 db 5432 > /dev/null 2>&1; do
    echo "PostgreSQL is unavailable - sleeping..."
    sleep 2
done
echo "Database is alive and responding!"

#check if the marker file exists to determine if this is the first run
if [ ! -f "$MARKER" ]; then
    echo "First run detected. Initializing Authelia database schema..."
    
    # Run the storage migration to create tables
    authelia storage migrate up -c "$CONFIG"
    
    # Mark Authelia as configured
    touch "$MARKER"
    echo "Database initialized and marker file created."
else
    echo "Marker file found. Skipping database initialization."
fi


echo "Starting Authelia..."
exec authelia "$@"