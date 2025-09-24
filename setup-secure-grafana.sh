#!/bin/bash

echo "🔐 Secure Grafana Setup"
echo "======================"

echo "📍 Generating secure password..."

# Generate a secure random password
SECURE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
SECURE_PASSWORD="${SECURE_PASSWORD}A1!"

echo "📍 Generated secure password: $SECURE_PASSWORD"
echo ""

echo "📍 Creating Kubernetes secret with secure password..."

# Create the secret with the generated password
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$SECURE_PASSWORD" \
  -n web \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "📍 Restarting Grafana deployment to use new credentials..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 Waiting for deployment to complete..."
kubectl rollout status deployment/grafana -n web

echo ""
echo "🎯 Grafana Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "✅ URL: https://grafana.sudharsana.dev"
echo "✅ Username: admin"
echo "✅ Password: $SECURE_PASSWORD"
echo ""
echo "🔐 Security Notes:"
echo "• Password is generated randomly and stored in Kubernetes Secret"
echo "• Password is NOT stored in Git repository"
echo "• Save this password securely - it won't be shown again"
echo ""
echo "💾 Save this information securely!"
