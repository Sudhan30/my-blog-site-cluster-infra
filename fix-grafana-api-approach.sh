#!/bin/bash

echo "🔧 Fixing Grafana - API Approach"
echo "==============================="

echo "📍 1. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Generated password: $NEW_PASSWORD"

echo ""
echo "📍 2. Updating Grafana secret..."
kubectl delete secret grafana-credentials -n web 2>/dev/null || true
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  -n web

echo ""
echo "📍 3. Restarting Grafana deployment..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 4. Waiting for deployment to be ready..."
kubectl rollout status deployment/grafana -n web --timeout=120s

echo ""
echo "📍 5. Method 1: Try to create admin user via API..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 10

echo "Attempting to create admin user via API..."
CREATE_USER=$(curl -s -X POST http://localhost:3000/api/admin/users \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"Admin\",\"email\":\"admin@localhost\",\"login\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

CREATE_STATUS=$(echo $CREATE_USER | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
CREATE_BODY=$(echo $CREATE_USER | sed -e 's/HTTPSTATUS:.*//g')

echo "Create user response: $CREATE_BODY"
echo "Create user status: $CREATE_STATUS"

echo ""
echo "📍 6. Method 2: Try to update admin user password via API..."
UPDATE_PASSWORD=$(curl -s -X PUT http://localhost:3000/api/admin/users/1/password \
  -H 'Content-Type: application/json' \
  -d "{\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

UPDATE_STATUS=$(echo $UPDATE_PASSWORD | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
UPDATE_BODY=$(echo $UPDATE_PASSWORD | sed -e 's/HTTPSTATUS:.*//g')

echo "Update password response: $UPDATE_BODY"
echo "Update password status: $UPDATE_STATUS"

echo ""
echo "📍 7. Method 3: Try to get admin user info..."
GET_USER=$(curl -s -X GET http://localhost:3000/api/admin/users/1 \
  -w "HTTPSTATUS:%{http_code}")

GET_STATUS=$(echo $GET_USER | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
GET_BODY=$(echo $GET_USER | sed -e 's/HTTPSTATUS:.*//g')

echo "Get user response: $GET_BODY"
echo "Get user status: $GET_STATUS"

echo ""
echo "📍 8. Testing login with new password..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 9. Testing login with default password..."
DEFAULT_LOGIN=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"user":"admin","password":"admin"}' \
  -w "HTTPSTATUS:%{http_code}")

DEFAULT_STATUS=$(echo $DEFAULT_LOGIN | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
DEFAULT_BODY=$(echo $DEFAULT_LOGIN | sed -e 's/HTTPSTATUS:.*//g')

echo "Default login test response: $DEFAULT_BODY"
echo "Default login test status: $DEFAULT_STATUS"

echo ""
echo "📍 10. Stopping port forward..."
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
elif [ "$DEFAULT_STATUS" = "200" ]; then
    echo "🎯 SUCCESS! Grafana is using default password!"
    echo ""
    echo "📋 Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: admin"
    echo ""
    echo "⚠️  WARNING: Using default password! Change it after login."
else
    echo "❌ Neither new nor default password works."
    echo ""
    echo "📍 11. Let's check if Grafana is actually running..."
    kubectl get pods -n web -l app=grafana
    kubectl logs deployment/grafana -n web --tail=10
    echo ""
    echo "📍 12. Let's try accessing Grafana directly..."
    kubectl port-forward svc/grafana-service -n web 3000:3000 &
    PF_PID=$!
    sleep 5
    curl -s -I http://localhost:3000/
    kill $PF_PID
fi
