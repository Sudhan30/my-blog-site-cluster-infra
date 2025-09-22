# 🚀 Blog API Documentation

This document provides comprehensive documentation for the Blog API endpoints that your frontend can use to interact with the database.

## 📋 **Base URL**
- **Production**: `https://api.sudharsana.dev`
- **Development**: `http://localhost:3001` (via port forward)

## 🔐 **Authentication**
The API uses anonymous tracking with optional cookies:
- **Client ID**: UUID for persistent user tracking
- **IP Hashing**: SHA-256 hash for privacy protection
- **Rate Limiting**: 100 requests per 15 minutes per IP

## 📊 **API Endpoints**

### **1. Posts**

#### **Get All Posts**
```http
GET /api/posts?page=1&limit=10
```

**Response:**
```json
{
  "posts": [
    {
      "id": 1,
      "slug": "my-first-blog",
      "title": "My First Blog Post",
      "content": "Welcome to my blog!",
      "created_at": "2025-09-22T00:00:00.000Z",
      "comment_count": 5,
      "like_count": 12
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 25,
    "pages": 3
  }
}
```

#### **Get Single Post**
```http
GET /api/posts/{slug}
```

**Response:**
```json
{
  "post": {
    "id": 1,
    "slug": "my-first-blog",
    "title": "My First Blog Post",
    "content": "Welcome to my blog!",
    "created_at": "2025-09-22T00:00:00.000Z",
    "comment_count": 5,
    "like_count": 12
  }
}
```

### **2. Comments**

#### **Get Post Comments**
```http
GET /api/posts/{postId}/comments?page=1&limit=10
```

**Response:**
```json
{
  "postId": 1,
  "comments": [
    {
      "id": 1,
      "display_name": "John Doe",
      "content": "Great post! Thanks for sharing.",
      "created_at": "2025-09-22T01:00:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 10,
    "total": 5,
    "pages": 1
  }
}
```

#### **Add Comment**
```http
POST /api/posts/{postId}/comments
Content-Type: application/json

{
  "content": "Great post! Thanks for sharing.",
  "displayName": "John Doe",
  "clientId": "optional-uuid-for-tracking",
  "userIP": "192.168.1.100"
}
```

**Response:**
```json
{
  "success": true,
  "comment": {
    "id": 1,
    "created_at": "2025-09-22T01:00:00.000Z"
  },
  "clientId": "generated-uuid"
}
```

### **3. Likes**

#### **Get Post Likes**
```http
GET /api/posts/{postId}/likes
```

**Response:**
```json
{
  "postId": 1,
  "likes": 12,
  "cached": false
}
```

#### **Like a Post**
```http
POST /api/posts/{postId}/like
Content-Type: application/json

{
  "clientId": "optional-uuid-for-tracking",
  "userIP": "192.168.1.100"
}
```

**Response:**
```json
{
  "success": true,
  "likes": 13,
  "clientId": "generated-uuid"
}
```

### **4. Analytics**

#### **Get Analytics Data**
```http
GET /api/analytics?period=7d
```

**Available Periods:** `1d`, `7d`, `30d`, `90d`

**Response:**
```json
{
  "totalLikes": 150,
  "totalComments": 45,
  "likesByDay": [
    {
      "date": "2025-09-21",
      "count": "12"
    }
  ],
  "commentsByDay": [
    {
      "date": "2025-09-21",
      "count": "5"
    }
  ],
  "period": "7d"
}
```

### **5. Health & Metrics**

#### **Health Check**
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-09-22T00:00:00.000Z",
  "uptime": 3600,
  "memory": {
    "rss": 123456789,
    "heapTotal": 98765432,
    "heapUsed": 87654321
  }
}
```

#### **Metrics**
```http
GET /metrics
```

**Response:** Prometheus metrics format

## 🎯 **Frontend Integration Examples**

### **React/Angular Service Example**

```typescript
class BlogApiService {
  private baseUrl = 'https://api.sudharsana.dev';
  private clientId = this.getOrCreateClientId();

  private getOrCreateClientId(): string {
    let clientId = localStorage.getItem('blog_client_id');
    if (!clientId) {
      clientId = crypto.randomUUID();
      localStorage.setItem('blog_client_id', clientId);
    }
    return clientId;
  }

  // Get all posts
  async getPosts(page = 1, limit = 10) {
    const response = await fetch(`${this.baseUrl}/api/posts?page=${page}&limit=${limit}`);
    return response.json();
  }

  // Get single post
  async getPost(slug: string) {
    const response = await fetch(`${this.baseUrl}/api/posts/${slug}`);
    return response.json();
  }

  // Get comments for a post
  async getComments(postId: number, page = 1, limit = 10) {
    const response = await fetch(`${this.baseUrl}/api/posts/${postId}/comments?page=${page}&limit=${limit}`);
    return response.json();
  }

  // Add comment
  async addComment(postId: number, content: string, displayName: string) {
    const response = await fetch(`${this.baseUrl}/api/posts/${postId}/comments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        content,
        displayName,
        clientId: this.clientId
      })
    });
    return response.json();
  }

  // Get likes for a post
  async getLikes(postId: number) {
    const response = await fetch(`${this.baseUrl}/api/posts/${postId}/likes`);
    return response.json();
  }

  // Like a post
  async likePost(postId: number) {
    const response = await fetch(`${this.baseUrl}/api/posts/${postId}/like`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        clientId: this.clientId
      })
    });
    return response.json();
  }

  // Get analytics
  async getAnalytics(period = '7d') {
    const response = await fetch(`${this.baseUrl}/api/analytics?period=${period}`);
    return response.json();
  }
}
```

### **JavaScript Fetch Examples**

```javascript
// Get all posts
const posts = await fetch('https://api.sudharsana.dev/api/posts')
  .then(res => res.json());

// Get single post
const post = await fetch('https://api.sudharsana.dev/api/posts/my-first-blog')
  .then(res => res.json());

// Get comments
const comments = await fetch('https://api.sudharsana.dev/api/posts/1/comments')
  .then(res => res.json());

// Add comment
const newComment = await fetch('https://api.sudharsana.dev/api/posts/1/comments', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    content: 'Great post!',
    displayName: 'John Doe',
    clientId: 'your-client-id'
  })
}).then(res => res.json());

// Like a post
const likeResult = await fetch('https://api.sudharsana.dev/api/posts/1/like', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    clientId: 'your-client-id'
  })
}).then(res => res.json());
```

## 🔒 **Privacy & Security Features**

### **1. Anonymous Tracking**
- **Client ID**: UUID stored in localStorage for persistent user tracking
- **IP Hashing**: SHA-256 hash of IP addresses for privacy
- **No Personal Data**: Only display names and content are stored

### **2. Rate Limiting**
- **Limit**: 100 requests per 15 minutes per IP
- **Purpose**: Prevent spam and abuse
- **Response**: 429 status code when limit exceeded

### **3. Input Validation**
- **Comment Length**: 1-2000 characters
- **Required Fields**: Content and display name for comments
- **SQL Injection**: Protected with parameterized queries

### **4. Comment Moderation**
- **Status System**: approved, pending, rejected
- **Default**: All comments are approved
- **Future**: Admin interface for moderation

## 📈 **Performance Features**

### **1. Caching**
- **Redis**: Like counts cached for 5 minutes
- **Database**: Optimized queries with proper indexing
- **Frontend**: Client ID stored in localStorage

### **2. Pagination**
- **Posts**: Default 10 per page, max 100
- **Comments**: Default 10 per page, max 100
- **Efficient**: Offset-based pagination with limits

### **3. Metrics**
- **Prometheus**: Built-in metrics collection
- **Monitoring**: Request counts, response times, errors
- **Analytics**: Like and comment trends over time

## 🚨 **Error Handling**

### **Common Error Responses**

```json
// 400 Bad Request
{
  "error": "Content and display name are required"
}

// 404 Not Found
{
  "error": "Post not found"
}

// 429 Too Many Requests
{
  "error": "Too many requests from this IP, please try again later."
}

// 500 Internal Server Error
{
  "error": "Something went wrong!"
}
```

## 🔧 **Testing**

### **Health Check**
```bash
curl https://api.sudharsana.dev/health
```

### **Test API Endpoints**
```bash
# Get posts
curl https://api.sudharsana.dev/api/posts

# Get single post
curl https://api.sudharsana.dev/api/posts/my-first-blog

# Get comments
curl https://api.sudharsana.dev/api/posts/1/comments

# Like a post
curl -X POST https://api.sudharsana.dev/api/posts/1/like \
  -H "Content-Type: application/json" \
  -d '{"clientId": "test-client-id"}'

# Add comment
curl -X POST https://api.sudharsana.dev/api/posts/1/comments \
  -H "Content-Type: application/json" \
  -d '{"content": "Great post!", "displayName": "Test User", "clientId": "test-client-id"}'
```

## 🎯 **Next Steps**

1. **Frontend Integration**: Use the API service examples above
2. **Client ID Management**: Implement localStorage-based tracking
3. **Error Handling**: Add proper error handling in your frontend
4. **Loading States**: Show loading indicators for API calls
5. **Real-time Updates**: Consider WebSocket for live comments/likes

Your API is now ready for frontend integration! 🚀
