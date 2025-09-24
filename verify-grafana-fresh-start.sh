#!/bin/bash

echo "✅ Verifying Grafana Fresh Start"
echo "==============================="

echo "📍 1. Checking if Grafana pod is running..."
kubectl get pods -n web -l app=grafana

echo ""
echo "📍 2. Waiting for Grafana to be ready..."
kubectl wait --for=condition=ready pod -l app=grafana -n web --timeout=120s

echo ""
echo "📍 3. Getting current password from secret..."
CURRENT_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret password: $CURRENT_PASSWORD"

echo ""
echo "📍 4. Testing Grafana login..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 5

LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$CURRENT_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 5. Stopping port forward..."
kill $PF_PID

echo ""
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "🎯 SUCCESS! Grafana is working with new password!"
    echo ""
    echo "📋 Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: $CURRENT_PASSWORD"
    echo ""
    echo "💾 Save this password securely!"
else
    echo "❌ Login still not working. Checking pod logs..."
    kubectl logs deployment/grafana -n web --tail=10
fi
