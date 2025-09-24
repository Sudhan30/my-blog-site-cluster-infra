#!/bin/bash

echo "🔐 Testing Grafana Login"
echo "======================="

echo "📍 1. Getting current password from secret..."
CURRENT_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret password: $CURRENT_PASSWORD"

echo ""
echo "📍 2. Starting port forward to Grafana..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!

echo "📍 3. Waiting for port forward to be ready..."
sleep 15

echo ""
echo "📍 4. Testing login with current password..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$CURRENT_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 5. Testing login with default password..."
DEFAULT_LOGIN=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"user":"admin","password":"admin"}' \
  -w "HTTPSTATUS:%{http_code}")

DEFAULT_STATUS=$(echo $DEFAULT_LOGIN | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
DEFAULT_BODY=$(echo $DEFAULT_LOGIN | sed -e 's/HTTPSTATUS:.*//g')

echo "Default login test response: $DEFAULT_BODY"
echo "Default login test status: $DEFAULT_STATUS"

echo ""
echo "📍 6. Testing basic connectivity..."
HEALTH_CHECK=$(curl -s -I http://localhost:3000/ -w "HTTPSTATUS:%{http_code}")
HEALTH_STATUS=$(echo $HEALTH_CHECK | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
echo "Health check status: $HEALTH_STATUS"

echo ""
echo "📍 7. Stopping port forward..."
kill $PF_PID 2>/dev/null || true

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
    echo "❌ Login tests failed."
    echo ""
    echo "📍 8. Let's check if Grafana is accessible via web interface..."
    echo "Try accessing: https://grafana.sudharsana.dev"
    echo "If you can access it via browser, try logging in with:"
    echo "  Username: admin"
    echo "  Password: $CURRENT_PASSWORD"
    echo ""
    echo "If that doesn't work, try:"
    echo "  Username: admin"
    echo "  Password: admin"
fi
