#!/bin/bash

# Connect to Dagster Orchestrator via secure K8s tunnel
echo "Connecting to Dagster Orchestrator..."

# Get pod name (works for single pod deployment)
POD_NAME=$(kubectl get pods -n orchestrator -l app=dagster -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo "ERROR: Dagster pod not found. Is it deployed?"
    exit 1
fi

echo "Found Pod: $POD_NAME"
echo "---------------------------------------------------"
echo "Dagster available at: http://192.168.1.129:30030"
echo "---------------------------------------------------"

# Kill any existing port-forward on port 30030
PID=$(lsof -t -i:30030)
if [ ! -z "$PID" ]; then
    echo "Stopping existing process on port 30030 (PID: $PID)..."
    kill $PID
fi

# detailed logging for debugging
nohup kubectl port-forward $POD_NAME 30030:3000 -n orchestrator --address 0.0.0.0 > dagster_forward.log 2>&1 &

echo "Background process started. Logs at dagster_forward.log"
