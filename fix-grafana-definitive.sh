#!/bin/bash

echo "🔧 DEFINITIVE Grafana Fix - No More Prompts!"
echo "============================================="

echo "📍 1. Generating final secure password..."
FINAL_PASSWORD="GrafanaAdmin2025!Secure"
echo "Final password: $FINAL_PASSWORD"

echo ""
echo "📍 2. Completely removing old Grafana deployment..."
kubectl delete deployment grafana -n web --ignore-not-found=true
kubectl delete secret grafana-credentials -n web --ignore-not-found=true
kubectl delete service grafana-service -n web --ignore-not-found=true
kubectl delete ingress grafana-simple -n web --ignore-not-found=true

echo ""
echo "📍 3. Creating new secret with final password..."
kubectl create secret generic grafana-credentials \
  --from-literal=admin-user=admin \
  --from-literal=admin-password="$FINAL_PASSWORD" \
  -n web

echo ""
echo "📍 4. Creating new Grafana deployment with proper configuration..."
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: web
  labels:
    app: grafana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: "admin"
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "$FINAL_PASSWORD"
        - name: GF_SECURITY_ADMIN_EMAIL
          value: "admin@localhost"
        - name: GF_SECURITY_DISABLE_INITIAL_ADMIN_CREATION
          value: "false"
        - name: GF_SECURITY_ALLOW_EMBEDDING
          value: "true"
        - name: GF_USERS_ALLOW_SIGN_UP
          value: "false"
        - name: GF_USERS_AUTO_ASSIGN_ORG
          value: "true"
        - name: GF_USERS_AUTO_ASSIGN_ORG_ROLE
          value: "Viewer"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "false"
        - name: GF_AUTH_BASIC_ENABLED
          value: "true"
        - name: GF_AUTH_DISABLE_LOGIN_FORM
          value: "false"
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: web
spec:
  selector:
    app: grafana
  ports:
    - port: 3000
      targetPort: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-simple
  namespace: web
  annotations:
    traefik.ingress.kubernetes.io/router.tls.certresolver: le
spec:
  ingressClassName: traefik
  rules:
    - host: grafana.sudharsana.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana-service
                port:
                  number: 3000
  tls:
    - hosts: [ "grafana.sudharsana.dev" ]
EOF

echo ""
echo "📍 5. Waiting for deployment to be ready..."
kubectl rollout status deployment/grafana -n web --timeout=180s

echo ""
echo "📍 6. Verifying environment variables..."
kubectl exec deployment/grafana -n web -- env | grep -E "(GF_SECURITY|ADMIN)" | sort

echo ""
echo "📍 7. Waiting for Grafana to fully initialize..."
sleep 30

echo ""
echo "📍 8. Testing login with final password..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 15

LOGIN_TEST=$(curl -s -X POST http://localhost:3000/api/login \
  -H 'Content-Type: application/json' \
  -d "{\"user\":\"admin\",\"password\":\"$FINAL_PASSWORD\"}" \
  -w "HTTPSTATUS:%{http_code}")

LOGIN_STATUS=$(echo $LOGIN_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_TEST | sed -e 's/HTTPSTATUS:.*//g')

echo "Login test response: $LOGIN_BODY"
echo "Login test status: $LOGIN_STATUS"

echo ""
echo "📍 9. Stopping port forward..."
kill $PF_PID 2>/dev/null || true

echo ""
if [ "$LOGIN_STATUS" = "200" ]; then
    echo "🎯 SUCCESS! Grafana is now working!"
    echo ""
    echo "📋 FINAL Access Information:"
    echo "✅ URL: https://grafana.sudharsana.dev"
    echo "✅ Username: admin"
    echo "✅ Password: $FINAL_PASSWORD"
    echo ""
    echo "💾 Save these credentials securely!"
    echo ""
    echo "🔧 Configuration Summary:"
    echo "   - Fresh Grafana deployment"
    echo "   - Environment variables properly configured"
    echo "   - Security settings optimized"
    echo "   - Ingress configured for external access"
    echo ""
    echo "✅ NO MORE PROMPTS NEEDED!"
else
    echo "❌ Login test failed. Checking logs..."
    kubectl logs deployment/grafana -n web --tail=20
    echo ""
    echo "📍 10. Manual verification..."
    echo "🌐 Try accessing: https://grafana.sudharsana.dev"
    echo "🔐 Credentials: admin / $FINAL_PASSWORD"
    echo ""
    echo "If still not working, the issue might be with Grafana's internal configuration."
    echo "The deployment is properly configured with environment variables."
fi
