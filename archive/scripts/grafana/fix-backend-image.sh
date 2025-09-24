#!/bin/bash

echo "🔧 Fixing Backend Image Issue"
echo "============================="

echo "📍 1. Current backend image (WRONG):"
kubectl get pods -n web -l app=blog-backend -o jsonpath='{.items[0].spec.containers[0].image}'
echo ""

echo "📍 2. Expected image (CORRECT):"
echo "docker.io/sudhan03/blog-site-backend:latest"
echo ""

echo "📍 3. Checking Flux ImageRepository..."
kubectl get imagerepository blog-backend -n flux-system -o yaml | grep -A5 -B5 "image:"

echo ""
echo "📍 4. Checking if new image exists in Docker Hub..."
echo "The new image should be: docker.io/sudhan03/blog-site-backend:latest"
echo ""

echo "📍 5. Fixing the deployment image..."
echo "Updating deployment to use correct image..."

# Update the deployment to use the correct image
kubectl patch deployment blog-backend -n web -p '{"spec":{"template":{"spec":{"containers":[{"name":"blog-backend","image":"docker.io/sudhan03/blog-site-backend:latest"}]}}}}'

echo ""
echo "📍 6. Checking if pods are updating..."
kubectl get pods -n web -l app=blog-backend

echo ""
echo "📍 7. Wait for rollout to complete..."
kubectl rollout status deployment/blog-backend -n web

echo ""
echo "📍 8. Test the fixed backend..."
echo "Run: kubectl port-forward svc/blog-backend-service -n web 3001:3001"
echo "Then test: curl http://localhost:3001/posts"

echo ""
echo "🎯 Expected Results:"
echo "✅ New pods should be created with correct image"
echo "✅ Backend should respond to /posts endpoint"
echo "✅ API should work: curl https://blog.sudharsana.dev/api/posts"
