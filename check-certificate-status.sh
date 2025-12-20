#!/bin/bash
# Certificate Verification Script

echo "========================================="
echo "Checking SSL Certificate Status"
echo "========================================="
echo ""

echo "1. Certificate Status:"
kubectl get certificates -n web
echo ""

echo "2. Certificate Details:"
kubectl describe certificate blog-tls -n web | tail -20
echo ""

echo "3. Certificate Request:"
kubectl get certificaterequest -n web
echo ""

echo "4. ACME Challenges (if any):"
kubectl get challenges -n web
if [ $? -eq 0 ]; then
    kubectl describe challenge -n web | grep -A 10 "State:"
fi
echo ""

echo "5. TLS Secrets:"
kubectl get secrets -n web | grep tls
echo ""

echo "6. Recent cert-manager logs:"
kubectl logs -n cert-manager deployment/cert-manager --tail=20 | grep -i "blog-tls\|error\|certificate"
echo ""

echo "========================================="
echo "Validation Check"
echo "========================================="

# Check if certificate is ready
CERT_READY=$(kubectl get certificate blog-tls -n web -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

if [ "$CERT_READY" == "True" ]; then
    echo "✅ Certificate is READY!"
    echo ""
    echo "Testing HTTPS connection..."
    curl -I https://blog.sudharsana.dev 2>&1 | head -5
else
    echo "⏳ Certificate is still being issued..."
    echo "   This typically takes 1-3 minutes."
    echo ""
    echo "   Run this script again in 1 minute to check progress."
fi

echo ""
echo "========================================="
