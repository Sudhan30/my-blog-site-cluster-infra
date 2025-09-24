#!/bin/bash

echo "🔍 Debugging API Route Issue"
echo "============================"

echo "📍 1. Checking backend pod status..."
kubectl get pods -n web -l app=blog-backend

echo ""
echo "📍 2. Checking backend pod image..."
kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].spec.containers[0].image}'

echo ""
echo "📍 3. Checking when pod was created..."
kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].metadata.creationTimestamp}'

echo ""
echo "📍 4. Checking backend logs for route registration..."
kubectl logs deployment/blog-backend -n web --tail=20 | grep -E "(posts|routes|listening|Express)"

echo ""
echo "📍 5. Testing backend directly (port forward)..."
echo "Run this command to test backend directly:"
echo "kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo "Then test: curl http://localhost:3001/posts"

echo ""
echo "📍 6. Checking Flux Image Automation..."
kubectl get imagerepository blog-backend -n flux-system
kubectl get imagepolicy blog-backend -n flux-system

echo ""
echo "📍 7. Force restart backend deployment..."
echo "Run this command to force restart:"
echo "kubectl rollout restart deployment/blog-backend -n web"

echo ""
echo "🎯 Expected Results:"
echo "✅ Backend pod should be running"
echo "✅ Image should be latest (with dual routes)"
echo "✅ Logs should show route registration"
echo "✅ Direct test should work: curl http://localhost:3001/posts"
