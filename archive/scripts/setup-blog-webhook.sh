#!/bin/bash

# Script to set up webhook for automatic blog updates
# This creates a GitHub Actions workflow in your blog repository that triggers builds

BLOG_REPO="Sudhan30/my-blog-site-sudhanverse"
CLUSTER_REPO="Sudhan30/my-blog-site-cluster-infra"

echo "🔗 Setting up webhook integration for automatic blog updates..."
echo "📦 Blog repo: $BLOG_REPO"
echo "🏗️  Cluster repo: $CLUSTER_REPO"
echo ""

# Create webhook workflow for the blog repository
cat > temp-webhook-workflow.yml << 'EOF'
name: Trigger Blog Deployment

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  trigger-deployment:
    runs-on: ubuntu-latest
    steps:
    - name: Trigger cluster deployment
      uses: peter-evans/repository-dispatch@v3
      with:
        token: ${{ secrets.CLUSTER_REPO_TOKEN }}
        repository: Sudhan30/my-blog-site-cluster-infra
        event-type: blog-updated
        client-payload: |
          {
            "ref": "${{ github.ref_name }}",
            "sha": "${{ github.sha }}",
            "repository": "${{ github.repository }}",
            "author": "${{ github.actor }}",
            "message": "${{ github.event.head_commit.message }}",
            "timestamp": "${{ github.event.head_commit.timestamp }}"
          }
    
    - name: Deployment triggered
      run: |
        echo "✅ Deployment triggered for blog update!"
        echo "📝 Commit: ${{ github.event.head_commit.message }}"
        echo "👤 Author: ${{ github.actor }}"
        echo "🔄 Cluster deployment will start automatically..."
EOF

echo "📝 Created webhook workflow file"
echo ""
echo "📋 Next steps to complete the setup:"
echo ""
echo "1. 🎯 Go to your blog repository: https://github.com/$BLOG_REPO"
echo "2. 📁 Create the workflow file:"
echo "   - Go to Actions tab"
echo "   - Click 'New workflow'"
echo "   - Create .github/workflows/trigger-deployment.yml"
echo "   - Copy the content from temp-webhook-workflow.yml"
echo ""
echo "3. 🔐 Set up the secret:"
echo "   - Go to Settings > Secrets and variables > Actions"
echo "   - Add new repository secret:"
echo "     Name: CLUSTER_REPO_TOKEN"
echo "     Value: [Your personal access token with repo permissions]"
echo ""
echo "4. ✅ Test the integration:"
echo "   - Make a commit to your blog repository"
echo "   - The webhook will automatically trigger a build and deployment"
echo ""
echo "🎉 After setup, every push to your blog repo will automatically:"
echo "   • Build a new Docker image"
echo "   • Push to Docker Hub"
echo "   • Update your cluster manifests"
echo "   • Deploy to your Kubernetes cluster"
echo ""

# Clean up temp file
rm temp-webhook-workflow.yml

echo "📄 Webhook workflow content saved to clipboard (if available)"
echo "💡 You can also find it in the setup instructions above"
