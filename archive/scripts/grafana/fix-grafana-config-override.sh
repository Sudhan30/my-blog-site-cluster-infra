#!/bin/bash

echo "🔧 Fixing Grafana - Config Override"
echo "==================================="

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
echo "📍 3. Method 1: Override Grafana configuration to force environment variables..."
kubectl patch deployment grafana -n web --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_SECURITY_ADMIN_USER",
      "value": "admin"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_SECURITY_ADMIN_PASSWORD",
      "value": "'$NEW_PASSWORD'"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_SECURITY_ADMIN_EMAIL",
      "value": "admin@localhost"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION",
      "value": "false"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_SECURITY_ALLOW_EMBEDDING",
      "value": "true"
    }
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "GF_USERS_ALLOW_SIGN_UP",
      "value": "false"
    }
  }
]'

echo ""
echo "📍 4. Restarting Grafana deployment..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 5. Waiting for deployment to be ready..."
kubectl rollout status deployment/grafana -n web --timeout=120s

echo ""
echo "📍 6. Checking pod environment variables..."
kubectl exec deployment/grafana -n web -- env | grep -E "(GF_SECURITY|ADMIN)" | sort

echo ""
echo "📍 7. Testing login with new password..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 10

LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$NEW_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 8. Testing login with default password..."
DEFAULT_LOGIN=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d '{"user":"admin","password":"admin"}' \
  -w "HTTPSTATUS:%{http_code}")

DEFAULT_STATUS=$(echo $DEFAULT_LOGIN | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
DEFAULT_BODY=$(echo $DEFAULT_LOGIN | sed -e 's/HTTPSTATUS:.*//g')

echo "Default login test response: $DEFAULT_BODY"
echo "Default login test status: $DEFAULT_STATUS"

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
    echo "📍 10. Let's check Grafana logs for more details..."
    kubectl logs deployment/grafana -n web --tail=20
    echo ""
    echo "📍 11. Let's check if there are any configuration overrides..."
    kubectl exec deployment/grafana -n web -- cat /etc/grafana/grafana.ini | grep -A 10 -B 5 "admin_user\|admin_password"
fi
