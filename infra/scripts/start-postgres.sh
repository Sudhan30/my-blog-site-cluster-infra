#!/bin/bash

# Start PostgreSQL
echo "Starting PostgreSQL..."

# PostgreSQL is already installed in the base image

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
