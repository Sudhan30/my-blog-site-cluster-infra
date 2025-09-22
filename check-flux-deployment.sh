#!/bin/bash

echo "🔍 Checking Flux Deployment Status"
echo "=================================="

echo "📍 1. Checking Flux System Status..."
kubectl get pods -n flux-system 2>/dev/null || echo "❌ kubectl not available"

echo ""
echo "📍 2. Checking Blog Application Status..."
kubectl get kustomization blog -n flux-system 2>/dev/null || echo "❌ Blog kustomization not found"

echo ""
echo "📍 3. Checking Backend Application Status..."
kubectl get kustomization backend -n flux-system 2>/dev/null || echo "❌ Backend kustomization not found"

echo ""
echo "📍 4. Checking Pod Status in web namespace..."
kubectl get pods -n web 2>/dev/null || echo "❌ Cannot access web namespace"

echo ""
echo "📍 5. Checking Services..."
kubectl get services -n web 2>/dev/null || echo "❌ Cannot access services"

echo ""
echo "📍 6. Checking Ingress..."
kubectl get ingress -n web 2>/dev/null || echo "❌ Cannot access ingress"

echo ""
echo "📍 7. Checking Backend Pod Logs..."
kubectl logs deployment/blog-backend -n web --tail=20 2>/dev/null || echo "❌ Cannot access backend logs"

echo ""
echo "📍 8. Checking Flux Events..."
kubectl get events -n flux-system --sort-by='.lastTimestamp' --tail=10 2>/dev/null || echo "❌ Cannot access events"

echo ""
echo "🎯 Quick Status Check Commands:"
echo "kubectl get pods -n web"
echo "kubectl get kustomization -n flux-system"
echo "kubectl logs deployment/blog-backend -n web --tail=50"
echo "kubectl describe kustomization blog -n flux-system"
