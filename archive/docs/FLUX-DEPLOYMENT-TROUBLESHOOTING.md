# 🔧 Flux Deployment Troubleshooting Guide

## **Current Issue**: API endpoints returning 404 errors

### **Quick Diagnostic Commands**

Run these commands on your server to check deployment status:

```bash
# 1. Check if backend pod is running
kubectl get pods -n web -l app=blog-backend

# 2. Check all pods in web namespace
kubectl get pods -n web

# 3. Check backend service
kubectl get service blog-backend-service -n web

# 4. Check Flux kustomization status
kubectl get kustomization -n flux-system

# 5. Check backend logs
kubectl logs deployment/blog-backend -n web --tail=20

# 6. Check ingress configuration
kubectl get ingress blog -n web -o yaml
```

### **Step-by-Step Troubleshooting**

#### **Step 1: Check Backend Pod Status**
```bash
kubectl get pods -n web -l app=blog-backend
```
**Expected**: Pod should show `Running` status
**If not running**: Check logs with `kubectl logs deployment/blog-backend -n web`

#### **Step 2: Test Backend Directly**
```bash
# Port forward to backend
kubectl port-forward svc/blog-backend-service -n web 3001:3001

# In another terminal, test:
curl http://localhost:3001/health
curl http://localhost:3001/posts
```
**Expected**: JSON responses from backend
**If 404**: Backend code not updated yet

#### **Step 3: Check Flux Deployment Status**
```bash
kubectl get kustomization blog -n flux-system
kubectl get kustomization backend -n flux-system
```
**Expected**: Status should be `Ready`
**If not ready**: Check events with `kubectl describe kustomization backend -n flux-system`

#### **Step 4: Check Image Updates**
```bash
kubectl get imagerepository blog-backend -n flux-system
kubectl get imagepolicy blog-backend -n flux-system
```
**Expected**: Latest image should be pulled
**If not updated**: Flux Image Automation might not be working

#### **Step 5: Check Ingress Routing**
```bash
kubectl get ingress blog -n web -o yaml
```
**Expected**: `/api` path should route to `blog-backend-service:3001`

### **Common Issues and Solutions**

#### **Issue 1: Backend Pod Not Running**
```bash
# Check pod status
kubectl describe pod -l app=blog-backend -n web

# Check logs
kubectl logs -l app=blog-backend -n web --previous
```

#### **Issue 2: Flux Not Deploying**
```bash
# Check Flux system
kubectl get pods -n flux-system

# Check Git repository status
kubectl get gitrepository blog-repo -n flux-system

# Force reconciliation
kubectl annotate kustomization backend -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

#### **Issue 3: Image Not Updated**
```bash
# Check if new image was built
kubectl get imagerepository blog-backend -n flux-system -o yaml

# Check image policy
kubectl get imagepolicy blog-backend -n flux-system -o yaml

# Force image update
kubectl annotate imageupdateautomation blog-backend -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

#### **Issue 4: Ingress Not Working**
```bash
# Check ingress controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=traefik

# Check ingress events
kubectl describe ingress blog -n web
```

### **Quick Fixes**

#### **Force Redeploy Backend**
```bash
kubectl rollout restart deployment/blog-backend -n web
```

#### **Force Flux Reconciliation**
```bash
kubectl annotate kustomization backend -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

#### **Check Latest Commit**
```bash
git log --oneline -5
```
**Expected**: Latest commit should be "Fix API routing issue - backend now handles both /api/* and /* paths"

### **Expected Timeline**

- **Git push**: Immediate
- **GitHub Actions build**: 2-3 minutes
- **Flux image detection**: 1-2 minutes
- **Flux deployment**: 2-3 minutes
- **Pod restart**: 1-2 minutes
- **Total**: 6-10 minutes

### **Verification Commands**

Once deployment is complete, these should work:

```bash
# Test API endpoints
curl https://blog.sudharsana.dev/api/health
curl https://blog.sudharsana.dev/api/posts
curl https://blog.sudharsana.dev/api/posts/1/likes
```

**Expected responses**:
```json
{"status":"healthy","timestamp":"...","uptime":3600,"memory":{...}}
{"posts":[],"pagination":{"page":1,"limit":10,"total":0,"pages":0}}
{"postId":"1","likes":0,"cached":false}
```
