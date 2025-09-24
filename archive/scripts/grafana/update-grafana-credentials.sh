#!/bin/bash

echo "🔐 Update Grafana Credentials"
echo "============================"

echo "📍 Current credentials:"
echo "Username: admin"
echo "Password: Grafana2025!Secure#Pass"
echo ""

echo "📍 To customize the credentials:"
echo "1. Edit the file: clusters/prod/apps/monitoring/grafana-secret.yaml"
echo "2. Change the admin-password value"
echo "3. Optionally change the admin-user value"
echo "4. Commit and push the changes"
echo ""

echo "📍 Example of a strong password:"
echo "admin-password: \"MySecure2025!Grafana#Pass\""
echo ""

echo "📍 After updating credentials:"
echo "1. Commit changes: git add . && git commit -m 'Update Grafana credentials'"
echo "2. Push changes: git push origin main"
echo "3. Wait for deployment (2-3 minutes)"
echo "4. Access Grafana with new credentials"
echo ""

echo "📍 Security recommendations:"
echo "✅ Use at least 12 characters"
echo "✅ Include uppercase, lowercase, numbers, and symbols"
echo "✅ Avoid common words or patterns"
echo "✅ Consider using a password manager"
echo ""

echo "📍 Example strong passwords:"
echo "• Grafana2025!Secure#Pass"
echo "• MyDashboard2025!@#Strong"
echo "• Monitoring2025!$ecure"
echo ""

echo "🎯 Ready to update? Edit grafana-secret.yaml and push the changes!"
