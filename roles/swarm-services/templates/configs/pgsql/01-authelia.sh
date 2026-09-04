#!/bin/bash
set -e

# TODO[VCC-012b]: Create the database and the user for Authelia
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER {{ authelia_db_user }} WITH PASSWORD '{{ authelia_db_password }}';
    CREATE DATABASE {{ authelia_db }} OWNER {{ authelia_db_user }};
EOSQL