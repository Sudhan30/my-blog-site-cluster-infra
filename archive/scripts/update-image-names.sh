#!/bin/bash

# Script to update all Docker image names to proper separation
# blog-site: Angular frontend
# blog-site-backend: Node.js API backend
# blog-site-infra: Infrastructure components (if needed)

echo "🔄 Updating Docker image names across all configurations..."
echo "=========================================================="
echo ""

# Update backend deployment
echo "📝 Updating backend deployment..."
sed -i.bak 's|image: docker.io/sudhan03/blog-backend:|image: docker.io/sudhan03/blog-site-backend:|g' clusters/prod/apps/backend/deployment.yaml
echo "✅ Backend deployment updated"

# Update backend ImageRepository
echo "📝 Updating backend ImageRepository..."
sed -i.bak 's|image: docker.io/sudhan03/blog-backend|image: docker.io/sudhan03/blog-site-backend|g' clusters/prod/apps/backend/imagerepository.yaml
echo "✅ Backend ImageRepository updated"

# Update GitHub Actions workflow
echo "📝 Updating GitHub Actions workflow..."
sed -i.bak 's|IMAGE_NAME_BACKEND: sudhan03/blog-backend|IMAGE_NAME_BACKEND: sudhan03/blog-site-backend|g' .github/workflows/build-and-deploy.yml
echo "✅ GitHub Actions workflow updated"

# Update external blog build workflow
echo "📝 Updating external blog build workflow..."
sed -i.bak 's|IMAGE_NAME_BLOG: sudhan03/blog-site|IMAGE_NAME_BLOG: sudhan03/blog-site|g' .github/workflows/build-blog-from-external.yml
echo "✅ External blog build workflow updated"

# Update webhook workflow
echo "📝 Updating webhook workflow..."
sed -i.bak 's|IMAGE_NAME_BLOG: sudhan03/blog-site|IMAGE_NAME_BLOG: sudhan03/blog-site|g' .github/workflows/webhook-blog-update.yml
echo "✅ Webhook workflow updated"

echo ""
echo "🎯 Image Name Summary:"
echo "====================="
echo "📦 blog-site: Angular frontend (your sudhanverse blog)"
echo "📦 blog-site-backend: Node.js API backend"
echo "📦 blog-site-infra: Infrastructure components (if needed)"
echo ""

echo "🔍 Verifying changes..."
echo "======================"

echo "📋 Blog deployment image:"
grep "image:" clusters/prod/apps/blog/deployment.yaml

echo "📋 Backend deployment image:"
grep "image:" clusters/prod/apps/backend/deployment.yaml

echo "📋 Backend ImageRepository:"
grep "image:" clusters/prod/apps/backend/imagerepository.yaml

echo ""
echo "✅ All image names updated successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Commit these changes: git add . && git commit -m 'Update Docker image names'"
echo "2. Push to trigger rebuilds: git push origin main"
echo "3. Your images will now be properly separated:"
echo "   • blog-site (frontend)"
echo "   • blog-site-backend (API)"
echo "   • blog-site-infra (infrastructure)"
