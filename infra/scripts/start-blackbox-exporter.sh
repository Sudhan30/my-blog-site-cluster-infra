#!/bin/bash

# Start Blackbox Exporter
echo "Starting Blackbox Exporter..."

# Install Blackbox Exporter if not present
if ! command -v blackbox_exporter &> /dev/null; then
    wget -O /tmp/blackbox_exporter.tar.gz https://github.com/prometheus/blackbox_exporter/releases/download/v0.22.0/blackbox_exporter-0.22.0.linux-amd64.tar.gz
    tar -xzf /tmp/blackbox_exporter.tar.gz -C /opt/
    mv /opt/blackbox_exporter-0.22.0.linux-amd64 /opt/blackbox_exporter
    ln -s /opt/blackbox_exporter/blackbox_exporter /usr/local/bin/blackbox_exporter
fi

# Start Blackbox Exporter
blackbox_exporter \
    --config.file=/opt/infra/monitoring/blackbox.yml \
    --web.listen-address=0.0.0.0:9115

echo "Blackbox Exporter started successfully"
