# Quick Fix Steps for ACME 403 Error

## Problem Found!
The nginx config was blocking ALL hidden files including `.well-known`, which prevented Let's Encrypt from validating your domain.

## Solution Applied
Updated the nginx configuration to:
1. Allow `.well-known/acme-challenge/` path
2. Still block other hidden files for security

## Steps to Fix (Run on your server)

### 1. Pull the latest changes
```bash
cd ~/my-blog-site-cluster-infra
git pull origin main
```

### 2. Apply the updated nginx config
```bash
kubectl apply -f clusters/prod/apps/blog/configmap.yaml
```

### 3. Restart the blog pods to pick up the new config
```bash
kubectl rollout restart deployment/blog -n web
kubectl rollout status deployment/blog -n web
```

### 4. Delete the old failed challenge
```bash
# Delete the existing challenge to force a retry
kubectl delete challenge --all -n web

# Delete the certificate to trigger recreate
kubectl delete certificate blog-tls -n web
```

### 5. Wait for new certificate to be issued (2-3 minutes)
```bash
# Watch the certificate status
watch kubectl get certificates -n web

# Or check challengesstatus
kubectl get challenges -n web
```

### 6. Verify success
```bash
# Certificate should show READY=True
kubectl get certificate blog-tls -n web

# Test the site
curl -I https://blog.sudharsana.dev
```

---

## What Changed?

**Before:**
```nginx
# Deny access to hidden files
location ~ /\. {
    deny all;
}
```

**After:**
```nginx
# Allow ACME challenge for Let's Encrypt
location ~ /.well-known/acme-challenge/ {
    allow all;
    default_type text/plain;
}

# Deny access to other hidden files
location ~ /\.(?!well-known) {
    deny all;
}
```

---

## Expected Timeline
- Pull + apply config: 30 seconds
- Pod restart: 1 minute
- New challenge validation: 1-2 minutes
- **Total: ~3-5 minutes**
