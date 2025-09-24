#!/bin/bash

# Blog Deployment Testing Script
# Usage: ./test-deployment.sh [namespace]

NAMESPACE=${1:-web}
APP_LABEL="app=blog"
TIMEOUT=300  # 5 minutes timeout

echo "🚀 Starting Blog Deployment Test..."
echo "📅 $(date)"
echo "🏷️  Namespace: $NAMESPACE"
echo "🔍 App Label: $APP_LABEL"
echo "⏱️  Timeout: ${TIMEOUT}s"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "🔧 Checking prerequisites..."
if ! command_exists kubectl; then
    echo "❌ kubectl not found"
    exit 1
fi

if ! command_exists flux; then
    echo "❌ flux not found"
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Step 1: Check Flux status
echo "📋 Step 1: Checking Flux Kustomization Status"
flux get kustomizations -n flux-system
echo ""

# Step 2: Check Git source status
echo "📋 Step 2: Checking Git Source Status"
flux get sources git -n flux-system
echo ""

# Step 3: Wait for sync completion
echo "⏳ Step 3: Waiting for sync completion (timeout: ${TIMEOUT}s)"
timeout $TIMEOUT flux get kustomizations -n flux-system --watch || {
    echo "⚠️  Sync timeout reached"
}
echo ""

# Step 4: Check if resources exist
echo "🔍 Step 4: Checking if resources are created"
kubectl -n $NAMESPACE get all -l $APP_LABEL
echo ""

# Step 5: Check deployment status
echo "🚀 Step 5: Checking deployment status"
kubectl -n $NAMESPACE get deploy blog -o wide 2>/dev/null || {
    echo "❌ Deployment not found"
    exit 1
}

# Wait for rollout to complete
echo "⏳ Waiting for deployment rollout to complete..."
kubectl -n $NAMESPACE rollout status deploy/blog --timeout=${TIMEOUT}s || {
    echo "❌ Deployment rollout failed or timed out"
    exit 1
}
echo ""

# Step 6: Check pod status
echo "🔄 Step 6: Checking pod status"
kubectl -n $NAMESPACE get pods -l $APP_LABEL -o wide
echo ""

# Check if all pods are ready
READY_PODS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers | grep -c "Running")
TOTAL_PODS=$(kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers | wc -l)

echo "📊 Pod Status: $READY_PODS/$TOTAL_PODS pods running"

if [ "$READY_PODS" -eq 0 ]; then
    echo "❌ No pods are running"
    echo "🔍 Checking pod logs..."
    kubectl -n $NAMESPACE get pods -l $APP_LABEL --no-headers | head -1 | awk '{print $1}' | xargs -I {} kubectl -n $NAMESPACE logs {} --tail=20
    exit 1
fi

# Step 7: Test application health
echo "🌐 Step 7: Testing application health"
POD_NAME=$(kubectl -n $NAMESPACE get pod -l $APP_LABEL -o jsonpath='{.items[0].metadata.name}')

if [ ! -z "$POD_NAME" ]; then
    echo "🔍 Testing health endpoint on pod: $POD_NAME"
    
    # Test health endpoint
    HEALTH_RESPONSE=$(kubectl -n $NAMESPACE exec "$POD_NAME" -- curl -s -w "%{http_code}" http://localhost/health -o /dev/null 2>/dev/null)
    
    if [ "$HEALTH_RESPONSE" = "200" ]; then
        echo "✅ Health check passed (HTTP 200)"
    else
        echo "❌ Health check failed (HTTP $HEALTH_RESPONSE)"
        echo "🔍 Testing root endpoint..."
        ROOT_RESPONSE=$(kubectl -n $NAMESPACE exec "$POD_NAME" -- curl -s -w "%{http_code}" http://localhost/ -o /dev/null 2>/dev/null)
        echo "Root endpoint response: HTTP $ROOT_RESPONSE"
    fi
else
    echo "❌ No pods found for health check"
    exit 1
fi

# Step 8: Test service connectivity
echo "🔗 Step 8: Testing service connectivity"
SERVICE_IP=$(kubectl -n $NAMESPACE get svc blog -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ ! -z "$SERVICE_IP" ]; then
    echo "🔍 Service IP: $SERVICE_IP"
    # Test service from within cluster
    kubectl -n $NAMESPACE run test-curl --image=curlimages/curl --rm -i --restart=Never -- curl -s -w "%{http_code}" http://blog.$NAMESPACE.svc.cluster.local/health -o /dev/null || echo "❌ Service connectivity test failed"
else
    echo "⚠️  Service not found"
fi

echo ""
echo "🎉 Deployment test completed!"
echo "📅 $(date)"
echo ""

# Summary
echo "📊 SUMMARY:"
echo "  - Flux Sync: $(flux get kustomizations -n flux-system --no-header | grep blog | awk '{print $4}')"
echo "  - Deployment Status: $(kubectl -n $NAMESPACE get deploy blog --no-headers | awk '{print $2}')"
echo "  - Pods Running: $READY_PODS/$TOTAL_PODS"
echo "  - Health Check: $([ "$HEALTH_RESPONSE" = "200" ] && echo "✅ PASS" || echo "❌ FAIL")"
