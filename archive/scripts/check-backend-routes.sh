#!/bin/bash

echo "🔍 Checking Backend Route Configuration"
echo "======================================"

echo "📍 1. Testing all backend routes directly..."
echo "Health endpoint:"
curl -s http://localhost:3001/health | jq '.status' 2>/dev/null || echo "Health check failed"

echo ""
echo "Posts endpoint (should work with new code):"
curl -s http://localhost:3001/posts | jq '.posts' 2>/dev/null || echo "Posts endpoint failed"

echo ""
echo "API posts endpoint:"
curl -s http://localhost:3001/api/posts | jq '.posts' 2>/dev/null || echo "API posts endpoint failed"

echo ""
echo "📍 2. Checking backend pod image..."
kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "Cannot get pod image"

echo ""
echo "📍 3. Checking if backend pod was restarted recently..."
kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].status.startTime}' 2>/dev/null || echo "Cannot get start time"

echo ""
echo "📍 4. Checking backend logs for route registration..."
kubectl logs deployment/blog-backend -n web --tail=50 | grep -E "(posts|routes|listening)" 2>/dev/null || echo "No route info in logs"

echo ""
echo "🎯 Expected Results:"
echo "✅ Health: 'healthy'"
echo "✅ Posts: [] (empty array)"
echo "✅ API Posts: [] (empty array)"
echo ""
echo "If posts endpoints still fail, the backend code hasn't been updated yet."
