#!/bin/bash

echo "🔍 Troubleshooting Grafana Login Issue"
echo "======================================"

echo "📍 1. Checking Grafana pod logs for errors..."
kubectl logs deployment/grafana -n web --tail=20

echo ""
echo "📍 2. Checking if Grafana is reading the environment variables..."
kubectl exec -it deployment/grafana -n web -- env | grep GF_SECURITY

echo ""
echo "📍 3. Checking Grafana configuration..."
kubectl exec -it deployment/grafana -n web -- cat /etc/grafana/grafana.ini | grep -A5 -B5 "admin"

echo ""
echo "📍 4. Testing Grafana health endpoint..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 3
curl -s http://localhost:3000/api/health | jq '.' 2>/dev/null || echo "Health endpoint not accessible"
kill $PF_PID

echo ""
echo "📍 5. Alternative: Reset Grafana admin password via API..."
echo "This will reset the admin password to match the secret:"

# Get the current password from secret
SECRET_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Secret password: $SECRET_PASSWORD"

echo ""
echo "📍 6. Manual reset command (run this if needed):"
echo "kubectl port-forward svc/grafana-service -n web 3000:3000"
echo "Then in another terminal:"
echo "curl -X PUT http://admin:admin@localhost:3000/api/admin/users/admin/password \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"password\":\"$SECRET_PASSWORD\"}'"

echo ""
echo "📍 7. Check if Grafana is using persistent storage..."
kubectl get pvc grafana-pvc -n web

echo ""
echo "🎯 Troubleshooting Complete!"
echo "If Grafana is using persistent storage, the old password might be stored in the database."
echo "Try the manual reset command above, or delete the PVC to start fresh."
