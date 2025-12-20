#!/bin/bash
# Diagnostic script for ACME challenge 403 issue

echo "========================================="
echo "ACME Challenge Diagnostics"
echo "========================================="
echo ""

echo "1. All Ingresses in web namespace:"
kubectl get ingress -n web -o wide
echo ""

echo "2. Challenge Ingress Details (if exists):"
kubectl get ingress -n web -o yaml | grep -A 30 "cm-acme-http-solver" || echo "No ACME solver ingress found"
echo ""

echo "3. Challenge Status:"
kubectl describe challenge -n web | grep -A 5 "Reason:"
echo ""

echo "4. Testing challenge URL directly:"
CHALLENGE_PATH=$(kubectl get challenge -n web -o jsonpath='{.items[0].spec.token}' 2>/dev/null)
if [ -n "$CHALLENGE_PATH" ]; then
    echo "Challenge token: $CHALLENGE_PATH"
    echo "Testing: http://blog.sudharsana.dev/.well-known/acme-challenge/$CHALLENGE_PATH"
    curl -v "http://blog.sudharsana.dev/.well-known/acme-challenge/$CHALLENGE_PATH" 2>&1 | head -20
else
    echo "No active challenge found"
fi
echo ""

echo "5. Testing generic challenge path:"
curl -I "http://blog.sudharsana.dev/.well-known/acme-challenge/test" 2>&1 | head -10
echo ""

echo "6. Blog ingress details:"
kubectl describe ingress blog -n web | grep -A 20 "Rules:"
echo ""

echo "7. Recent cert-manager logs:"
kubectl logs -n cert-manager deployment/cert-manager --tail=30 | grep -i "403\|error\|challenge\|blog"
echo ""

echo "========================================="
echo "End of Diagnostics"
echo "========================================="
