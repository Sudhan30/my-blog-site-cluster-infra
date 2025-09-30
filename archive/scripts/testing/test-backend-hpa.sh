#!/bin/bash

echo "🚀 Testing Backend HPA Configuration"
echo "===================================="

echo "📊 Current Backend Pod Status:"
kubectl get pods -n web -l app=blog-backend

echo ""
echo "📈 HPA Status:"
kubectl get hpa -n web blog-backend-hpa

echo ""
echo "📋 HPA Details:"
kubectl describe hpa -n web blog-backend-hpa

echo ""
echo "🔍 Backend Deployment Status:"
kubectl get deployment blog-backend -n web

echo ""
echo "📊 Resource Usage:"
kubectl top pods -n web -l app=blog-backend

echo ""
echo "✅ Expected HPA Configuration:"
echo "- Min Replicas: 2"
echo "- Max Replicas: 10"
echo "- CPU Target: 70%"
echo "- Memory Target: 85%"
echo "- Scale Up: Fast (60s window)"
echo "- Scale Down: Conservative (5min window)"
