#!/bin/bash

echo "🔍 Diagnosing API 404 Issues"
echo "============================"

echo "📍 1. Checking if backend pod is running..."
kubectl get pods -n web -l app=blog-backend 2>/dev/null || echo "❌ Backend pod not found or kubectl not available"

echo ""
echo "📍 2. Checking backend service..."
kubectl get service blog-backend-service -n web 2>/dev/null || echo "❌ Backend service not found"

echo ""
echo "📍 3. Testing backend directly (port forward)..."
echo "Run this command to test backend directly:"
echo "kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo "Then test: curl http://localhost:3001/health"

echo ""
echo "📍 4. Checking ingress configuration..."
kubectl get ingress blog -n web -o yaml 2>/dev/null || echo "❌ Cannot access ingress"

echo ""
echo "📍 5. Checking if backend is responding internally..."
kubectl exec -it deployment/blog-backend -n web -- curl localhost:3001/health 2>/dev/null || echo "❌ Backend not responding internally"

echo ""
echo "📍 6. Checking backend logs for errors..."
kubectl logs deployment/blog-backend -n web --tail=30 2>/dev/null || echo "❌ Cannot access logs"

echo ""
echo "📍 7. Checking Flux Image Automation status..."
kubectl get imagerepository blog-backend -n flux-system 2>/dev/null || echo "❌ Image repository not found"
kubectl get imagepolicy blog-backend -n flux-system 2>/dev/null || echo "❌ Image policy not found"

echo ""
echo "📍 8. Checking latest commits in repo..."
echo "Latest commit should be: 'Fix API routing issue - backend now handles both /api/* and /* paths'"

echo ""
echo "🎯 Most Likely Issues:"
echo "1. Backend pod not running or crashed"
echo "2. Backend service not configured correctly"
echo "3. Ingress routing issue"
echo "4. Flux deployment not complete yet"
echo "5. Backend code not updated yet"
