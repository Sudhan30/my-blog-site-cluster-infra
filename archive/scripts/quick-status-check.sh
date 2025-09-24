#!/bin/bash

echo "⚡ Quick Status Check"
echo "===================="

echo "📍 Backend Pod Status:"
kubectl get pods -n web -l app=blog-backend 2>/dev/null | grep -E "(NAME|blog-backend)" || echo "❌ Backend pod not found"

echo ""
echo "📍 Backend Service:"
kubectl get service blog-backend-service -n web 2>/dev/null || echo "❌ Backend service not found"

echo ""
echo "📍 All Pods in web namespace:"
kubectl get pods -n web 2>/dev/null || echo "❌ Cannot access web namespace"

echo ""
echo "📍 Flux Kustomization Status:"
kubectl get kustomization -n flux-system 2>/dev/null | grep -E "(NAME|blog|backend)" || echo "❌ Flux kustomization not found"

echo ""
echo "📍 Recent Backend Logs (last 10 lines):"
kubectl logs deployment/blog-backend -n web --tail=10 2>/dev/null || echo "❌ Cannot access backend logs"

echo ""
echo "🎯 If backend pod shows 'Running' and logs look good, try:"
echo "kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo "curl http://localhost:3001/health"
