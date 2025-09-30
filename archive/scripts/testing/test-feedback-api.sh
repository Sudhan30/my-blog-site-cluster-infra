#!/bin/bash

# Feedback API Testing Script
# Test the feedback submission endpoints

BASE_URL="https://blog.sudharsana.dev"
API_BASE="$BASE_URL/api"

echo "🧪 Testing Feedback Submission API"
echo "=================================="

# Generate a test UUID
TEST_UUID="550e8400-e29b-41d4-a716-446655440000"

# Test 1: Submit feedback with all fields
echo ""
echo "📝 Test 1: Submit feedback with all fields"
echo "------------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"name\": \"John Doe\",
    \"email\": \"john@example.com\",
    \"rating\": 5,
    \"feedback_text\": \"This is an excellent blog! I love the content and design. Keep up the great work!\"
  }" | jq .

# Test 2: Submit feedback without name (should generate random name)
echo ""
echo "📝 Test 2: Submit feedback without name (anonymous)"
echo "--------------------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"email\": \"anonymous@example.com\",
    \"rating\": 4,
    \"feedback_text\": \"Great content! Could use more images though.\"
  }" | jq .

# Test 3: Submit feedback without email
echo ""
echo "📝 Test 3: Submit feedback without email"
echo "----------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"name\": \"Jane Smith\",
    \"rating\": 3,
    \"feedback_text\": \"Good blog, but the navigation could be improved.\"
  }" | jq .

# Test 4: Submit feedback with invalid rating
echo ""
echo "📝 Test 4: Submit feedback with invalid rating"
echo "---------------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"name\": \"Test User\",
    \"rating\": 6,
    \"feedback_text\": \"This should fail due to invalid rating.\"
  }" | jq .

# Test 5: Submit feedback without required fields
echo ""
echo "📝 Test 5: Submit feedback without required fields"
echo "--------------------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"$TEST_UUID\",
    \"name\": \"Test User\"
  }" | jq .

# Test 6: Submit feedback with invalid UUID
echo ""
echo "📝 Test 6: Submit feedback with invalid UUID"
echo "-------------------------------------------"
curl -X POST "$API_BASE/feedback" \
  -H "Content-Type: application/json" \
  -d "{
    \"uuid\": \"invalid-uuid\",
    \"name\": \"Test User\",
    \"rating\": 5,
    \"feedback_text\": \"This should fail due to invalid UUID.\"
  }" | jq .

# Test 7: Test rate limiting (submit multiple feedbacks quickly)
echo ""
echo "📝 Test 7: Test rate limiting (submit multiple feedbacks)"
echo "----------------------------------------------------------"
for i in {1..12}; do
  echo "Submitting feedback $i..."
  curl -X POST "$API_BASE/feedback" \
    -H "Content-Type: application/json" \
    -d "{
      \"uuid\": \"$TEST_UUID\",
      \"name\": \"Rate Test User $i\",
      \"rating\": 4,
      \"feedback_text\": \"Rate limit test feedback $i\"
    }" | jq .success
  sleep 1
done

# Test 8: Get feedback statistics
echo ""
echo "📊 Test 8: Get feedback statistics"
echo "---------------------------------"
curl -X GET "$API_BASE/feedback/stats" | jq .

# Test 9: Get recent feedback
echo ""
echo "📊 Test 9: Get recent feedback"
echo "-----------------------------"
curl -X GET "$API_BASE/feedback/recent?limit=5" | jq .

# Test 10: Get pending feedback only
echo ""
echo "📊 Test 10: Get pending feedback only"
echo "-----------------------------------"
curl -X GET "$API_BASE/feedback/recent?status=pending&limit=3" | jq .

echo ""
echo "✅ Feedback API testing completed!"
echo "Check the responses above for proper functionality."
echo ""
echo "📋 Summary of tests:"
echo "- Submit feedback with all fields"
echo "- Submit anonymous feedback (no name)"
echo "- Submit feedback without email"
echo "- Test invalid rating validation"
echo "- Test missing required fields"
echo "- Test invalid UUID format"
echo "- Test rate limiting (10 per minute)"
echo "- Get feedback statistics"
echo "- Get recent feedback"
echo "- Filter feedback by status"
