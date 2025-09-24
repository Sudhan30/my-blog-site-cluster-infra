#!/bin/bash

echo "🌐 Accessing Grafana via Browser"
echo "==============================="

echo "📍 1. Getting current credentials..."
CURRENT_PASSWORD=$(kubectl get secret grafana-credentials -n web -o jsonpath='{.data.admin-password}' | base64 -d)
echo "Current password: $CURRENT_PASSWORD"

echo ""
echo "📍 2. Starting port forward for local access..."
kubectl port-forward svc/grafana-service -n web 3000:3000 &
PF_PID=$!
sleep 5

echo ""
echo "📍 3. Testing web interface access..."
WEB_TEST=$(curl -s -I http://localhost:3000/ -w "HTTPSTATUS:%{http_code}")
WEB_STATUS=$(echo $WEB_TEST | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')
echo "Web interface status: $WEB_STATUS"

if [ "$WEB_STATUS" = "200" ] || [ "$WEB_STATUS" = "302" ]; then
    echo ""
    echo "✅ Grafana web interface is accessible!"
    echo ""
    echo "📍 4. Manual access instructions..."
    echo "🌐 Open your web browser and go to:"
    echo "   http://localhost:3000"
    echo ""
    echo "🔐 Try logging in with these credentials:"
    echo "   Username: admin"
    echo "   Password: $CURRENT_PASSWORD"
    echo ""
    echo "📝 If that doesn't work, try the default:"
    echo "   Username: admin"
    echo "   Password: admin"
    echo ""
    echo "📍 5. Alternative: Access via Cloudflare..."
    echo "🌐 You can also try accessing via:"
    echo "   https://grafana.sudharsana.dev"
    echo ""
    echo "🔐 Use the same credentials as above"
    echo ""
    echo "📍 6. What to look for in the browser..."
    echo "   - If you see a login form, try the credentials above"
    echo "   - If you see an error, check the browser console (F12)"
    echo "   - If you see a setup page, follow the setup wizard"
    echo ""
    echo "📍 7. Keep port forward running..."
    echo "   The port forward is running in the background."
    echo "   Press Ctrl+C to stop it when you're done testing."
    echo ""
    echo "   Port forward PID: $PF_PID"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Open http://localhost:3000 in your browser"
    echo "   2. Try logging in with the credentials above"
    echo "   3. Let me know what you see!"
else
    echo "❌ Web interface not accessible. Status: $WEB_STATUS"
    kill $PF_PID 2>/dev/null || true
fi
