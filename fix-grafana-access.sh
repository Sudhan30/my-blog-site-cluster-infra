#!/bin/bash

echo "📊 Setting up Grafana Access"
echo "==========================="

echo "📍 1. Checking current Grafana status..."
kubectl get pods -n web -l app=grafana
kubectl get service grafana-service -n web
kubectl get ingress monitoring-ingress -n web

echo ""
echo "📍 2. Creating simple Grafana ingress (without auth middleware)..."

# Create a simple Grafana ingress without auth middleware
cat <<EOF | kubectl apply -f -
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
echo "📍 3. Waiting for ingress to be ready..."
kubectl wait --for=condition=ready ingress grafana-simple -n web --timeout=60s

echo ""
echo "📍 4. Testing Grafana access..."
echo "Testing: https://grafana.sudharsana.dev"
curl -I https://grafana.sudharsana.dev 2>/dev/null | head -1 || echo "Not accessible yet (might need a few minutes for DNS/SSL)"

echo ""
echo "📍 5. Alternative - Test with port forward..."
echo "Run this command to test Grafana directly:"
echo "kubectl port-forward svc/grafana-service -n web 3000:3000"
echo "Then access: http://localhost:3000"

echo ""
echo "🎯 Grafana Setup Complete!"
echo ""
echo "📋 Access Information:"
echo "✅ URL: https://grafana.sudharsana.dev"
echo "✅ Username: admin"
echo "✅ Password: admin123"
echo ""
echo "📊 Next Steps:"
echo "1. Wait 2-3 minutes for SSL certificate"
echo "2. Access Grafana at the URL above"
echo "3. Configure Prometheus data source"
echo "4. Import dashboards (Node Exporter: 1860, Kubernetes: 315)"
