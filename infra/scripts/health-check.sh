#!/bin/bash

# Health check script
echo "Starting health check service..."

while true; do
    echo "=== Health Check $(date) ==="
    
    # Check Nginx
    if curl -f http://localhost:80/health >/dev/null 2>&1; then
        echo "✅ Nginx: Healthy"
    else
        echo "❌ Nginx: Unhealthy"
    fi
    
    # Check PostgreSQL
    if command -v pg_isready >/dev/null 2>&1 && pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
        echo "✅ PostgreSQL: Healthy"
    else
        echo "❌ PostgreSQL: Unhealthy"
    fi
    
    # Check Redis
    if command -v redis-cli >/dev/null 2>&1 && redis-cli ping >/dev/null 2>&1; then
        echo "✅ Redis: Healthy"
    else
        echo "❌ Redis: Unhealthy"
    fi
    
    # Check Prometheus
    if curl -f http://localhost:9090/-/healthy >/dev/null 2>&1; then
        echo "✅ Prometheus: Healthy"
    else
        echo "❌ Prometheus: Unhealthy"
    fi
    
    # Check Grafana
    if curl -f http://localhost:3000/api/health >/dev/null 2>&1; then
        echo "✅ Grafana: Healthy"
    else
        echo "❌ Grafana: Unhealthy"
    fi
    
    echo "=========================="
    sleep 30
done
