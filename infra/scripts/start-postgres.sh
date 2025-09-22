#!/bin/bash

# Start PostgreSQL
echo "Starting PostgreSQL..."

# Install PostgreSQL if not present
if ! command -v postgres &> /dev/null; then
    apk add --no-cache postgresql postgresql-contrib
fi

# Initialize database if not exists
if [ ! -d "/var/lib/postgresql/data" ]; then
    echo "Initializing PostgreSQL database..."
    mkdir -p /var/lib/postgresql/data
    chown postgres:postgres /var/lib/postgresql/data
    su postgres -c "initdb -D /var/lib/postgresql/data"
fi

# Start PostgreSQL
su postgres -c "postgres -D /var/lib/postgresql/data -c listen_addresses='*' -c port=5432"

echo "PostgreSQL started successfully"
