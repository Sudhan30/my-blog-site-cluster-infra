#!/bin/bash

# Start Prometheus
echo "Starting Prometheus..."

# Install Prometheus if not present
if ! command -v prometheus &> /dev/null; then
    wget -O /tmp/prometheus.tar.gz https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
    tar -xzf /tmp/prometheus.tar.gz -C /opt/
    mv /opt/prometheus-2.40.0.linux-amd64 /opt/prometheus
    ln -s /opt/prometheus/prometheus /usr/local/bin/prometheus
fi

# Create Prometheus data directory
mkdir -p /var/lib/prometheus
chown prometheus:prometheus /var/lib/prometheus 2>/dev/null || chown 1000:1000 /var/lib/prometheus

# Start Prometheus
prometheus \
    --config.file=/opt/infra/monitoring/prometheus.yml \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.libraries=/opt/prometheus/console_libraries \
    --web.console.templates=/opt/prometheus/consoles \
    --web.listen-address=0.0.0.0:9090 \
    --web.enable-lifecycle

echo "Prometheus started successfully"
