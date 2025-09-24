#!/bin/bash

echo "🔐 Final Grafana Secret Fix"
echo "==========================="

echo "📍 1. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Generated password: $NEW_PASSWORD"

echo ""
echo "📍 2. Checking current secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 3. Deleting old secret completely..."
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

echo "📍 6. Restarting Grafana deployment..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 7. Waiting for deployment to be ready..."
kubectl rollout status deployment/grafana -n web --timeout=120s

echo ""
echo "📍 8. Checking pod environment variables..."
kubectl exec deployment/grafana -n web -- env | grep -E "(GF_SECURITY|ADMIN)" | sort

echo ""
echo "📍 9. Testing login..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 15

LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 10. Testing login with default password..."
DEFAULT_LOGIN=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"user":"admin","password":"admin"}' \
  -w "HTTPSTATUS:%{http_code}")

DEFAULT_STATUS=$(echo $DEFAULT_LOGIN | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
DEFAULT_BODY=$(echo $DEFAULT_LOGIN | sed -e 's/HTTPSTATUS:.*//g')

echo "Default login test response: $DEFAULT_BODY"
echo "Default login test status: $DEFAULT_STATUS"

echo ""
echo "📍 11. Stopping port forward..."
kill $PF_PID 2>/dev/null || true

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
    echo "❌ Login tests failed."
    echo ""
    echo "📍 12. Let's check Grafana logs..."
    kubectl logs deployment/grafana -n web --tail=10
    echo ""
    echo "📍 13. Manual access instructions..."
    echo "Try accessing: https://grafana.sudharsana.dev"
    echo "If you can access it via browser, try logging in with:"
    echo "  Username: admin"
    echo "  Password: $NEW_PASSWORD"
    echo ""
    echo "If that doesn't work, try:"
    echo "  Username: admin"
    echo "  Password: admin"
fi
