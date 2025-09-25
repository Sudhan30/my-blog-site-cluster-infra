# Multi-stage build for blog-site-infra
# Use specific alpine version to avoid tag resolution pulls
FROM alpine:3.19 AS base

# Install common tools in single RUN to reduce layers
RUN apk add --no-cache \
    curl \
    wget \
    bash \
    supervisor \
    tzdata \
    postgresql \
    redis && \
    rm -rf /var/cache/apk/*

# Create necessary users (skip if already exist)
RUN adduser -D -s /bin/sh prometheus 2>/dev/null || true && \
    adduser -D -s /bin/sh grafana 2>/dev/null || true

# Set timezone
ENV TZ=UTC

# Create directories
RUN mkdir -p /etc/supervisor/conf.d \
    /var/log/supervisor \
    /opt/infra/scripts \
    /opt/infra/configs \
    /opt/infra/monitoring

# Copy configuration files
COPY configs/ /opt/infra/configs/
COPY scripts/ /opt/infra/scripts/
COPY monitoring/ /opt/infra/monitoring/

# Make scripts executable
RUN chmod +x /opt/infra/scripts/*.sh

# Copy supervisor configuration
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose ports
EXPOSE 80 3001 5432 6379 9090 3000 9114 9115

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/health || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
