#!/bin/bash
set -e

# TODO: create the database and the user for Authelia
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER authelia WITH PASSWORD 'authelia_password';
    CREATE DATABASE authelia;
    GRANT ALL PRIVILEGES ON DATABASE authelia TO authelia;
    ALTER DATABASE authelia OWNER TO authelia;
EOSQL