#!/bin/bash

# Start Postgres Exporter
echo "Starting Postgres Exporter..."

# Install Postgres Exporter if not present
if ! command -v postgres_exporter &> /dev/null; then
    wget -O /tmp/postgres_exporter.tar.gz https://github.com/prometheus-community/postgres_exporter/releases/download/v0.11.1/postgres_exporter-0.11.1.linux-amd64.tar.gz
    tar -xzf /tmp/postgres_exporter.tar.gz -C /opt/
    mv /opt/postgres_exporter-0.11.1.linux-amd64 /opt/postgres_exporter
    ln -s /opt/postgres_exporter/postgres_exporter /usr/local/bin/postgres_exporter
fi

# Start Postgres Exporter
postgres_exporter \
    --web.listen-address=0.0.0.0:9114 \
    --config.dsn="postgresql://blog_user:blog_password@localhost:5432/blog_db?sslmode=disable"

echo "Postgres Exporter started successfully"
