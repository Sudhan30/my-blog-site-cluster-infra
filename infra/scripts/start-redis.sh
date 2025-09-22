#!/bin/bash

# Start Redis
echo "Starting Redis..."

# Install Redis if not present
if ! command -v redis-server &> /dev/null; then
    apk add --no-cache redis
fi

# Create Redis data directory
mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis

# Start Redis server
redis-server --daemonize no --bind 0.0.0.0 --port 6379 --dir /var/lib/redis

echo "Redis started successfully"
