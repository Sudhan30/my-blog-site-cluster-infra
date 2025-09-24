#!/bin/bash

echo "🔐 Fixing Grafana Secret - Final Solution"
echo "========================================="

echo "📍 1. Checking current secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 2. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Generated password: $NEW_PASSWORD"

echo ""
echo "📍 3. Deleting old secret..."
kubectl delete secret grafana-credentials -n web

echo ""
echo "📍 4. Creating new secret with secure password..."
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  -n web

echo ""
echo "📍 5. Verifying new secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 6. Restarting Grafana pods..."
kubectl delete pods -n web -l app=grafana

echo ""
echo "📍 7. Waiting for new pod to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n web --timeout=120s

echo ""
echo "📍 8. Testing login..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 5

LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 9. Stopping port forward..."
kill $PF_PID

echo ""
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "🎯 SUCCESS! Grafana is working with new password!"
    echo ""
    echo "📋 Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: $NEW_PASSWORD"
    echo ""
    echo "💾 Save this password securely!"
else
    echo "❌ Still not working. Let's check pod logs..."
    kubectl logs deployment/grafana -n web --tail=20
fi
