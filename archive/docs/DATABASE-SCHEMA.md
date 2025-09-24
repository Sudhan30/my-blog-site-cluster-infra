# 📊 Blog Database Schema Documentation

This document contains the complete database schema for the blog application, including posts, comments, and likes functionality.

## 🏗️ **Database Structure**

### **Database Details:**
- **Database Name**: `blog_db`
- **Username**: `blog_user`
- **Password**: `blog_password`
- **Host**: `postgres-service` (Kubernetes service)
- **Port**: `5432`

## 📋 **Tables Schema**

### **1. Comment Status Enum**
```sql
-- Optional: for simple moderation later; drop if you don't want it
DO $$ BEGIN
  CREATE TYPE comment_status AS ENUM ('approved','pending','rejected');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
```

### **2. Posts Table**
```sql
-- Content being liked/commented. Keep if you have multiple posts/pages.
CREATE TABLE posts (
  id          bigserial PRIMARY KEY,
  slug        text UNIQUE NOT NULL,          -- e.g. "my-first-blog"
  title       text NOT NULL,
  content     text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
```

**Fields:**
- `id` - Auto-incrementing primary key
- `slug` - Unique URL-friendly identifier (e.g., "my-first-blog")
- `title` - Post title
- `content` - Post content (can be NULL)
- `created_at` - Timestamp with timezone, defaults to current time

### **3. Comments Table**
```sql
-- Anonymous comments: display_name is required (your app generates if blank)
CREATE TABLE comments (
  id            bigserial PRIMARY KEY,
  post_id       bigint NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  display_name  text   NOT NULL,             -- user-supplied or app-generated
  content       text   NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  -- Optional anonymous telemetry (store hashed for privacy; compute in app)
  client_id     uuid,                        -- from your cookie, if present
  ip_hash       char(64),                    -- SHA-256 hex of IP (optional)
  status        comment_status NOT NULL DEFAULT 'approved',
  CONSTRAINT comments_len CHECK (char_length(content) BETWEEN 1 AND 2000)
);
```

**Fields:**
- `id` - Auto-incrementing primary key
- `post_id` - Foreign key to posts table (CASCADE delete)
- `display_name` - Commenter's name (required, app-generated if blank)
- `content` - Comment content (1-2000 characters)
- `created_at` - Timestamp with timezone, defaults to current time
- `client_id` - UUID for cookie-based tracking (optional)
- `ip_hash` - SHA-256 hash of IP address for privacy (optional)
- `status` - Comment moderation status (approved/pending/rejected)

### **4. Likes Table**
```sql
-- Anonymous likes with dedupe:
-- Prefer client_id (cookie). If missing, fall back to one like per IP per day.
CREATE TABLE likes (
  id          bigserial PRIMARY KEY,
  post_id     bigint NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  client_id   uuid,            -- if you can set a cookie
  ip_hash     char(64),        -- fallback dedupe if no cookie

  -- Generated day (UTC) to dedupe IP likes per day without a heavy query
  like_day    date GENERATED ALWAYS AS ( (created_at AT TIME ZONE 'UTC')::date ) STORED,

  -- Must have at least one identifier to dedupe on
  CONSTRAINT likes_identity_present CHECK (client_id IS NOT NULL OR ip_hash IS NOT NULL)
);
```

**Fields:**
- `id` - Auto-incrementing primary key
- `post_id` - Foreign key to posts table (CASCADE delete)
- `created_at` - Timestamp with timezone, defaults to current time
- `client_id` - UUID for cookie-based tracking (optional)
- `ip_hash` - SHA-256 hash of IP address for privacy (optional)
- `like_day` - Generated field for daily deduplication (auto-calculated)

## 🔍 **Indexes**

### **Comments Indexes**
```sql
CREATE INDEX idx_comments_post_created ON comments (post_id, created_at DESC);
```

### **Likes Indexes**
```sql
-- Dedupe rules:
-- 1) If client_id present: one like per user per post.
CREATE UNIQUE INDEX ux_likes_post_client
  ON likes (post_id, client_id)
  WHERE client_id IS NOT NULL;

-- 2) If no client_id, fall back: one like per IP per post per day.
CREATE UNIQUE INDEX ux_likes_post_ip_day
  ON likes (post_id, ip_hash, like_day)
  WHERE client_id IS NULL AND ip_hash IS NOT NULL;

-- Helpful indexes
CREATE INDEX idx_likes_post ON likes (post_id);
CREATE INDEX idx_posts_created ON posts (created_at DESC);
```

## 🎯 **Key Features**

### **1. Comment Moderation**
- Comments can be approved, pending, or rejected
- Default status is 'approved'
- Content length validation (1-2000 characters)

### **2. Anonymous Tracking**
- Uses UUID cookies for persistent users
- Falls back to IP hashing for privacy
- SHA-256 hashing for IP addresses

### **3. Like Deduplication**
- **Cookie-based**: One like per user per post (if cookie available)
- **IP-based**: One like per IP per post per day (fallback)
- Prevents spam and ensures fair counting

### **4. Data Integrity**
- Foreign key constraints with CASCADE delete
- Check constraints for data validation
- Unique constraints for deduplication

## 🚀 **Usage Examples**

### **Create a Post**
```sql
INSERT INTO posts (slug, title, content) VALUES 
('my-first-blog', 'My First Blog Post', 'Welcome to my blog!');
```

### **Add a Comment**
```sql
INSERT INTO comments (post_id, display_name, content) VALUES 
(1, 'John Doe', 'Great post! Thanks for sharing.');
```

### **Like a Post**
```sql
INSERT INTO likes (post_id, client_id) VALUES 
(1, gen_random_uuid());
```

### **Query Posts with Counts**
```sql
SELECT 
    p.id,
    p.slug,
    p.title,
    p.created_at,
    COUNT(DISTINCT c.id) as comment_count,
    COUNT(DISTINCT l.id) as like_count
FROM posts p
LEFT JOIN comments c ON p.id = c.post_id AND c.status = 'approved'
LEFT JOIN likes l ON p.id = l.post_id
GROUP BY p.id, p.slug, p.title, p.created_at
ORDER BY p.created_at DESC;
```

## 🔧 **Database Access**

### **Port Forward (for DBeaver)**
```bash
kubectl port-forward svc/postgres-service -n web 5432:5432
```

### **Direct Pod Access**
```bash
kubectl exec -it -n web deployment/postgres -- psql -U blog_user -d blog_db
```

### **Connection Details**
- **Host**: `localhost` (via port forward) or `postgres-service` (within cluster)
- **Port**: `5432`
- **Database**: `blog_db`
- **Username**: `blog_user`
- **Password**: `blog_password`
- **SSL**: Disabled

## 📝 **Notes**

1. **Privacy-First Design**: Uses hashed IPs and optional cookies for tracking
2. **Moderation Ready**: Built-in comment status system for content moderation
3. **Scalable**: Proper indexing for performance with large datasets
4. **Flexible**: Supports both cookie-based and IP-based user tracking
5. **Clean**: CASCADE deletes ensure data consistency

This schema provides a solid foundation for a blog with commenting and liking functionality while maintaining user privacy and preventing spam.
