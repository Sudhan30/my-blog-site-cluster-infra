#!/bin/bash

echo "🔍 Testing Backend Routes Directly"
echo "=================================="

echo "📍 Testing if backend pod is running..."
kubectl get pods -n web -l app=blog-backend 2>/dev/null || echo "❌ kubectl not available or backend not running"

echo ""
echo "📍 Testing port forwarding to backend..."

echo "Run these commands to test backend directly:"
echo ""
echo "1. Port forward to backend:"
echo "   kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo ""
echo "2. Test routes directly:"
echo "   curl http://localhost:3001/health"
echo "   curl http://localhost:3001/api/posts"
echo "   curl http://localhost:3001/api/posts/1/likes"
echo ""

echo "📍 Testing with kubectl exec (if backend pod exists):"
echo "kubectl exec -it deployment/blog-backend -n web -- curl localhost:3001/health"
echo ""

echo "📍 Checking backend logs:"
echo "kubectl logs deployment/blog-backend -n web --tail=50"
