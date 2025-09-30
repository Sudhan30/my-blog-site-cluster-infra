#!/bin/bash

# Analytics API Testing Script
# Test the analytics tracking endpoints

BASE_URL="https://blog.sudharsana.dev"
API_BASE="$BASE_URL/api"

echo "🧪 Testing Analytics Tracking API"
echo "================================="

# Generate test UUIDs
TEST_UUID="550e8400-e29b-41d4-a716-446655440000"
TEST_SESSION="550e8400-e29b-41d4-a716-446655440001"

# Test 1: Start user session
echo ""
echo "🚀 Test 1: Start user session"
echo "-----------------------------"
curl -X POST "$API_BASE/analytics/session" \
  -H "Content-Type: application/json" \
  -d "{
    \"session_id\": \"$TEST_SESSION\",
    \"uuid\": \"$TEST_UUID\",
    \"entry_page\": \"https://blog.sudharsana.dev/\",
    \"referrer\": \"https://google.com\",
    \"device_type\": \"desktop\",
    \"browser\": \"Chrome\",
    \"os\": \"macOS\",
    \"country\": \"US\",
    \"city\": \"San Francisco\"
  }" | jq .

# Test 2: Track page view
echo ""
echo "📄 Test 2: Track page view"
echo "-------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"pageview\",
    \"page_url\": \"https://blog.sudharsana.dev/\",
    \"page_title\": \"Blog Homepage\",
    \"viewport_width\": 1920,
    \"viewport_height\": 1080,
    \"metadata\": {
      \"user_agent\": \"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)\",
      \"language\": \"en-US\"
    }
  }" | jq .

# Test 3: Track click event
echo ""
echo "🖱️ Test 3: Track click event"
echo "---------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"click\",
    \"page_url\": \"https://blog.sudharsana.dev/\",
    \"page_title\": \"Blog Homepage\",
    \"element_id\": \"subscribe-button\",
    \"element_class\": \"btn btn-primary\",
    \"element_text\": \"Subscribe to Newsletter\",
    \"element_type\": \"button\",
    \"click_x\": 500,
    \"click_y\": 300,
    \"viewport_width\": 1920,
    \"viewport_height\": 1080,
    \"metadata\": {
      \"href\": null,
      \"alt\": null
    }
  }" | jq .

# Test 4: Track scroll event
echo ""
echo "📜 Test 4: Track scroll event"
echo "-----------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"scroll\",
    \"page_url\": \"https://blog.sudharsana.dev/\",
    \"page_title\": \"Blog Homepage\",
    \"scroll_depth\": 75,
    \"viewport_width\": 1920,
    \"viewport_height\": 1080
  }" | jq .

# Test 5: Track time on page
echo ""
echo "⏱️ Test 5: Track time on page"
echo "-----------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"time_on_page\",
    \"page_url\": \"https://blog.sudharsana.dev/\",
    \"page_title\": \"Blog Homepage\",
    \"time_on_page\": 120,
    \"viewport_width\": 1920,
    \"viewport_height\": 1080
  }" | jq .

# Test 6: Track custom event
echo ""
echo "🎯 Test 6: Track custom event"
echo "-----------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"custom\",
    \"event_name\": \"newsletter_signup\",
    \"page_url\": \"https://blog.sudharsana.dev/\",
    \"page_title\": \"Blog Homepage\",
    \"metadata\": {
      \"source\": \"header_banner\",
      \"email_provided\": true
    }
  }" | jq .

# Test 7: End user session
echo ""
echo "🏁 Test 7: End user session"
echo "---------------------------"
curl -X POST "$API_BASE/analytics/session/end" \
  -H "Content-Type: application/json" \
  -d "{
    \"session_id\": \"$TEST_SESSION\",
    \"exit_page\": \"https://blog.sudharsana.dev/about\",
    \"total_time\": 180,
    \"page_views\": 3,
    \"clicks\": 5,
    \"scroll_depth\": 85
  }" | jq .

# Test 8: Get analytics dashboard
echo ""
echo "📊 Test 8: Get analytics dashboard"
echo "---------------------------------"
curl -X GET "$API_BASE/analytics/dashboard?days=7" | jq .

# Test 9: Test invalid UUID
echo ""
echo "❌ Test 9: Test invalid UUID"
echo "----------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"invalid-uuid\",
    \"session_id\": \"$TEST_SESSION\",
    \"event_type\": \"pageview\",
    \"page_url\": \"https://blog.sudharsana.dev/\"
  }" | jq .

# Test 10: Test missing required fields
echo ""
echo "❌ Test 10: Test missing required fields"
echo "----------------------------------------"
curl -X POST "$API_BASE/analytics/track" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"event_type\": \"pageview\"
  }" | jq .

echo ""
echo "✅ Analytics API testing completed!"
echo "Check the responses above for proper functionality."
echo ""
echo "📋 Summary of tests:"
echo "- Start user session"
echo "- Track page view"
echo "- Track click event"
echo "- Track scroll event"
echo "- Track time on page"
echo "- Track custom event"
echo "- End user session"
echo "- Get analytics dashboard"
echo "- Test validation (invalid UUID)"
echo "- Test validation (missing fields)"
echo ""
echo "📈 Next steps:"
echo "1. Add blog-analytics.js to your frontend"
echo "2. Analytics will automatically track user behavior"
echo "3. View analytics in Grafana dashboard"
echo "4. Use /api/analytics/dashboard for custom analytics UI"
