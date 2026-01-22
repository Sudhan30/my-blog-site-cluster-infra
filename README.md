# 🚀 My Blog Site - Kubernetes Infrastructure

A complete Kubernetes infrastructure setup hosting two primary applications:
1. **Modern Blog Site**: Angular frontend + Node.js backend
2. **Algorithmic Trading System**: High-frequency trading platform with microservices architecture

## 🏗️ **Architecture**

```
┌─────────────────────────────────┐   ┌────────────────────────────────────────────────────────┐
│           Blog System           │   │                    Trading System                      │
│                                 │   │                                                        │
│  ┌────────────┐ ┌────────────┐  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
│  │  Frontend  │ │  Backend   │  │   │  │ Data        │  │ Strategy    │  │ Order       │ │
│  │ (Angular)  │ │ (Node.js)  │  │   │  │ Ingestion   │→ │ Engine      │→ │ Executor    │ │
│  └────────────┘ └────────────┘  │   │  └─────────────┘  └─────────────┘  └─────────────┘ │
│         │             │         │   │         │               │                │         │
└─────────┼─────────────┼─────────┘   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │
          │             │             │  │ Data        │  │ Portfolio   │  │ TimescaleDB │ │
          └─────────────┴───────────┬─┤  │ Integrity   │  │ Tracker     │  │ (Storage)   │ │
                                    │ │  └─────────────┘  └─────────────┘  └─────────────┘ │
                       ┌────────────┴─┴────────────────────────────────────┐
                       │               Kubernetes Cluster                  │
                       │                 (k3s + Flux CD)                   │
                       └───────────────────────────────────────────────────┘
```

## 📦 **Components**

### **Frontend** (`blog-site`)
- **Technology**: Angular + Nginx
- **URL**: `https://blog.sudharsana.dev`
- **Auto-scaling**: HPA enabled (2-10 pods)

### **Backend API** (`blog-site-backend`)
- **Technology**: Node.js + Express
- **URL**: `https://blog.sudharsana.dev/api/*`
- **Features**: Posts, Comments, Likes, Analytics

### **Infrastructure** (`blog-site-infra`)
- **Technology**: Multi-service container (Supervisor)
- **Services**: PostgreSQL, Redis, Prometheus, Grafana
- **Monitoring**: Postgres Exporter, Blackbox Exporter

### **Trading System** (`trading`)
- **Strategy Engine**: AI/ML based decision making (Python)
- **Data Ingestion**: Real-time market data feed handler
- **Order Executor**: Low-latency trade execution
- **Portfolio Tracker**: PnL and position monitoring
- **Data Integrity**: Gap detection and self-healing
- **TimescaleDB**: Time-series data storage for market data

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
- **Blog Frontend**: `docker.io/sudhan03/blog-site`
- **Backend API**: `docker.io/sudhan03/blog-site-backend`
- **Infrastructure**: `docker.io/sudhan03/blog-site-infra`

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
- `trading` - High-frequency trading system

### **Key Resources**
- **Deployments**: 
  - **Web**: `blog`, `blog-backend`, `infra`
  - **Trading**: `strategy-engine`, `order-executor`, `data-ingestion`, `portfolio-tracker`, `data-integrity`, `reconciliation`, `redis`, `timescaledb`
- **Services**: `blog`, `blog-backend-service`, `infra`, `timescaledb`, `redis`
- **Ingress**: `blog` (with TLS)
- **HPA**: `blog` (auto-scaling)
- **PVC**: Data persistence (Postgres, TimescaleDB, Redis)

## 📁 **Repository Structure**

```
├── clusters/prod/           # Kubernetes manifests
│   ├── apps/
│   │   ├── blog/           # Frontend application
│   │   ├── backend/        # Backend API
│   │   ├── monitoring/     # Monitoring stack
│   │   └── infra/          # Infrastructure services
│   └── kustomization.yaml  # Main kustomization
├── .github/workflows/       # CI/CD workflows
├── backend/                 # Backend source code
├── infra/                   # Infrastructure components
├── blog/                    # Frontend build files
├── archive/                 # Archived files and docs
└── create-secrets.sh        # Security setup script
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
