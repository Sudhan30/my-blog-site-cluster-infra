#!/bin/bash

echo "🔐 Fixing Grafana Secret - Once and For All"
echo "==========================================="

echo "📍 1. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Generated password: $NEW_PASSWORD"

echo ""
echo "📍 2. Checking current secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 3. Deleting old secret..."
kubectl delete secret grafana-credentials -n web

echo ""
echo "📍 4. Creating new secret..."
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  -n web

echo ""
echo "📍 5. Verifying new secret..."
kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d
echo ""

echo "📍 6. Restarting Grafana..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 7. Waiting for deployment..."
kubectl rollout status deployment/grafana -n web --timeout=120s

echo ""
echo "📍 8. Checking environment variables..."
kubectl exec deployment/grafana -n web -- env | grep -E "(GF_SECURITY|ADMIN)" | sort

echo ""
echo "📍 9. Starting port forward..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 10

echo ""
echo "📍 10. Testing login..."
LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 11. Stopping port forward..."
kill $PF_PID 2>/dev/null || true

echo ""
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "🎯 SUCCESS! Grafana is working!"
    echo ""
    echo "📋 Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: $NEW_PASSWORD"
    echo ""
    echo "💾 Save this password securely!"
else
    echo "❌ Login test failed. Let's try browser access..."
    echo ""
    echo "📍 12. Starting port forward for browser access..."
    kubectl port-forward svc/grafana-service -n web 3000:3000 &
    PF_PID=$!
    sleep 5
    echo ""
    echo "🌐 Open your browser and go to: http://localhost:3000"
    echo "🔐 Try logging in with:"
    echo "   Username: admin"
    echo "   Password: $NEW_PASSWORD"
    echo ""
    echo "📝 If that doesn't work, try:"
    echo "   Username: admin"
    echo "   Password: admin"
    echo ""
    echo "📍 13. Port forward is running (PID: $PF_PID)"
    echo "   Press Ctrl+C to stop it when done"
fi
