# 🚀 My Blog Site - Kubernetes Infrastructure

A production-ready Kubernetes infrastructure setup for a modern blog platform with monitoring and observability.

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────┐
│              Blog System                    │
│                                             │
│  ┌────────────┐         ┌────────────┐     │
│  │  Frontend  │         │  Backend   │     │
│  │  (Bun.js)  │    ←→   │  (Bun.js)  │     │
│  └────────────┘         └────────────┘     │
│         │                      │            │
│         └──────────┬───────────┘            │
│                    │                        │
│         ┌──────────▼──────────┐             │
│         │    PostgreSQL DB    │             │
│         └─────────────────────┘             │
│                                             │
└─────────────────────────────────────────────┘
                    │
       ┌────────────▼────────────┐
       │   Kubernetes Cluster    │
       │    (K3s + FluxCD)       │
       └─────────────────────────┘
```

## 📦 **Components**

### **Blog Application** (`blog`)
- **Technology**: Bun.js (TypeScript)
- **URL**: `https://blog.sudharsana.dev`
- **Features**: Posts, Comments, Feedback, RSS/Sitemap
- **Auto-scaling**: HPA enabled (2-10 pods)

### **Database** (`postgres`)
- **Technology**: PostgreSQL 15
- **Features**: Post storage, comments, user tracking
- **Persistence**: PVC-backed storage

### **Monitoring Stack**
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Dashboards and visualization
- **Exporters**: Postgres, Blackbox monitoring

## 🚀 **Quick Start**

### **1. Security Setup (Required)**
Before deploying, you must generate secure credentials for the database and API.

```bash
# Run the secret generation script
./create-secrets.sh
```
This will:
1. Generate a strong Database Password and JWT Secret
2. Create the `backend-secrets` Kubernetes Secret
3. Provide instructions for updating the PostgreSQL user password

### **2. Deploy to Kubernetes**
```bash
# Clone the repository
git clone https://github.com/Sudhan30/my-blog-site-cluster-infra.git
cd my-blog-site-cluster-infra

# Deploy with Flux CD
kubectl apply -k clusters/prod/
```

### **2. Access Your Blog**
- **Frontend**: https://blog.sudharsana.dev
- **API**: https://blog.sudharsana.dev/api/health
- **Grafana**: https://grafana.sudharsana.dev
- **Prometheus**: https://prometheus.sudharsana.dev

## 🔄 **CI/CD Pipeline**

### **Automatic Deployment**
1. **Push to main** → GitHub Actions builds Docker images
2. **Images pushed** → Docker Hub
3. **Flux detects** → New images automatically
4. **Flux deploys** → Updated pods in cluster

### **Image Automation**
- **Blog Application**: `docker.io/sudhan03/blog-site`
- **Ollama (AI)**: `ollama/ollama:rocm`

## 📊 **Monitoring & Observability**

### **Metrics Collection**
- **Prometheus**: System and application metrics
- **Grafana**: Dashboards and visualization
- **Postgres Exporter**: Database metrics
- **Blackbox Exporter**: Uptime monitoring

### **Health Checks**
```bash
# API Health
curl https://blog.sudharsana.dev/api/health

# Prometheus Metrics
curl https://prometheus.sudharsana.dev/metrics
```

## 🗄️ **Database Schema**

### **Posts Table**
```sql
CREATE TABLE posts (
  id          bigserial PRIMARY KEY,
  slug        text UNIQUE NOT NULL,
  title       text NOT NULL,
  content     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
```

### **Comments Table**
```sql
CREATE TABLE comments (
  id            bigserial PRIMARY KEY,
  post_id       bigint NOT NULL REFERENCES posts(id),
  display_name  text NOT NULL,
  content       text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  status        comment_status DEFAULT 'approved'
);
```

### **Likes Table**
```sql
CREATE TABLE likes (
  id          bigserial PRIMARY KEY,
  post_id     bigint NOT NULL REFERENCES posts(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  client_id   uuid,
  ip_hash     char(64)
);
```

## 🔧 **API Endpoints**

### **Posts**
- `GET /api/posts` - Get all posts
- `GET /api/posts/:slug` - Get single post
- `GET /api/posts/:id/likes` - Get post likes
- `POST /api/posts/:id/like` - Like a post

### **Comments**
- `GET /api/posts/:id/comments` - Get post comments
- `POST /api/posts/:id/comments` - Add comment

### **Analytics**
- `GET /api/analytics` - Get analytics data

### **Health**
- `GET /api/health` - Health check
- `GET /api/metrics` - Prometheus metrics

## 🏷️ **Kubernetes Resources**

### **Namespaces**
- `web` - Main application namespace
- `flux-system` - Flux CD components
- `monitoring` - Prometheus and Grafana

### **Key Resources**
- **Deployments**: `blog`, `postgres`, `prometheus`, `grafana`, `ollama`
- **Services**: `blog-service`, `postgres-service`, `prometheus-service`, `grafana-service`, `ollama-service`
- **Ingress**: `blog-ingress` (with TLS)
- **Secrets**: `blog-db-secret`, `grafana-secret`
- **PVC**: Data persistence (Postgres, Prometheus, Grafana, Ollama)

## 📁 **Repository Structure**

```
├── clusters/prod/           # Kubernetes manifests
│   ├── apps/
│   │   ├── blog/           # Blog application
│   │   ├── postgres/       # Database
│   │   ├── monitoring/     # Prometheus & Grafana
│   │   ├── ollama/         # AI service
│   │   └── gotify/         # Notification service
│   └── kustomization.yaml  # Main kustomization
├── .github/workflows/       # CI/CD workflows
└── README.md               # This file
```

## 🔐 **Security Features**

- **TLS/SSL**: Automatic Let's Encrypt certificates
- **Rate Limiting**: API request throttling
- **CORS**: Cross-origin resource sharing
- **Helmet**: Security headers
- **Anonymous Tracking**: Privacy-focused analytics

## 📈 **Scaling & Performance**

- **Horizontal Pod Autoscaler**: CPU/Memory based scaling
- **Redis Caching**: Like counts and session data
- **Connection Pooling**: Database optimization
- **Load Testing**: Comprehensive testing scripts

## 🆘 **Troubleshooting**

### **Check Deployment Status**
```bash
kubectl get pods -n web
kubectl get kustomization -n flux-system
kubectl logs deployment/blog-backend -n web
```

### **Test API Endpoints**
```bash
curl https://blog.sudharsana.dev/api/health
curl https://blog.sudharsana.dev/api/posts
```

## 📚 **Documentation**

- **Detailed docs**: See `archive/docs/` folder
- **API Documentation**: `archive/docs/API-DOCUMENTATION.md`
- **Deployment Guide**: `archive/docs/DEPLOYMENT-TESTING-GUIDE.md`
- **Troubleshooting**: `archive/docs/FLUX-DEPLOYMENT-TROUBLESHOOTING.md`

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License.

---

**🚀 Happy Blogging!** Your modern, scalable blog infrastructure is ready to go!
