#!/bin/bash

echo "🔄 Resetting Grafana Password via API"
echo "===================================="

echo "📍 1. Getting current password from secret..."
SECRET_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret password: $SECRET_PASSWORD"

echo ""
echo "📍 2. Starting port forward to Grafana..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!

echo "📍 3. Waiting for port forward to be ready..."
sleep 5

echo ""
echo "📍 4. Resetting admin password via API..."

# Try to reset the password using the API
RESPONSE=$(curl -s -X PUT http://admin:admin@localhost:3000/api/admin/users/admin/password \
  -H 'Content-Type: application/json' \
  -d "{\"password\":\"$SECRET_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

HTTP_STATUS=$(echo $RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
RESPONSE_BODY=$(echo $RESPONSE | sed -e 's/HTTPSTATUS:.*//g')

echo "API Response: $RESPONSE_BODY"
echo "HTTP Status: $HTTP_STATUS"

echo ""
echo "📍 5. Testing login with new password..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$SECRET_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 6. Stopping port forward..."
kill $PF_PID

echo ""
if [ "$HTTP_STATUS" = "200" ] && [ "$LOGIN_STATUS" = "200" ]; then
    echo "🎯 Password Reset Successful!"
    echo ""
    echo "📋 Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: $SECRET_PASSWORD"
else
    echo "❌ Password reset failed. Trying alternative method..."
    echo ""
    echo "📍 7. Alternative: Delete persistent storage to start fresh..."
    echo "This will delete all Grafana data but will use the new password:"
    echo "kubectl delete pvc grafana-pvc -n web"
    echo "kubectl delete pods -n web -l app=grafana"
fi
