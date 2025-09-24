#!/bin/bash

echo "🔐 Fixing Grafana Password"
echo "=========================="

echo "📍 1. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
NEW_PASSWORD="${NEW_PASSWORD}A1!"

echo "📍 Generated password: $NEW_PASSWORD"
echo ""

echo "📍 2. Updating the Kubernetes secret..."
kubectl patch secret grafana-credentials -n web -p "{\"data\":{\"admin-password\":\"$(echo -n "$NEW_PASSWORD" | base64)\"}}"

echo ""
echo "📍 3. Restarting Grafana pods to use new password..."
kubectl delete pods -n web -l app=grafana

echo ""
echo "📍 4. Waiting for new pods to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n web --timeout=120s

echo ""
echo "📍 5. Verifying the new password..."
VERIFIED_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret now contains: $VERIFIED_PASSWORD"

echo ""
echo "📍 6. Checking Grafana pod status..."
kubectl get pods -n web -l app=grafana

echo ""
echo "🎯 Grafana Password Fixed!"
echo ""
echo "📋 Access Information:"
echo "✅ URL: https://grafana.sudharsana.dev"
echo "✅ Username: admin"
echo "✅ Password: $NEW_PASSWORD"
echo ""
echo "💾 Save this password securely!"
