#!/bin/bash

echo "🔄 Restarting Grafana with New Credentials"
echo "=========================================="

echo "📍 1. Checking current Grafana pod status..."
kubectl get pods -n web -l app=grafana

echo ""
echo "📍 2. Checking if the secret exists..."
kubectl get secret grafana-credentials -n web

echo ""
echo "📍 3. Forcing Grafana pod restart..."
kubectl delete pods -n web -l app=grafana

echo ""
echo "📍 4. Waiting for new pod to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n web --timeout=120s

echo ""
echo "📍 5. Checking new pod status..."
kubectl get pods -n web -l app=grafana

echo ""
echo "📍 6. Getting the current password from secret..."
CURRENT_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Current password: $CURRENT_PASSWORD"

echo ""
echo "📍 7. Testing Grafana access..."
echo "URL: https://grafana.sudharsana.dev"
echo "Username: admin"
echo "Password: $CURRENT_PASSWORD"

echo ""
echo "🎯 Grafana should now use the new password!"
echo "Try logging in with the password shown above."
