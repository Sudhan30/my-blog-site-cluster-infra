# 🚀 Blog Backend Stack

A comprehensive backend infrastructure for your blog with PostgreSQL, Prometheus, Grafana, and monitoring capabilities.

## 🎯 **What's Included:**

### **📊 Backend Components:**
- **Node.js API** - Express server for likes, comments, and analytics
- **PostgreSQL** - Database for storing likes and comments
- **Redis** - Caching layer for improved performance
- **Prometheus** - Metrics collection and monitoring
- **Grafana** - Beautiful dashboards and visualization
- **Postgres Exporter** - Database metrics
- **Blackbox Exporter** - HTTP uptime monitoring

### **🔧 Features:**
- **Likes System** - Track post likes with user/IP deduplication
- **Comments System** - Full comment management with pagination
- **Analytics API** - Detailed analytics and metrics
- **Health Checks** - Comprehensive health monitoring
- **Rate Limiting** - Protection against abuse
- **Metrics Export** - Prometheus-compatible metrics
- **Caching** - Redis-based caching for performance
- **Logging** - Structured logging with Winston

## 🚀 **Quick Start:**

### **Option 1: Kubernetes (Recommended)**
```bash
# Set up complete backend stack
./setup-backend-stack.sh setup

# Or set up components individually
./setup-backend-stack.sh backend
./setup-backend-stack.sh monitoring
```

### **Option 2: Docker Compose**
```bash
# Start with Docker Compose
./setup-backend-stack.sh docker-compose

# Or manually
docker-compose up -d
```

## 📋 **Prerequisites:**

### **For Kubernetes:**
- Kubernetes cluster (k3s, minikube, etc.)
- kubectl configured
- Flux CD (for GitOps)

### **For Docker Compose:**
- Docker and Docker Compose
- Ports 3000, 3001, 5432, 6379, 9090, 9187, 9115 available

## 🏗️ **Architecture:**

```mermaid
graph TB
    subgraph "Frontend"
        Blog[Blog Site]
    end
    
    subgraph "Backend API"
        API[Node.js API]
        Redis[Redis Cache]
    end
    
    subgraph "Database"
        Postgres[PostgreSQL]
    end
    
    subgraph "Monitoring"
        Prometheus[Prometheus]
        Grafana[Grafana]
        PostgresExporter[Postgres Exporter]
        BlackboxExporter[Blackbox Exporter]
    end
    
    Blog --> API
    API --> Redis
    API --> Postgres
    PostgresExporter --> Postgres
    PostgresExporter --> Prometheus
    BlackboxExporter --> Blog
    BlackboxExporter --> Prometheus
    Prometheus --> Grafana
```

## 🔧 **Configuration:**

### **Environment Variables:**
```bash
NODE_ENV=production
PORT=3001
DATABASE_URL=postgresql://blog_user:blog_password@postgres-service:5432/blog_db
REDIS_URL=redis://redis-service:6379
JWT_SECRET=your-jwt-secret-key
```

### **Database Schema:**
```sql
-- Likes table
CREATE TABLE likes (
    id SERIAL PRIMARY KEY,
    post_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255),
    user_ip INET,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id),
    UNIQUE(post_id, user_ip)
);

-- Comments table
CREATE TABLE comments (
    id SERIAL PRIMARY KEY,
    post_id VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    author_name VARCHAR(255) NOT NULL,
    author_email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 📡 **API Endpoints:**

### **Health & Metrics:**
- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /metrics` - Prometheus metrics

### **Likes:**
- `GET /api/posts/:postId/likes` - Get post likes
- `POST /api/posts/:postId/like` - Like a post

### **Comments:**
- `GET /api/posts/:postId/comments` - Get post comments
- `POST /api/posts/:postId/comments` - Add comment

### **Analytics:**
- `GET /api/analytics` - Get analytics data

## 🎨 **Frontend Integration:**

### **JavaScript Example:**
```javascript
// Like a post
async function likePost(postId, userId) {
    const response = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/like`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            userId: userId,
            userIP: await getClientIP()
        })
    });
    
    const data = await response.json();
    return data;
}

// Get post likes
async function getPostLikes(postId) {
    const response = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/likes`);
    const data = await response.json();
    return data.likes;
}

// Add comment
async function addComment(postId, content, authorName, authorEmail) {
    const response = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/comments`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({
            content: content,
            authorName: authorName,
            authorEmail: authorEmail
        })
    });
    
    const data = await response.json();
    return data;
}
```

### **HTML Example:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Blog Post</title>
</head>
<body>
    <article>
        <h1>My Blog Post</h1>
        <p>Content goes here...</p>
        
        <div class="interactions">
            <button onclick="likePost('post-1', 'user123')">Like</button>
            <span id="like-count">0</span> likes
            
            <div class="comments">
                <h3>Comments</h3>
                <div id="comments-list"></div>
                
                <form onsubmit="addComment(event)">
                    <input type="text" name="authorName" placeholder="Your name" required>
                    <input type="email" name="authorEmail" placeholder="Your email">
                    <textarea name="content" placeholder="Your comment" required></textarea>
                    <button type="submit">Add Comment</button>
                </form>
            </div>
        </div>
    </article>

    <script>
        // Load likes and comments on page load
        window.onload = function() {
            loadPostData('post-1');
        };
        
        async function loadPostData(postId) {
            // Load likes
            const likesData = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/likes`);
            const likes = await likesData.json();
            document.getElementById('like-count').textContent = likes.likes;
            
            // Load comments
            const commentsData = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/comments`);
            const comments = await commentsData.json();
            displayComments(comments.comments);
        }
        
        async function likePost(postId, userId) {
            try {
                const response = await fetch(`https://api.sudharsana.dev/api/posts/${postId}/like`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ userId: userId, userIP: 'client-ip' })
                });
                
                const data = await response.json();
                if (data.success) {
                    document.getElementById('like-count').textContent = data.likes;
                } else {
                    alert(data.error);
                }
            } catch (error) {
                console.error('Error liking post:', error);
            }
        }
        
        async function addComment(event) {
            event.preventDefault();
            
            const formData = new FormData(event.target);
            const commentData = {
                content: formData.get('content'),
                authorName: formData.get('authorName'),
                authorEmail: formData.get('authorEmail')
            };
            
            try {
                const response = await fetch(`https://api.sudharsana.dev/api/posts/post-1/comments`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(commentData)
                });
                
                const data = await response.json();
                if (data.success) {
                    event.target.reset();
                    loadPostData('post-1'); // Reload comments
                } else {
                    alert(data.error);
                }
            } catch (error) {
                console.error('Error adding comment:', error);
            }
        }
        
        function displayComments(comments) {
            const commentsList = document.getElementById('comments-list');
            commentsList.innerHTML = comments.map(comment => `
                <div class="comment">
                    <strong>${comment.author_name}</strong>
                    <small>${new Date(comment.created_at).toLocaleDateString()}</small>
                    <p>${comment.content}</p>
                </div>
            `).join('');
        }
    </script>
</body>
</html>
```

## 📊 **Monitoring & Dashboards:**

### **Grafana Dashboards:**
- **Blog Uptime** - Real-time uptime monitoring
- **Response Times** - API performance metrics
- **Total Likes/Comments** - Engagement metrics
- **HTTP Request Rate** - Traffic patterns
- **Pod Resource Usage** - Kubernetes metrics

### **Prometheus Metrics:**
- `http_requests_total` - Total HTTP requests
- `blog_likes_total` - Total blog likes
- `blog_comments_total` - Total blog comments
- `http_request_duration_seconds` - Request duration
- `active_connections` - Active connections

### **Access URLs:**
- **Grafana**: https://grafana.sudharsana.dev (admin/admin123)
- **Prometheus**: https://prometheus.sudharsana.dev
- **Backend API**: https://api.sudharsana.dev

## 🛠️ **Management Commands:**

### **Setup & Deployment:**
```bash
# Complete setup
./setup-backend-stack.sh setup

# Individual components
./setup-backend-stack.sh backend
./setup-backend-stack.sh monitoring

# Docker Compose
./setup-backend-stack.sh docker-compose
```

### **Monitoring & Debugging:**
```bash
# Show status
./setup-backend-stack.sh status

# Show logs
./setup-backend-stack.sh logs backend
./setup-backend-stack.sh logs postgres
./setup-backend-stack.sh logs prometheus
./setup-backend-stack.sh logs grafana

# Test functionality
./setup-backend-stack.sh test
```

### **Cleanup:**
```bash
# Clean up all components
./setup-backend-stack.sh cleanup
```

## 🔒 **Security Features:**

### **Rate Limiting:**
- 100 requests per 15 minutes per IP
- Configurable limits

### **Input Validation:**
- Comment length limits (1000 characters)
- Required field validation
- SQL injection protection

### **CORS Configuration:**
- Restricted to blog domain
- Credential support

### **Helmet Security:**
- Security headers
- XSS protection
- Content Security Policy

## 📈 **Performance Features:**

### **Caching:**
- Redis-based caching
- 5-minute cache for likes
- Configurable cache TTL

### **Database Optimization:**
- Indexed queries
- Connection pooling
- Query optimization

### **Monitoring:**
- Real-time metrics
- Performance tracking
- Resource usage monitoring

## 🚨 **Troubleshooting:**

### **Common Issues:**

#### **Backend Not Starting:**
```bash
# Check logs
./setup-backend-stack.sh logs backend

# Check database connection
kubectl exec -it deployment/postgres -n web -- psql -U blog_user -d blog_db -c "SELECT 1;"
```

#### **Database Connection Issues:**
```bash
# Check PostgreSQL status
kubectl get pods -n web -l app=postgres

# Check database logs
./setup-backend-stack.sh logs postgres

# Test connection
kubectl exec -it deployment/postgres -n web -- psql -U blog_user -d blog_db
```

#### **Monitoring Issues:**
```bash
# Check Prometheus status
kubectl get pods -n web -l app=prometheus

# Check Grafana status
kubectl get pods -n web -l app=grafana

# Check metrics endpoint
curl https://api.sudharsana.dev/metrics
```

### **Health Checks:**
```bash
# Backend health
curl https://api.sudharsana.dev/health

# Database health
curl https://api.sudharsana.dev/ready

# Metrics
curl https://api.sudharsana.dev/metrics
```

## 🔄 **Backup & Recovery:**

### **Database Backup:**
```bash
# Create backup
kubectl exec -it deployment/postgres -n web -- pg_dump -U blog_user blog_db > backup.sql

# Restore backup
kubectl exec -i deployment/postgres -n web -- psql -U blog_user blog_db < backup.sql
```

### **Configuration Backup:**
```bash
# Backup ConfigMaps
kubectl get configmap -n web -o yaml > configmaps-backup.yaml

# Backup PVCs
kubectl get pvc -n web -o yaml > pvcs-backup.yaml
```

## 📚 **Development:**

### **Local Development:**
```bash
# Start backend locally
cd backend
npm install
npm run dev

# Start with Docker Compose
docker-compose up -d
```

### **Testing:**
```bash
# Run tests
cd backend
npm test

# Test API endpoints
curl http://localhost:3001/health
curl http://localhost:3001/api/posts/test/likes
```

## 🎉 **Success Criteria:**

Your backend stack is working correctly if:

✅ **Backend API** responds to health checks  
✅ **Database** is accessible and has tables  
✅ **Redis** is connected and caching works  
✅ **Prometheus** is collecting metrics  
✅ **Grafana** shows dashboards  
✅ **Likes/Comments** can be created and retrieved  
✅ **Analytics** endpoint returns data  
✅ **Monitoring** shows real-time metrics  

---

**🎯 Your complete backend infrastructure is now ready!**

*This stack provides a robust foundation for your blog with likes, comments, analytics, and comprehensive monitoring.*
