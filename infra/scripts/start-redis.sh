#!/bin/bash

# Start Redis
echo "Starting Redis..."

# Redis is already installed in the base image

# Create Redis data directory
mkdir -p /var/lib/redis
chown redis:redis /var/lib/redis

# Start Redis server
redis-server --daemonize no --bind 0.0.0.0 --port 6379 --dir /var/lib/redis

echo "Redis started successfully"
