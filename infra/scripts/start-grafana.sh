#!/bin/bash

# Start Grafana
echo "Starting Grafana..."

# Install Grafana if not present
if ! command -v grafana-server &> /dev/null; then
    wget -O /tmp/grafana.tar.gz https://dl.grafana.com/oss/release/grafana-9.3.0.linux-amd64.tar.gz
    tar -xzf /tmp/grafana.tar.gz -C /opt/
    mv /opt/grafana-9.3.0 /opt/grafana
    ln -s /opt/grafana/bin/grafana-server /usr/local/bin/grafana-server
fi

# Create Grafana data directory
mkdir -p /var/lib/grafana
chown grafana:grafana /var/lib/grafana 2>/dev/null || chown 1001:1001 /var/lib/grafana

# Start Grafana
grafana-server \
    --config=/opt/grafana/conf/defaults.ini \
    --homepath=/opt/grafana \
    --pidfile=/var/run/grafana-server.pid \
    --packaging=alpine \
    --cfg:default.paths.data=/var/lib/grafana \
    --cfg:default.paths.logs=/var/log/grafana \
    --cfg:default.paths.plugins=/var/lib/grafana/plugins \
    --cfg:default.paths.provisioning=/opt/grafana/conf/provisioning \
    --cfg:default.server.http_addr=0.0.0.0 \
    --cfg:default.server.http_port=3000

echo "Grafana started successfully"
