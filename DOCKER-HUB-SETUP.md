# Docker Hub Setup Guide

This guide explains how to set up Docker Hub authentication for your CI/CD pipeline.

## Required GitHub Secrets

### 1. DOCKER_USERNAME
- **Value**: Your Docker Hub username (`sudhan03`)
- **Setup**: 
  1. Go to your GitHub repository → Settings → Secrets and variables → Actions
  2. Click "New repository secret"
  3. Name: `DOCKER_USERNAME`
  4. Value: `sudhan03`

### 2. DOCKER_PASSWORD
- **Value**: Your Docker Hub password or access token
- **Setup**:
  1. Go to your GitHub repository → Settings → Secrets and variables → Actions
  2. Click "New repository secret"
  3. Name: `DOCKER_PASSWORD`
  4. Value: Your Docker Hub password or access token

## Docker Hub Access Token (Recommended)

For better security, use a Docker Hub access token instead of your password:

### To create an access token:
1. Go to [Docker Hub](https://hub.docker.com/) → Account Settings
2. Click "Security" → "New Access Token"
3. Give it a name like "GitHub Actions"
4. Set permissions to "Read, Write, Delete"
5. Copy the token and use it as `DOCKER_PASSWORD`

## Image Pull Secrets Setup

Your deployments use `dockerhub-creds` for pulling images. Set this up on your cluster:

```bash
# Create the secret for pulling from Docker Hub
kubectl create secret docker-registry dockerhub-creds \
  --docker-server=docker.io \
  --docker-username=sudhan03 \
  --docker-password=YOUR_DOCKER_PASSWORD \
  --docker-email=YOUR_EMAIL \
  --namespace=web
```

## Verification

After setting up the secrets, verify they work:

```bash
# Check if the secret exists
kubectl get secrets -n web

# Test pulling an image
kubectl run test-pull --image=docker.io/sudhan03/blog-site:latest --rm -i --restart=Never --dry-run=client -o yaml
```

## Expected Image Registry

Your images will now be pushed to:
- **Blog**: `docker.io/sudhan03/blog-site:latest`
- **Backend**: `docker.io/sudhan03/blog-backend:latest`

## Troubleshooting

### If images fail to pull:
```bash
# Check pod events
kubectl describe pod <pod-name> -n web

# Check if secret exists
kubectl get secret dockerhub-creds -n web

# Check secret details
kubectl describe secret dockerhub-creds -n web
```

### If GitHub Actions fails to push:
1. Verify `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets are set
2. Check Docker Hub rate limits (free accounts have limits)
3. Ensure your Docker Hub account has push permissions

## Docker Hub Rate Limits

**Free accounts**: 100 pulls per 6 hours per IP
**Paid accounts**: No limits

If you hit rate limits, consider:
1. Upgrading to a paid Docker Hub plan
2. Using GitHub Container Registry instead
3. Implementing image caching strategies

## Summary

**To complete the setup:**
1. ✅ Set up `DOCKER_USERNAME` and `DOCKER_PASSWORD` GitHub secrets
2. ✅ Create `dockerhub-creds` secret on your cluster
3. ✅ Push code to trigger the CI/CD pipeline
4. ✅ Check Docker Hub to see your new images

**Your images will now be visible in Docker Hub at:**
- https://hub.docker.com/r/sudhan03/blog-site
- https://hub.docker.com/r/sudhan03/blog-backend
