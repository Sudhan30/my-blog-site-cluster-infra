# 🧪 Deployment Testing Guide

This guide shows you how to test if your backend stack components have been deployed successfully.

## 🚀 **Quick Testing Methods:**

### **1. Quick Deployment Check:**
```bash
# Check if components are deployed
./quick-deployment-test.sh check

# Show quick status
./quick-deployment-test.sh status

# Test basic connectivity
./quick-deployment-test.sh test

# Show deployment commands
./quick-deployment-test.sh commands
```

### **2. Comprehensive Status Check:**
```bash
# Run complete deployment check
./check-deployment-status.sh check

# Check specific components
./check-deployment-status.sh deployments
./check-deployment-status.sh pods
./check-deployment-status.sh services
./check-deployment-status.sh ingress
./check-deployment-status.sh flux
```

### **3. API Testing:**
```bash
# Test backend API functionality
./test-backend-api.sh test

# Test specific endpoints
./test-backend-api.sh health
./test-backend-api.sh likes
./test-backend-api.sh comments
./test-backend-api.sh analytics
```

## 🔍 **Manual Testing Methods:**

### **1. Check Kubernetes Resources:**

#### **Check Namespace:**
```bash
kubectl get namespace web
```

#### **Check Pods:**
```bash
# All pods
kubectl get pods -n web

# Specific components
kubectl get pods -n web -l app=blog
kubectl get pods -n web -l app=blog-backend
kubectl get pods -n web -l app=postgres
kubectl get pods -n web -l app=prometheus
kubectl get pods -n web -l app=grafana
```

#### **Check Deployments:**
```bash
kubectl get deployments -n web
kubectl get deployments -n web -o wide
```

#### **Check Services:**
```bash
kubectl get svc -n web
kubectl get svc -n web -o wide
```

#### **Check Ingress:**
```bash
kubectl get ingress -n web
kubectl describe ingress -n web
```

#### **Check PVCs:**
```bash
kubectl get pvc -n web
kubectl get pvc -n web -o wide
```

### **2. Check Pod Status:**

#### **Detailed Pod Information:**
```bash
# Check pod status
kubectl get pods -n web -o wide

# Check pod logs
kubectl logs -n web -l app=blog-backend
kubectl logs -n web -l app=postgres
kubectl logs -n web -l app=prometheus
kubectl logs -n web -l app=grafana

# Check pod events
kubectl describe pods -n web
```

#### **Check Resource Usage:**
```bash
# Check pod resource usage
kubectl top pods -n web

# Check node resource usage
kubectl top nodes
```

### **3. Check Flux Sync Status:**

#### **Flux Kustomizations:**
```bash
# Check Flux sync status
flux get kustomizations -n flux-system

# Check specific kustomization
flux get kustomization blog -n flux-system

# Check Flux logs
flux logs -n flux-system
```

#### **Force Flux Sync:**
```bash
# Force reconciliation
flux reconcile kustomization blog -n flux-system
flux reconcile source git blog-repo -n flux-system
```

### **4. Test API Endpoints:**

#### **Health Endpoints:**
```bash
# Test backend health
curl -s https://api.sudharsana.dev/health

# Test backend readiness
curl -s https://api.sudharsana.dev/ready

# Test metrics endpoint
curl -s https://api.sudharsana.dev/metrics
```

#### **API Functionality:**
```bash
# Test likes endpoint
curl -s https://api.sudharsana.dev/api/posts/test-post/likes

# Test comments endpoint
curl -s https://api.sudharsana.dev/api/posts/test-post/comments

# Test analytics endpoint
curl -s https://api.sudharsana.dev/api/analytics
```

#### **Monitoring Endpoints:**
```bash
# Test Grafana
curl -s -I https://grafana.sudharsana.dev

# Test Prometheus
curl -s -I https://prometheus.sudharsana.dev

# Test blog site
curl -s -I https://blog.sudharsana.dev
```

## 🎯 **What to Look For:**

### **✅ Successful Deployment:**

#### **Pods Status:**
- All pods should be in `Running` state
- No pods in `Pending`, `Error`, or `CrashLoopBackOff`
- Ready replicas should match desired replicas

#### **Services Status:**
- All services should have `ClusterIP` or `LoadBalancer` type
- Endpoints should be populated
- No services in `Pending` state

#### **Ingress Status:**
- Ingress should have `ADDRESS` populated
- TLS certificates should be ready
- No ingress in `Pending` state

#### **API Responses:**
- Health endpoints return `200 OK`
- API endpoints return expected JSON responses
- Metrics endpoint returns Prometheus format

### **❌ Common Issues:**

#### **Pods Not Ready:**
```bash
# Check pod logs
kubectl logs -n web <pod-name>

# Check pod events
kubectl describe pod -n web <pod-name>

# Check resource limits
kubectl describe pod -n web <pod-name>
```

#### **Services Not Working:**
```bash
# Check service endpoints
kubectl get endpoints -n web

# Check service selector
kubectl describe svc -n web <service-name>
```

#### **Ingress Issues:**
```bash
# Check ingress controller
kubectl get pods -n kube-system -l app=traefik

# Check ingress events
kubectl describe ingress -n web <ingress-name>
```

#### **Database Issues:**
```bash
# Check PostgreSQL logs
kubectl logs -n web -l app=postgres

# Test database connection
kubectl exec -it -n web deployment/postgres -- psql -U blog_user -d blog_db -c "SELECT 1;"
```

## 🚨 **Troubleshooting Steps:**

### **1. Check Prerequisites:**
```bash
# Check kubectl
kubectl version --client
kubectl cluster-info

# Check Flux
flux version
flux get kustomizations -n flux-system
```

### **2. Check Namespace:**
```bash
# Create namespace if missing
kubectl create namespace web

# Check namespace
kubectl get namespace web
```

### **3. Check Resource Availability:**
```bash
# Check node resources
kubectl describe nodes

# Check available storage
kubectl get storageclass
kubectl get pv
```

### **4. Check Network:**
```bash
# Check DNS
kubectl exec -it -n web deployment/blog-backend -- nslookup postgres-service

# Check connectivity
kubectl exec -it -n web deployment/blog-backend -- curl postgres-service:5432
```

### **5. Check Configuration:**
```bash
# Check ConfigMaps
kubectl get configmap -n web

# Check Secrets
kubectl get secrets -n web

# Check environment variables
kubectl exec -it -n web deployment/blog-backend -- env
```

## 📊 **Expected Results:**

### **Pods:**
```
NAME                            READY   STATUS    RESTARTS   AGE
blog-85455d748-l98v7            1/1     Running   0          5m
blog-85455d748-ljwj2            1/1     Running   0          5m
blog-backend-7d8f9c4b5-abc123   1/1     Running   0          4m
postgres-6f8e9d2a1-def456       1/1     Running   0          4m
prometheus-5c7d8e9f0-ghi789     1/1     Running   0          3m
grafana-4b6c7d8e9-jkl012       1/1     Running   0          3m
```

### **Services:**
```
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
blog-service            ClusterIP   10.43.123.45    <none>        80/TCP     5m
blog-backend-service    ClusterIP   10.43.123.46    <none>        3001/TCP   4m
postgres-service        ClusterIP   10.43.123.47    <none>        5432/TCP   4m
prometheus-service      ClusterIP   10.43.123.48    <none>        9090/TCP   3m
grafana-service         ClusterIP   10.43.123.49    <none>        3000/TCP   3m
```

### **Ingress:**
```
NAME                    CLASS    HOSTS                           ADDRESS        PORTS     AGE
blog-ingress           traefik   blog.sudharsana.dev            192.168.1.100  80,443    5m
blog-backend-ingress   traefik   api.sudharsana.dev             192.168.1.100  80,443    4m
monitoring-ingress     traefik   grafana.sudharsana.dev,        192.168.1.100  80,443    3m
                                prometheus.sudharsana.dev
```

### **API Responses:**
```bash
# Health endpoint
curl https://api.sudharsana.dev/health
{"status":"healthy","timestamp":"2025-01-21T16:14:24.000Z","uptime":300.123,"memory":{"rss":45678912,"heapTotal":25165824,"heapUsed":18350080,"external":1234567}}

# Likes endpoint
curl https://api.sudharsana.dev/api/posts/test-post/likes
{"postId":"test-post","likes":0,"cached":false}

# Comments endpoint
curl https://api.sudharsana.dev/api/posts/test-post/comments
{"postId":"test-post","comments":[],"pagination":{"page":1,"limit":10,"total":0,"pages":0}}
```

## 🎉 **Success Criteria:**

Your deployment is successful if:

✅ **All pods are running** and ready  
✅ **All services are active** with endpoints  
✅ **Ingress is configured** and accessible  
✅ **API endpoints respond** correctly  
✅ **Database is accessible** and initialized  
✅ **Monitoring is working** (Prometheus/Grafana)  
✅ **Flux is synced** (if using GitOps)  
✅ **TLS certificates** are issued  
✅ **Health checks pass**  

## 🚀 **Next Steps After Successful Deployment:**

1. **Test the API** with real data
2. **Configure Grafana dashboards** 
3. **Set up monitoring alerts**
4. **Integrate with your blog frontend**
5. **Test under load**
6. **Set up backups**

---

**🎯 Use this guide to verify your deployment is working correctly!**

*The testing scripts will help you quickly identify any issues and ensure your backend stack is running smoothly.*
