# Dockerfile for Dagster Orchestrator
# Build context must point to the orchestrator application repo:
#   docker build -f clusters/prod/apps/orchestrator/Dockerfile /path/to/orchestrator/
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies (for psycopg2 and TA-Lib)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc-dev \
    libpq-dev \
    python3-dev \
    wget \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install TA-Lib C library (required for talib Python package)
RUN wget http://prdownloads.sourceforge.net/ta-lib/ta-lib-0.4.0-src.tar.gz && \
    tar -xzf ta-lib-0.4.0-src.tar.gz && \
    cd ta-lib && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd .. && \
    rm -rf ta-lib ta-lib-0.4.0-src.tar.gz

# Copy and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY common/ ./common/
COPY orchestrator/ ./orchestrator/
COPY config/ ./config/

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV DAGSTER_HOME=/app/dagster_home

# Create required directories
RUN mkdir -p /app/dagster_home /opt/dagster/logs /app/models

# Default command (override for daemon)
CMD ["dagster-webserver", "-h", "0.0.0.0", "-p", "3000", "-f", "orchestrator/__init__.py"]
