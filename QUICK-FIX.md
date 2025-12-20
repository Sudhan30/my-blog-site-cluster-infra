# 🚀 Quick Start - Fix SSL Certificate

## Copy-Paste Commands for Server

SSH into your server and run these commands:

### 1. Install cert-manager (2-3 minutes)
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml

kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-webhook -n cert-manager
kubectl wait --for=condition=Available --timeout=300s deployment/cert-manager-cainjector -n cert-manager
```

### 2. Create Let's Encrypt ClusterIssuer
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: sudhan0312@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

### 3. Pull Latest Changes (Flux will auto-apply)
```bash
# Changes are already pushed to GitHub
# Flux CD should auto-deploy within 1-5 minutes
# Check Flux status:
kubectl get kustomization -n flux-system
```

### 4. Wait and Verify Certificates (2-3 minutes after Flux applies)
```bash
# Check certificates
kubectl get certificates -n web

# Should show:
# NAME       READY   SECRET     AGE
# blog-tls   True    blog-tls   2m
```

### 5. Test Your Site
Visit: https://blog.sudharsana.dev

---

## Quick Troubleshooting

**If certificate isn't created after 5 minutes:**
```bash
kubectl logs -n cert-manager deployment/cert-manager --tail=50
kubectl describe certificate blog-tls -n web
```

**Force Flux to reconcile immediately:**
```bash
flux reconcile kustomization flux-system --with-source
```

---

## ✅ Success Criteria
- Site loads without Cloudflare Error 526
- Valid Let's Encrypt certificate
- HTTPS working properly
