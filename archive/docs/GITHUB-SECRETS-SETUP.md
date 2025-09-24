# GitHub Secrets Setup Guide

This guide explains how to set up the necessary GitHub Secrets for your CI/CD pipeline to work properly.

## Required Secrets

### 1. GITHUB_TOKEN (Automatic)
- **Status**: ✅ Automatically provided by GitHub Actions
- **Purpose**: Used for pushing/pulling from GitHub Container Registry
- **Action**: No setup required - GitHub provides this automatically

### 2. KUBE_CONFIG (Optional - for direct cluster access)
- **Status**: ⚠️ Only needed if you want GitHub Actions to directly access your cluster
- **Purpose**: Allows GitHub Actions to run kubectl commands against your cluster
- **Setup**: 
  1. Get your kubeconfig: `cat ~/.kube/config | base64 -w 0`
  2. Go to your GitHub repository → Settings → Secrets and variables → Actions
  3. Click "New repository secret"
  4. Name: `KUBE_CONFIG`
  5. Value: The base64 encoded kubeconfig content

## Current Setup (Recommended)

Your current setup uses **Flux Image Automation** which is the recommended GitOps approach:

### How it works:
1. **GitHub Actions** builds and pushes Docker images to GHCR
2. **Flux Image Automation** detects new images automatically
3. **Flux CD** applies changes to your cluster
4. **No direct cluster access needed** from GitHub Actions

### Benefits:
- ✅ **More secure** - No need to expose cluster credentials
- ✅ **True GitOps** - All changes go through Git
- ✅ **Better audit trail** - All changes are tracked in Git history
- ✅ **Easier to manage** - No need to manage GitHub secrets

## Image Pull Secrets Setup

Your deployments use `ghcr-creds` for pulling images. Set this up on your cluster:

```bash
# Create the secret for pulling from GHCR
kubectl create secret docker-registry ghcr-creds \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --docker-email=YOUR_EMAIL \
  --namespace=web
```

### To get your GitHub token:
1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name like "GHCR Access"
4. Select scopes: `read:packages`, `write:packages`
5. Copy the token and use it in the command above

## Verification

After setting up the image pull secret, verify it works:

```bash
# Check if the secret exists
kubectl get secrets -n web

# Test pulling an image
kubectl run test-pull --image=ghcr.io/sudhan30/my-blog-site-cluster-infra/blog-site:latest --rm -i --restart=Never --dry-run=client -o yaml
```

## Troubleshooting

### If images fail to pull:
```bash
# Check pod events
kubectl describe pod <pod-name> -n web

# Check if secret exists
kubectl get secret ghcr-creds -n web

# Check secret details
kubectl describe secret ghcr-creds -n web
```

### If Flux Image Automation isn't working:
```bash
# Check ImageRepository status
kubectl get imagerepository -n flux-system

# Check ImagePolicy status  
kubectl get imagepolicy -n flux-system

# Check ImageUpdateAutomation status
kubectl get imageupdateautomation -n flux-system

# Check Flux logs
kubectl logs -n flux-system -l app=flux
```

## Summary

**For your current setup, you only need to:**
1. ✅ Set up the `ghcr-creds` secret on your cluster (for image pulling)
2. ✅ Ensure Flux is running and monitoring your repository
3. ✅ Push code to trigger the CI/CD pipeline

**No GitHub Secrets needed** for the basic workflow - Flux handles everything automatically!
