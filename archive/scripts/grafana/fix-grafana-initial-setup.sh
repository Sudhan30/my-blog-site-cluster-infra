#!/bin/bash

echo "🔧 Fixing Grafana - Initial Setup"
echo "================================="

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
echo "📍 3. Method 1: Try to access Grafana web interface to trigger initial setup..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 10

echo "Attempting to access Grafana web interface..."
WEB_ACCESS=$(curl -s -I http://localhost:3000/ -w "HTTPSTATUS:%{http_code}")
WEB_STATUS=$(echo $WEB_ACCESS | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
WEB_BODY=$(echo $WEB_ACCESS | sed -e 's/HTTPSTATUS:.*//g')

echo "Web access response: $WEB_BODY"
echo "Web access status: $WEB_STATUS"

echo ""
echo "📍 4. Method 2: Try to access login page..."
LOGIN_PAGE=$(curl -s -I http://localhost:3000/login -w "HTTPSTATUS:%{http_code}")
LOGIN_STATUS=$(echo $LOGIN_PAGE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_BODY=$(echo $LOGIN_PAGE | sed -e 's/HTTPSTATUS:.*//g')

echo "Login page response: $LOGIN_BODY"
echo "Login page status: $LOGIN_STATUS"

echo ""
echo "📍 5. Method 3: Try to access setup page..."
SETUP_PAGE=$(curl -s -I http://localhost:3000/setup -w "HTTPSTATUS:%{http_code}")
SETUP_STATUS=$(echo $SETUP_PAGE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
SETUP_BODY=$(echo $SETUP_PAGE | sed -e 's/HTTPSTATUS:.*//g')

echo "Setup page response: $SETUP_BODY"
echo "Setup page status: $SETUP_STATUS"

echo ""
echo "📍 6. Method 4: Try to access admin setup page..."
ADMIN_SETUP=$(curl -s -I http://localhost:3000/admin/setup -w "HTTPSTATUS:%{http_code}")
ADMIN_STATUS=$(echo $ADMIN_SETUP | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
ADMIN_BODY=$(echo $ADMIN_SETUP | sed -e 's/HTTPSTATUS:.*//g')

echo "Admin setup response: $ADMIN_BODY"
echo "Admin setup status: $ADMIN_STATUS"

echo ""
echo "📍 7. Method 5: Try to access the actual setup page content..."
SETUP_CONTENT=$(curl -s http://localhost:3000/setup -w "HTTPSTATUS:%{http_code}")
SETUP_CONTENT_STATUS=$(echo $SETUP_CONTENT | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
SETUP_CONTENT_BODY=$(echo $SETUP_CONTENT | sed -e 's/HTTPSTATUS:.*//g')

echo "Setup content status: $SETUP_CONTENT_STATUS"
if [ "$SETUP_CONTENT_STATUS" = "200" ]; then
    echo "Setup content found! Looking for setup form..."
    echo "$SETUP_CONTENT_BODY" | grep -i "setup\|admin\|password" | head -5
fi

echo ""
echo "📍 8. Method 6: Try to access the login page content..."
LOGIN_CONTENT=$(curl -s http://localhost:3000/login -w "HTTPSTATUS:%{http_code}")
LOGIN_CONTENT_STATUS=$(echo $LOGIN_CONTENT | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
LOGIN_CONTENT_BODY=$(echo $LOGIN_CONTENT | sed -e 's/HTTPSTATUS:.*//g')

echo "Login content status: $LOGIN_CONTENT_STATUS"
if [ "$LOGIN_CONTENT_STATUS" = "200" ]; then
    echo "Login content found! Looking for login form..."
    echo "$LOGIN_CONTENT_BODY" | grep -i "login\|admin\|password" | head -5
fi

echo ""
echo "📍 9. Stopping port forward..."
kill $PF_PID

echo ""
echo "📍 10. Let's check Grafana logs for initialization messages..."
kubectl logs deployment/grafana -n web | grep -i "admin\|setup\|initial\|user" | tail -10

echo ""
echo "📍 11. Let's check if there are any configuration files..."
kubectl exec deployment/grafana -n web -- ls -la /etc/grafana/ 2>/dev/null || echo "Cannot access /etc/grafana/"

echo ""
echo "📍 12. Let's check Grafana's configuration..."
kubectl exec deployment/grafana -n web -- cat /etc/grafana/grafana.ini 2>/dev/null | grep -i "admin\|security" | head -10 || echo "Cannot access grafana.ini"

echo ""
echo "🎯 Analysis Complete!"
echo "===================="
echo "Based on the responses above, we can determine:"
echo "1. If Grafana is accessible (status 200)"
echo "2. If there's a setup page available"
echo "3. If there's a login page available"
echo "4. What the actual configuration is"
echo ""
echo "Next steps will depend on what we find in the responses above."
