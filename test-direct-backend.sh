#!/bin/bash

echo "🔍 Testing Direct Backend Access"
echo "==============================="

echo "📍 Testing if backend is running internally..."

# Test if we can access the backend service directly
kubectl get pods -n web -l app=blog-backend 2>/dev/null || echo "kubectl not available or backend not running"

echo ""
echo "📍 Testing port forwarding to backend..."

# Try port forwarding to test backend directly
echo "Run this command to test backend directly:"
echo "kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo ""
echo "Then test with:"
echo "curl http://localhost:3001/health"
echo "curl http://localhost:3001/posts"

echo ""
echo "📍 Alternative: Test with internal service URL"
echo "If you're on the cluster, try:"
echo "curl http://blog-backend-service.web.svc.cluster.local:3001/health"
