# 📊 Grafana Setup Guide

## 🎯 **Current Status**

Your Grafana is deployed but needs proper configuration for external access.

## 🔍 **Check Current Status**

Run these commands on your server to check Grafana:

```bash
# 1. Check if Grafana pod is running
kubectl get pods -n web -l app=grafana

# 2. Check Grafana service
kubectl get service grafana-service -n web

# 3. Check ingress configuration
kubectl get ingress monitoring-ingress -n web

# 4. Check Grafana logs
kubectl logs deployment/grafana -n web --tail=20
```

## 🔧 **Setup Steps**

### **Step 1: Fix Ingress Configuration**

The current ingress has an auth middleware that might be blocking access. Let's update it:

```bash
# Update the ingress to remove auth middleware
kubectl patch ingress monitoring-ingress -n web -p '{"metadata":{"annotations":{"traefik.ingress.kubernetes.io/router.middlewares":""}}}'
```

### **Step 2: Alternative - Create Simple Ingress**

If the patch doesn't work, create a new simple ingress:

```bash
# Create a simple Grafana ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-simple
  namespace: web
  annotations:
    traefik.ingress.kubernetes.io/router.tls.certresolver: le
spec:
  ingressClassName: traefik
  rules:
  - host: grafana.sudharsana.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana-service
            port:
              number: 3000
  tls:
  - hosts: [ "grafana.sudharsana.dev" ]
EOF
```

### **Step 3: Test Direct Access**

```bash
# Port forward to test Grafana directly
kubectl port-forward svc/grafana-service -n web 3000:3000

# Then access: http://localhost:3000
# Username: admin
# Password: admin123
```

## 🔐 **Default Credentials**

- **Username**: `admin`
- **Password**: `admin123`

## 📊 **Configure Data Sources**

Once you can access Grafana:

1. **Go to**: Configuration → Data Sources
2. **Add Prometheus**:
   - URL: `http://prometheus-service:9090`
   - Access: Server (default)
3. **Add PostgreSQL** (if needed):
   - Host: `postgres-service:5432`
   - Database: `blog_db`
   - User: `blog_user`
   - Password: `blog_password`

## 🎨 **Import Dashboards**

1. **Go to**: + → Import
2. **Import these dashboard IDs**:
   - `1860` - Node Exporter Full
   - `315` - Kubernetes Cluster Monitoring
   - `9628` - PostgreSQL Database

## 🧪 **Test Access**

After setup, test:

```bash
# Test Grafana access
curl -I https://grafana.sudharsana.dev

# Should return: HTTP/1.1 200 OK
```

## 🚨 **Troubleshooting**

### **If Grafana is not accessible:**

1. **Check pod status**:
   ```bash
   kubectl describe pod -l app=grafana -n web
   ```

2. **Check service**:
   ```bash
   kubectl describe service grafana-service -n web
   ```

3. **Check ingress**:
   ```bash
   kubectl describe ingress monitoring-ingress -n web
   ```

4. **Check logs**:
   ```bash
   kubectl logs deployment/grafana -n web --tail=50
   ```

### **If you get authentication errors:**

The ingress might have auth middleware. Try the simple ingress approach above.

## 🎯 **Expected Results**

- ✅ Grafana accessible at: `https://grafana.sudharsana.dev`
- ✅ Login with: `admin` / `admin123`
- ✅ Prometheus data source configured
- ✅ Dashboards imported and working
