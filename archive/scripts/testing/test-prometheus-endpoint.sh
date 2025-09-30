#!/bin/bash

echo "🧪 Testing Prometheus Analytics Endpoint"
echo "========================================"

# Test the new Prometheus endpoint
echo "📊 Testing POST /api/analytics/prometheus..."

curl -X POST https://blog.sudharsana.dev/api/analytics/prometheus \
  -H "Content-Type: application/json" \
  -d '{
    "metrics": [
      {
        "name": "blog_page_views_total",
        "type": "counter",
        "value": 1,
        "help": "Total number of page views",
        "labels": {
          "page": "/",
          "browser": "chrome",
          "device": "desktop"
        },
        "uuid": "550e8400-e29b-41d4-a716-446655440000",
        "session_id": "test-session-123",
        "page_url": "/"
      },
      {
        "name": "blog_clicks_total",
        "type": "counter", 
        "value": 1,
        "help": "Total number of clicks",
        "labels": {
          "element": "button",
          "page": "/"
        },
        "uuid": "550e8400-e29b-41d4-a716-446655440000",
        "session_id": "test-session-123",
        "page_url": "/"
      }
    ],
    "job": "blog-frontend",
    "instance": "web-browser"
  }' | jq .

echo ""
echo "✅ Test completed!"
echo ""
echo "🎯 Expected Results:"
echo "- HTTP 200 OK response"
echo "- Success message with metrics count"
echo "- Metrics forwarded to Prometheus Pushgateway"
echo "- Metrics stored in database as backup"
