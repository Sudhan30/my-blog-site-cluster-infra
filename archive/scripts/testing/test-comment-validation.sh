#!/bin/bash

echo "🛡️ Testing Enhanced Comment Validation"
echo "======================================"

# Test 1: Valid comment
echo "✅ Test 1: Valid Comment"
curl -X POST https://blog.sudharsana.dev/api/posts/post-001/comments \
  -H "Content-Type: application/json" \
  -d '{
    "content": "This is a great post! Very informative and well written.",
    "displayName": "John Doe"
  }' | jq .

echo ""
echo "❌ Test 2: Too Short Comment"
curl -X POST https://blog.sudharsana.dev/api/posts/post-001/comments \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Nice!",
    "displayName": "Jane"
  }' | jq .

echo ""
echo "❌ Test 3: Spam Content"
curl -X POST https://blog.sudharsana.dev/api/posts/post-001/comments \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Click here to make money fast! Free money guaranteed!",
    "displayName": "Spammer"
  }' | jq .

echo ""
echo "❌ Test 4: HTML/Script Injection"
curl -X POST https://blog.sudharsana.dev/api/posts/post-001/comments \
  -H "Content-Type: application/json" \
  -d '{
    "content": "Great post! <script>alert(\"hack\")</script>",
    "displayName": "Hacker"
  }' | jq .

echo ""
echo "❌ Test 5: Excessive Repetition"
curl -X POST https://blog.sudharsana.dev/api/posts/post-001/comments \
  -H "Content-Type: application/json" \
  -d '{
    "content": "spam spam spam spam spam spam spam spam spam spam",
    "displayName": "Repeater"
  }' | jq .

echo ""
echo "✅ Expected Results:"
echo "- Valid comment: 201 Created"
echo "- Invalid comments: 400 Bad Request with specific error messages"
echo "- HTML tags stripped from valid comments"
echo "- Spam keywords blocked"
echo "- Rate limiting prevents rapid posting"
