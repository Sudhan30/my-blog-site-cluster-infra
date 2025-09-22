#!/bin/bash

# Script to update blog from external repository
# Usage: ./update-blog-from-repo.sh [branch]

set -e

BLOG_REPO="Sudhan30/my-blog-site-sudhanverse"
BLOG_BRANCH="${1:-main}"
TEMP_DIR="./temp-blog-source"
IMAGE_NAME="sudhan03/blog-site"
REGISTRY="docker.io"

echo "🚀 Updating blog from external repository..."
echo "📦 Repository: $BLOG_REPO"
echo "🌿 Branch: $BLOG_BRANCH"
echo ""

# Clean up any existing temp directory
if [ -d "$TEMP_DIR" ]; then
    echo "🧹 Cleaning up existing temp directory..."
    rm -rf "$TEMP_DIR"
fi

# Clone the blog repository
echo "📥 Cloning blog repository..."
git clone "https://github.com/$BLOG_REPO.git" "$TEMP_DIR"
cd "$TEMP_DIR"

# Checkout the specified branch
echo "🌿 Checking out branch: $BLOG_BRANCH"
git checkout "$BLOG_BRANCH"

# Get commit information
COMMIT_SHA=$(git rev-parse HEAD)
COMMIT_MESSAGE=$(git log -1 --pretty=%B)
COMMIT_DATE=$(git log -1 --pretty=%ci)

echo "📝 Latest commit: $COMMIT_SHA"
echo "💬 Message: $COMMIT_MESSAGE"
echo "📅 Date: $COMMIT_DATE"
echo ""

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t "$REGISTRY/$IMAGE_NAME:blog-$COMMIT_SHA" .
docker build -t "$REGISTRY/$IMAGE_NAME:latest" .

# Push to Docker Hub
echo "📤 Pushing to Docker Hub..."
docker push "$REGISTRY/$IMAGE_NAME:blog-$COMMIT_SHA"
docker push "$REGISTRY/$IMAGE_NAME:latest"

# Clean up temp directory
cd ..
rm -rf "$TEMP_DIR"

# Update deployment manifest
echo "📝 Updating deployment manifest..."
sed -i.bak "s|image: $REGISTRY/$IMAGE_NAME:.*|image: $REGISTRY/$IMAGE_NAME:blog-$COMMIT_SHA|g" clusters/prod/apps/blog/deployment.yaml

# Commit the changes
echo "💾 Committing changes..."
git add clusters/prod/apps/blog/deployment.yaml
git commit -m "🚀 Update blog image to blog-$COMMIT_SHA

- Built from: $BLOG_REPO@$BLOG_BRANCH
- Commit: $COMMIT_MESSAGE
- SHA: $COMMIT_SHA
- Date: $COMMIT_DATE"

echo ""
echo "✅ Blog update completed!"
echo "📦 New image: $REGISTRY/$IMAGE_NAME:blog-$COMMIT_SHA"
echo "📝 Source: $BLOG_REPO@$BLOG_BRANCH"
echo ""
echo "🔄 To deploy:"
echo "   1. git push origin main"
echo "   2. Flux CD will automatically deploy the new image"
echo ""
echo "🔍 Monitor deployment:"
echo "   kubectl get pods -n web"
echo "   kubectl rollout status deployment/blog -n web"
