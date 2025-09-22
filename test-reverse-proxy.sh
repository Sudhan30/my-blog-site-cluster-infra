#!/bin/bash

echo "🧪 Testing Reverse Proxy Setup"
echo "================================"

BASE_URL="https://blog.sudharsana.dev"

echo "📍 Testing Frontend (should return HTML):"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$BASE_URL/"

echo ""
echo "📍 Testing API Health Check:"
curl -s "$BASE_URL/api/health" | jq '.status' 2>/dev/null || echo "API not responding or jq not installed"

echo ""
echo "📍 Testing API Posts Endpoint:"
curl -s "$BASE_URL/api/posts" | jq '.posts | length' 2>/dev/null || echo "Posts endpoint not responding"

echo ""
echo "📍 Testing API Metrics:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$BASE_URL/api/metrics"

echo ""
echo "🎯 Reverse Proxy Test Complete!"
echo ""
echo "Expected Results:"
echo "✅ Frontend: HTTP 200 (HTML content)"
echo "✅ API Health: 'healthy' status"
echo "✅ API Posts: Array of posts or empty array"
echo "✅ API Metrics: HTTP 200 (Prometheus metrics)"
echo ""
echo "If all tests pass, your reverse proxy is working correctly! 🚀"
