#!/bin/bash

# Newsletter API Testing Script
# Test the newsletter subscription endpoints

BASE_URL="https://blog.sudharsana.dev"
API_BASE="$BASE_URL/api"

echo "🧪 Testing Newsletter Subscription API"
echo "======================================"

# Test 1: Subscribe to newsletter
echo ""
echo "📧 Test 1: Subscribe to newsletter"
echo "--------------------------------"
curl -X POST "$API_BASE/newsletter/subscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .

# Test 2: Try to subscribe again (should show already subscribed)
echo ""
echo "📧 Test 2: Try to subscribe again (duplicate prevention)"
echo "--------------------------------------------------------"
curl -X POST "$API_BASE/newsletter/subscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .

# Test 3: Check subscription status
echo ""
echo "📧 Test 3: Check subscription status"
echo "-----------------------------------"
curl -X GET "$API_BASE/newsletter/status?email=test@example.com" | jq .

# Test 4: Subscribe with invalid email
echo ""
echo "📧 Test 4: Subscribe with invalid email"
echo "---------------------------------------"
curl -X POST "$API_BASE/newsletter/subscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"invalid-email"}' | jq .

# Test 5: Unsubscribe
echo ""
echo "📧 Test 5: Unsubscribe from newsletter"
echo "-------------------------------------"
curl -X POST "$API_BASE/newsletter/unsubscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .

# Test 6: Check status after unsubscribe
echo ""
echo "📧 Test 6: Check status after unsubscribe"
echo "---------------------------------------"
curl -X GET "$API_BASE/newsletter/status?email=test@example.com" | jq .

# Test 7: Try to unsubscribe again
echo ""
echo "📧 Test 7: Try to unsubscribe again"
echo "----------------------------------"
curl -X POST "$API_BASE/newsletter/unsubscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .

# Test 8: Resubscribe
echo ""
echo "📧 Test 8: Resubscribe to newsletter"
echo "-----------------------------------"
curl -X POST "$API_BASE/newsletter/subscribe" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}' | jq .

echo ""
echo "✅ Newsletter API testing completed!"
echo "Check the responses above for proper functionality."
