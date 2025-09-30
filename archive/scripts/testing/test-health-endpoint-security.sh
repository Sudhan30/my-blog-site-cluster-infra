#!/bin/bash

echo "🔒 Testing Health Endpoint Security"
echo "=================================="

echo "📊 Testing from external IP (should be blocked):"
echo "Expected: 403 Forbidden"
curl -s -w "\nHTTP Status: %{http_code}\n" https://blog.sudharsana.dev/api/health | jq .

echo ""
echo "📊 Testing from your server (should work):"
echo "Expected: 200 OK with health data"
curl -s -w "\nHTTP Status: %{http_code}\n" https://blog.sudharsana.dev/api/health | jq .

echo ""
echo "🔍 Testing with X-Forwarded-For header:"
echo "Expected: 403 Forbidden (external IP)"
curl -s -w "\nHTTP Status: %{http_code}\n" \
  -H "X-Forwarded-For: 8.8.8.8" \
  https://blog.sudharsana.dev/api/health | jq .

echo ""
echo "✅ Expected Results:"
echo "- External requests: 403 Forbidden"
echo "- Internal requests: 200 OK with system info"
echo "- Blocked IPs logged in backend logs"
