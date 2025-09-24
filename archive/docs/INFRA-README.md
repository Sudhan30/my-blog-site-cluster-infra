# 🏗️ Blog Infrastructure Stack

This document describes the **`blog-site-infra`** image that contains all the infrastructure components for your blog.

## 🐳 **What's Included:**

### **Core Services:**
- **Nginx** - Web server and reverse proxy
- **PostgreSQL** - Database for likes, comments, and user data
- **Redis** - Caching and session storage
- **Prometheus** - Metrics collection and monitoring
- **Grafana** - Dashboards and visualization
- **Postgres Exporter** - Database metrics for Prometheus
- **Blackbox Exporter** - HTTP uptime monitoring

### **Management:**
- **Supervisor** - Process management for all services
- **Health Checks** - Automated service monitoring
- **Log Management** - Centralized logging for all services

## 🚀 **How It Works:**

### **Single Container Architecture:**
Instead of running separate containers for each service, everything runs in one container managed by Supervisor:

```yaml
# One container, multiple services
blog-infra:
  - Nginx (port 80)
  - PostgreSQL (port 5432)
  - Redis (port 6379)
  - Prometheus (port 9090)
  - Grafana (port 3000)
  - Postgres Exporter (port 9114)
  - Blackbox Exporter (port 9115)
```

### **Service Management:**
- **Supervisor** manages all processes
- **Health checks** monitor service status
- **Automatic restarts** if services fail
- **Centralized logging** for troubleshooting

## 🔧 **Configuration:**

### **Environment Variables:**
```yaml
POSTGRES_DB: "blog_db"
POSTGRES_USER: "blog_user"
POSTGRES_PASSWORD: "blog_password"
REDIS_PASSWORD: ""
GRAFANA_ADMIN_PASSWORD: "admin123"
```

### **Ports:**
- **80** - Nginx (main web server)
- **3001** - API backend (if included)
- **5432** - PostgreSQL database
- **6379** - Redis cache
- **9090** - Prometheus metrics
- **3000** - Grafana dashboards
- **9114** - Postgres Exporter
- **9115** - Blackbox Exporter

## 📊 **Monitoring & Metrics:**

### **Prometheus Metrics:**
- **System metrics** - CPU, memory, disk usage
- **Database metrics** - PostgreSQL performance
- **Application metrics** - Custom business metrics
- **Uptime monitoring** - HTTP endpoint health

### **Grafana Dashboards:**
- **System Overview** - Server resource usage
- **Database Performance** - PostgreSQL metrics
- **Application Metrics** - Blog performance
- **Uptime Monitoring** - Service availability

## 🔄 **Deployment:**

### **Kubernetes:**
```bash
# Deploy the infrastructure stack
kubectl apply -k clusters/prod/apps/infra

# Check deployment status
kubectl get pods -n web -l app=blog-infra

# View logs
kubectl logs -n web -l app=blog-infra -f
```

### **Docker Compose:**
```bash
# Run locally for development
docker-compose up -d blog-infra
```

## 🌐 **Access Points:**

### **Production URLs:**
- **Blog**: https://blog.sudharsana.dev
- **API**: https://api.sudharsana.dev
- **Grafana**: https://grafana.sudharsana.dev
- **Prometheus**: https://prometheus.sudharsana.dev

### **Local Development:**
- **Blog**: http://localhost:80
- **API**: http://localhost:3001
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

## 🔍 **Health Monitoring:**

### **Health Check Endpoint:**
```bash
# Check overall health
curl http://localhost/health

# Expected response: "healthy"
```

### **Service Status:**
```bash
# Check individual services
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3000/api/health # Grafana
```

## 📝 **Logs:**

### **View Logs:**
```bash
# All services
kubectl logs -n web -l app=blog-infra

# Specific service
kubectl logs -n web -l app=blog-infra -c blog-infra
```

### **Log Locations:**
- **Nginx**: `/var/log/nginx/`
- **PostgreSQL**: `/var/log/postgresql/`
- **Supervisor**: `/var/log/supervisor/`
- **Application**: `/var/log/app/`

## 🛠️ **Troubleshooting:**

### **Common Issues:**

1. **Services not starting:**
   ```bash
   # Check supervisor status
   kubectl exec -n web -l app=blog-infra -- supervisorctl status
   ```

2. **Database connection issues:**
   ```bash
   # Check PostgreSQL logs
   kubectl logs -n web -l app=blog-infra | grep postgres
   ```

3. **Memory issues:**
   ```bash
   # Check resource usage
   kubectl top pods -n web -l app=blog-infra
   ```

## 🔄 **Updates:**

### **Automatic Updates:**
- **Flux Image Automation** updates the image automatically
- **Rolling updates** ensure zero downtime
- **Health checks** verify successful deployments

### **Manual Updates:**
```bash
# Trigger update
kubectl rollout restart deployment/blog-infra -n web

# Check update status
kubectl rollout status deployment/blog-infra -n web
```

## 📈 **Scaling:**

### **Horizontal Scaling:**
```bash
# Scale up infrastructure
kubectl scale deployment/blog-infra -n web --replicas=3

# Check scaling status
kubectl get pods -n web -l app=blog-infra
```

### **Resource Limits:**
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## 🎯 **Benefits:**

### **Simplified Management:**
- **Single container** to manage
- **Centralized configuration**
- **Unified logging**
- **Simplified deployment**

### **Cost Effective:**
- **Fewer containers** = lower resource usage
- **Shared resources** = better efficiency
- **Simplified networking** = less complexity

### **Easy Troubleshooting:**
- **All services** in one place
- **Centralized logs**
- **Unified health checks**
- **Single point of monitoring**

## 🚀 **Next Steps:**

1. **Deploy the infrastructure** to your cluster
2. **Configure monitoring** dashboards
3. **Set up alerts** for critical metrics
4. **Monitor performance** and optimize
5. **Scale as needed** based on usage

Your infrastructure stack is now ready to handle your blog's backend needs! 🎉
