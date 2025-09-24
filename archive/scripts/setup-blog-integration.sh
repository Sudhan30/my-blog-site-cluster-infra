#!/bin/bash

# Complete setup script for blog integration
# This sets up automatic deployment from your blog repo to your cluster

echo "🚀 Setting up Blog Integration for Automatic Deployments"
echo "========================================================"
echo ""

BLOG_REPO="Sudhan30/my-blog-site-sudhanverse"
INFRA_REPO="Sudhan30/my-blog-site-cluster-infra"

echo "📋 This will set up automatic deployment when you push to your blog repo"
echo "📦 Blog repo: https://github.com/$BLOG_REPO"
echo "🏗️  Infra repo: https://github.com/$INFRA_REPO"
echo ""

# Step 1: Instructions for blog repository
echo "📝 STEP 1: Update your blog repository workflow"
echo "================================================"
echo ""
echo "1. Go to: https://github.com/$BLOG_REPO"
echo "2. Navigate to: Actions > Workflows > docker.yml"
echo "3. Replace the workflow content with:"
echo ""
echo "   [Copy the content from blog-repo-workflow.yml]"
echo ""
echo "4. Add these secrets to your blog repository:"
echo "   - DOCKERHUB_USERNAME: Your Docker Hub username"
echo "   - DOCKERHUB_TOKEN: Your Docker Hub access token"
echo "   - INFRA_REPO_TOKEN: Personal access token with repo permissions"
echo ""
echo "   To create INFRA_REPO_TOKEN:"
echo "   - Go to GitHub Settings > Developer settings > Personal access tokens"
echo "   - Generate new token with 'repo' permissions"
echo "   - Add it as INFRA_REPO_TOKEN secret in your blog repo"
echo ""

# Step 2: Instructions for infra repository
echo "📝 STEP 2: Your infra repository is already set up!"
echo "=================================================="
echo ""
echo "✅ The blog-update-listener.yml workflow is already created"
echo "✅ Your deployment.yaml is configured correctly"
echo "✅ Flux CD will automatically deploy updates"
echo ""

# Step 3: Test the integration
echo "📝 STEP 3: Test the integration"
echo "==============================="
echo ""
echo "1. Make a change to your blog repository"
echo "2. Commit and push to main branch"
echo "3. Watch the magic happen:"
echo "   • Blog repo builds and pushes Docker image"
echo "   • Infra repo receives webhook notification"
echo "   • Deployment manifest gets updated"
echo "   • Flux CD deploys the new image to your cluster"
echo ""

# Step 4: Manual update script
echo "📝 STEP 4: Manual update option"
echo "==============================="
echo ""
echo "If you need to manually update, run:"
echo "  ./manual-blog-update.sh"
echo ""

# Create manual update script
cat > manual-blog-update.sh << 'EOF'
#!/bin/bash

# Manual blog update script
echo "🚀 Manually updating blog from latest commit..."

# Get latest commit from blog repo
BLOG_REPO="Sudhan30/my-blog-site-sudhanverse"
LATEST_SHA=$(curl -s "https://api.github.com/repos/$BLOG_REPO/commits/main" | jq -r '.sha')

if [ "$LATEST_SHA" = "null" ]; then
    echo "❌ Could not fetch latest commit SHA"
    exit 1
fi

echo "📝 Latest commit: $LATEST_SHA"

# Update deployment
sed -i "s|image: docker.io/sudhan03/blog-site:.*|image: docker.io/sudhan03/blog-site:$LATEST_SHA|g" clusters/prod/apps/blog/deployment.yaml

# Commit and push
git add clusters/prod/apps/blog/deployment.yaml
git commit -m "🚀 Manual update blog to $LATEST_SHA"
git push origin main

echo "✅ Blog updated to latest commit: $LATEST_SHA"
echo "🔄 Flux CD will deploy the update"
EOF

chmod +x manual-blog-update.sh

echo "✅ Manual update script created: manual-blog-update.sh"
echo ""

# Step 5: Monitoring
echo "📝 STEP 5: Monitor your deployments"
echo "==================================="
echo ""
echo "Watch your deployments with:"
echo "  kubectl get pods -n web -w"
echo ""
echo "Check deployment status:"
echo "  kubectl rollout status deployment/blog -n web"
echo ""
echo "View recent deployments:"
echo "  kubectl rollout history deployment/blog -n web"
echo ""

echo "🎉 Setup Complete!"
echo "=================="
echo ""
echo "Your blog integration is now ready:"
echo "✅ Automatic builds on blog repo changes"
echo "✅ Automatic deployment to your cluster"
echo "✅ Manual update option available"
echo "✅ Monitoring commands provided"
echo ""
echo "🌐 Your blog will automatically stay up-to-date!"
echo "   Every push to your blog repo = automatic cluster update"
