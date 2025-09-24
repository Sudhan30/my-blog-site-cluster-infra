#!/bin/bash

echo "🧪 Testing API with Browser Headers"
echo "=================================="

BASE_URL="https://blog.sudharsana.dev"

echo "📍 Testing with Browser User-Agent..."

# Test with browser headers
curl -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
     -H "Accept: application/json" \
     -H "Accept-Language: en-US,en;q=0.9" \
     "$BASE_URL/api/health" | jq '.status' 2>/dev/null || echo "Still blocked or jq not installed"

echo ""
echo "📍 Testing with curl but different approach..."

# Try with different headers
curl -H "Accept: application/json" \
     -H "X-Requested-With: XMLHttpRequest" \
     "$BASE_URL/api/health" | jq '.status' 2>/dev/null || echo "Still blocked"

echo ""
echo "📍 Testing posts endpoint..."
curl -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
     -H "Accept: application/json" \
     "$BASE_URL/api/posts" | jq '.posts | length' 2>/dev/null || echo "Posts endpoint blocked"

echo ""
echo "🎯 If all tests still show HTML challenges, you need to configure Cloudflare Page Rules."
echo "📖 See: cloudflare-page-rules.md for configuration instructions."
