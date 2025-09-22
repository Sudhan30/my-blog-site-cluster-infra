#!/bin/bash

echo "🚀 Setting up PostgreSQL UI (Adminer)..."

# Create Adminer deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer
  namespace: web
  labels:
    app: adminer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: adminer
  template:
    metadata:
      labels:
        app: adminer
    spec:
      containers:
      - name: adminer
        image: adminer:latest
        ports:
        - containerPort: 8080
        env:
        - name: ADMINER_DEFAULT_SERVER
          value: "postgres-service"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: adminer-service
  namespace: web
  labels:
    app: adminer
spec:
  selector:
    app: adminer
  ports:
  - port: 8080
    targetPort: 8080
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: adminer-ingress
  namespace: web
  annotations:
    kubernetes.io/ingress.class: "traefik"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - adminer.sudharsana.dev
    secretName: adminer-tls
  rules:
  - host: adminer.sudharsana.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: adminer-service
            port:
              number: 8080
EOF

echo "✅ Adminer deployed successfully!"
echo ""
echo "🌐 Access Adminer at: https://adminer.sudharsana.dev"
echo ""
echo "📋 Database Connection Details:"
echo "   System: PostgreSQL"
echo "   Server: postgres-service"
echo "   Username: blog_user"
echo "   Password: blog_password"
echo "   Database: blog_db"
echo ""
echo "⏱️  Waiting for deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/adminer -n web

echo ""
echo "🔍 Check deployment status:"
kubectl get pods -n web -l app=adminer
echo ""
echo "📊 Check service status:"
kubectl get svc -n web -l app=adminer
echo ""
echo "🌐 Check ingress status:"
kubectl get ingress -n web -l app=adminer
