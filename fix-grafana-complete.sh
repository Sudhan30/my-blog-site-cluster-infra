#!/bin/bash

echo "🔧 Complete Grafana Fix - Remove Persistent Storage"
echo "=================================================="

echo "📍 1. Checking current Grafana deployment..."
kubectl get deployment grafana -n web -o yaml | grep -A 10 -B 5 persistentVolumeClaim

echo ""
echo "📍 2. Removing persistent storage from Grafana deployment..."
kubectl patch deployment grafana -n web --type='json' -p='[
  {
    "op": "remove",
    "path": "/spec/template/spec/containers/0/volumeMounts"
  },
  {
    "op": "remove", 
    "path": "/spec/template/spec/volumes"
  }
]'

echo ""
echo "📍 3. Generating a new secure password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
echo "Generated password: $NEW_PASSWORD"

echo ""
echo "📍 4. Updating Grafana secret..."
kubectl delete secret grafana-credentials -n web 2>/dev/null || true
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$NEW_PASSWORD" \
  -n web

echo ""
echo "📍 5. Restarting Grafana deployment..."
kubectl rollout restart deployment/grafana -n web

echo ""
echo "📍 6. Waiting for deployment to be ready..."
kubectl rollout status deployment/grafana -n web --timeout=120s

echo ""
echo "📍 7. Testing login..."
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
echo "📍 8. Stopping port forward..."
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
    echo ""
    echo "📝 Note: Grafana is now running without persistent storage."
    echo "   This means data won't persist across pod restarts."
    echo "   For production, you may want to add persistent storage back."
else
    echo "❌ Still not working. Checking pod status and logs..."
    kubectl get pods -n web -l app=grafana
    kubectl logs deployment/grafana -n web --tail=10
fi
