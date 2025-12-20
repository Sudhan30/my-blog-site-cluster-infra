#!/bin/bash
set -e

echo "========================================="
echo "SSL Certificate Fix for blog.sudharsana.dev"
echo "========================================="
echo ""

# Step 1: Install cert-manager
echo "Step 1: Installing cert-manager..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager

echo "✓ cert-manager installed successfully"
echo ""

# Step 2: Create ClusterIssuer for Let's Encrypt
echo "Step 2: Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: sudhan0312@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

echo "✓ ClusterIssuer created successfully"
echo ""

# Step 3: Verify ClusterIssuer
echo "Step 3: Verifying ClusterIssuer status..."
sleep 5
kubectl get clusterissuer letsencrypt-prod -o wide

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Certificates should be automatically created within 2-3 minutes"
echo "2. Check certificate status with: kubectl get certificates -n web"
echo "3. Check TLS secrets with: kubectl get secrets -n web | grep tls"
echo ""
echo "If certificates don't appear automatically, you may need to:"
echo "- Delete and recreate the ingresses, OR"
echo "- Manually create Certificate resources"
echo ""
