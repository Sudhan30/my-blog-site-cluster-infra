#!/bin/bash

echo "🔐 Recreating Grafana Secret with New Password"
echo "=============================================="

echo "📍 1. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
NEW_PASSWORD="${NEW_PASSWORD}A1!"

echo "📍 Generated password: $NEW_PASSWORD"
echo ""

echo "📍 2. Deleting the old secret..."
kubectl delete secret grafana-credentials -n web

echo ""
echo "📍 3. Creating new secret with secure password..."
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  -n web

echo ""
echo "📍 4. Verifying the new secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 5. Restarting Grafana pods to use new secret..."
kubectl delete pods -n web -l app=grafana

echo ""
echo "📍 6. Waiting for new pods to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n web --timeout=120s

echo ""
echo "📍 7. Final verification..."
FINAL_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret contains: $FINAL_PASSWORD"

echo ""
echo "📍 8. Checking Grafana pod status..."
kubectl get pods -n web -l app=grafana

echo ""
echo "🎯 Grafana Secret Recreated Successfully!"
echo ""
echo "📋 Access Information:"
echo "✅ URL: https://grafana.sudharsana.dev"
echo "✅ Username: admin"
echo "✅ Password: $NEW_PASSWORD"
echo ""
echo "💾 Save this password securely!"
