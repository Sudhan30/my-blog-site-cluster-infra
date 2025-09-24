const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');
const redis = require('redis');
const rateLimit = require('express-rate-limit');
const client = require('prom-client');
const winston = require('winston');
const crypto = require('crypto');

// Configure logging
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' }),
    new winston.transports.Console({
      format: winston.format.simple()
    })
  ]
});

const app = express();
const PORT = process.env.PORT || 3001;

// Prometheus metrics
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const likesTotal = new client.Counter({
  name: 'blog_likes_total',
  help: 'Total number of blog likes',
  labelNames: ['post_id'],
  registers: [register]
});

const commentsTotal = new client.Counter({
  name: 'blog_comments_total',
  help: 'Total number of blog comments',
  labelNames: ['post_id'],
  registers: [register]
});

const unlikesTotal = new client.Counter({
  name: 'blog_unlikes_total',
  help: 'Total number of blog unlikes',
  labelNames: ['post_id'],
  registers: [register]
});

const responseTime = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
  registers: [register]
});

const activeConnections = new client.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  registers: [register]
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false, // Disabled for your setup
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Redis connection
const redisClient = redis.createClient({
  url: process.env.REDIS_URL
});

redisClient.on('error', (err) => logger.error('Redis Client Error', err));
redisClient.on('connect', () => logger.info('Redis connected'));
redisClient.connect();

// Utility functions
const hashIP = (ip) => {
  return crypto.createHash('sha256').update(ip).digest('hex');
};

const generateClientId = () => {
  return crypto.randomUUID();
};

// Middleware
app.use(helmet());
app.use(cors({
  origin: ['https://blog.sudharsana.dev', 'http://localhost:3000', 'http://localhost:4200'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use(limiter);

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  activeConnections.inc();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    responseTime.observe({ method: req.method, route: req.route?.path || req.path }, duration);
    httpRequestsTotal.inc({ method: req.method, route: req.route?.path || req.path, status_code: res.statusCode });
    activeConnections.dec();
  });
  
  next();
});

// Health check endpoints
// Health check (handle both /health and /api/health)
app.get(['/health', '/api/health'], async (req, res) => {
  try {
    await pool.query('SELECT 1');
    await redisClient.ping();
    res.status(200).json({ 
      status: 'healthy', 
      timestamp: new Date().toISOString(),
      uptime: process.uptime(),
      memory: process.memoryUsage()
    });
  } catch (error) {
    logger.error('Health check failed', error);
    res.status(503).json({ status: 'unhealthy', error: error.message });
  }
});

app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    await redisClient.ping();
    res.status(200).json({ status: 'ready' });
  } catch (error) {
    logger.error('Readiness check failed', error);
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// API Routes

// Get all posts (handle both /api/posts and /posts)
app.get(['/api/posts', '/posts'], async (req, res) => {
  try {
    const { page = 1, limit = 10 } = req.query;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offsetNum = (pageNum - 1) * limitNum;
    
    const result = await pool.query(`
      SELECT 
        p.id,
        p.slug,
        p.title,
        p.content,
        p.created_at,
        COUNT(DISTINCT c.id) as comment_count,
        COUNT(DISTINCT l.id) as like_count
      FROM posts p
      LEFT JOIN comments c ON p.id = c.post_id AND c.status = 'approved'
      LEFT JOIN likes l ON p.id = l.post_id
      GROUP BY p.id, p.slug, p.title, p.content, p.created_at
      ORDER BY p.created_at DESC
      LIMIT $1 OFFSET $2
    `, [limitNum, offsetNum]);
    
    const countResult = await pool.query('SELECT COUNT(*) as count FROM posts');
    
    res.json({
      posts: result.rows,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: parseInt(countResult.rows[0].count),
        pages: Math.ceil(countResult.rows[0].count / limitNum)
      }
    });
  } catch (error) {
    logger.error('Error getting posts', error);
    res.status(500).json({ error: error.message });
  }
});

// Get single post (handle both /api/posts/:slug and /posts/:slug)
app.get(['/api/posts/:slug', '/posts/:slug'], async (req, res) => {
  try {
    const { slug } = req.params;
    
    const result = await pool.query(`
      SELECT 
        p.id,
        p.slug,
        p.title,
        p.content,
        p.created_at,
        COUNT(DISTINCT c.id) as comment_count,
        COUNT(DISTINCT l.id) as like_count
      FROM posts p
      LEFT JOIN comments c ON p.id = c.post_id AND c.status = 'approved'
      LEFT JOIN likes l ON p.id = l.post_id
      WHERE p.slug = $1
      GROUP BY p.id, p.slug, p.title, p.content, p.created_at
    `, [slug]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Post not found' });
    }
    
    res.json({ post: result.rows[0] });
  } catch (error) {
    logger.error('Error getting post', error);
    res.status(500).json({ error: error.message });
  }
});

// Get post likes (handle both /api/posts/:postId/likes and /posts/:postId/likes)
app.get(['/api/posts/:postId/likes', '/posts/:postId/likes'], async (req, res) => {
  try {
    const { postId } = req.params;
    
    // Try cache first
    const cached = await redisClient.get(`likes:${postId}`);
    if (cached) {
      return res.json({ postId, likes: parseInt(cached), cached: true });
    }
    
    // Query using the string ID
    const result = await pool.query('SELECT COUNT(*) as count FROM likes WHERE post_id = $1', [postId]);
    const count = parseInt(result.rows[0].count);
    
    // Cache for 5 minutes
    await redisClient.setEx(`likes:${postId}`, 300, count.toString());
    res.json({ postId, likes: count, cached: false });
  } catch (error) {
    logger.error('Error getting likes', error);
    res.status(500).json({ error: error.message });
  }
});

// Like a post (handle both /api/posts/:postId/like and /posts/:postId/like)
app.post(['/api/posts/:postId/like', '/posts/:postId/like'], async (req, res) => {
  try {
    const { postId } = req.params;
    const { clientId, userIP } = req.body;
    
    // Validate input
    if (!postId) {
      return res.status(400).json({ error: 'Post ID is required' });
    }
    
    // Generate client ID if not provided or validate provided one
    let finalClientId;
    if (clientId) {
      // Validate UUID format
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(clientId)) {
        return res.status(400).json({ error: 'Invalid clientId format. Must be a valid UUID.' });
      }
      finalClientId = clientId;
    } else {
      finalClientId = generateClientId();
    }
    const ipHash = userIP ? hashIP(userIP) : null;
    
    // Check if already liked
    const existingLike = await pool.query(
      'SELECT id FROM likes WHERE post_id = $1 AND (client_id = $2 OR ip_hash = $3)',
      [postId, finalClientId, ipHash]
    );
    
    if (existingLike.rows.length > 0) {
      return res.status(400).json({ error: 'Already liked' });
    }
    
    // Add like
    await pool.query(
      'INSERT INTO likes (post_id, client_id, ip_hash, created_at) VALUES ($1, $2, $3, NOW())',
      [postId, finalClientId, ipHash]
    );
    
    // Update metrics
    likesTotal.inc({ post_id: postId });
    
    // Cache the like count
    const countResult = await pool.query('SELECT COUNT(*) as count FROM likes WHERE post_id = $1', [postId]);
    const count = parseInt(countResult.rows[0].count);
    await redisClient.setEx(`likes:${postId}`, 300, count.toString());
    
    logger.info(`Post ${postId} liked by ${finalClientId || ipHash}`);
    res.json({ success: true, likes: count, clientId: finalClientId });
  } catch (error) {
    logger.error('Error liking post', error);
    res.status(500).json({ error: error.message });
  }
});

// Unlike a post (handle both /api/posts/:postId/unlike and /posts/:postId/unlike)
app.delete(['/api/posts/:postId/unlike', '/posts/:postId/unlike'], async (req, res) => {
  try {
    const { postId } = req.params;
    const { clientId, userIP } = req.body;
    
    // Validate input
    if (!postId) {
      return res.status(400).json({ error: 'Post ID is required' });
    }
    
    // Validate clientId if provided
    let finalClientId = null;
    if (clientId) {
      const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(clientId)) {
        return res.status(400).json({ error: 'Invalid clientId format. Must be a valid UUID.' });
      }
      finalClientId = clientId;
    }
    
    const ipHash = userIP ? hashIP(userIP) : null;
    
    // Find the like to remove
    let deleteQuery, deleteParams;
    if (finalClientId && ipHash) {
      deleteQuery = 'DELETE FROM likes WHERE post_id = $1 AND (client_id = $2 OR ip_hash = $3) RETURNING id';
      deleteParams = [postId, finalClientId, ipHash];
    } else if (finalClientId) {
      deleteQuery = 'DELETE FROM likes WHERE post_id = $1 AND client_id = $2 RETURNING id';
      deleteParams = [postId, finalClientId];
    } else if (ipHash) {
      deleteQuery = 'DELETE FROM likes WHERE post_id = $1 AND ip_hash = $2 RETURNING id';
      deleteParams = [postId, ipHash];
    } else {
      return res.status(400).json({ error: 'Either clientId or userIP is required to unlike a post' });
    }
    
    const result = await pool.query(deleteQuery, deleteParams);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Like not found. Post may not have been liked by this user.' });
    }
    
    // Update metrics
    unlikesTotal.inc({ post_id: postId });
    
    // Cache the updated like count
    const countResult = await pool.query('SELECT COUNT(*) as count FROM likes WHERE post_id = $1', [postId]);
    const count = parseInt(countResult.rows[0].count);
    await redisClient.setEx(`likes:${postId}`, 300, count.toString());
    
    logger.info(`Post ${postId} unliked by ${finalClientId || ipHash}`);
    res.json({ success: true, likes: count, clientId: finalClientId, message: 'Post unliked successfully' });
  } catch (error) {
    logger.error('Error unliking post', error);
    res.status(500).json({ error: error.message });
  }
});

// Get post comments (handle both /api/posts/:postId/comments and /posts/:postId/comments)
app.get(['/api/posts/:postId/comments', '/posts/:postId/comments'], async (req, res) => {
  try {
    const { postId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offsetNum = (pageNum - 1) * limitNum;
    
    const result = await pool.query(
      'SELECT id, display_name, content, created_at FROM comments WHERE post_id = $1 AND status = $2 ORDER BY created_at DESC LIMIT $3 OFFSET $4',
      [postId, 'approved', limitNum, offsetNum]
    );
    
    const countResult = await pool.query('SELECT COUNT(*) as count FROM comments WHERE post_id = $1 AND status = $2', [postId, 'approved']);
    
    res.json({
      postId,
      comments: result.rows,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: parseInt(countResult.rows[0].count),
        pages: Math.ceil(countResult.rows[0].count / limitNum)
      }
    });
  } catch (error) {
    logger.error('Error getting comments', error);
    res.status(500).json({ error: error.message });
  }
});

// Add comment (handle both /api/posts/:postId/comments and /posts/:postId/comments)
app.post(['/api/posts/:postId/comments', '/posts/:postId/comments'], async (req, res) => {
  try {
    const { postId } = req.params;
    const { content, displayName, clientId, userIP } = req.body;
    
    // Validate input
    if (!content || !displayName) {
      return res.status(400).json({ error: 'Content and display name are required' });
    }
    
    if (content.length < 1 || content.length > 2000) {
      return res.status(400).json({ error: 'Comment must be between 1 and 2000 characters' });
    }
    
    // Generate display name if not provided
    const finalDisplayName = displayName || 'Anonymous';
    const finalClientId = clientId || generateClientId();
    const ipHash = userIP ? hashIP(userIP) : null;
    
    const result = await pool.query(
      'INSERT INTO comments (post_id, display_name, content, client_id, ip_hash, created_at) VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING id, created_at',
      [postId, finalDisplayName, content, finalClientId, ipHash]
    );
    
    // Update metrics
    commentsTotal.inc({ post_id: postId });
    
    logger.info(`Comment added to post ${postId} by ${finalDisplayName}`);
    res.status(201).json({
      success: true,
      comment: result.rows[0],
      clientId: finalClientId
    });
  } catch (error) {
    logger.error('Error adding comment', error);
    res.status(500).json({ error: error.message });
  }
});

// Get analytics data
// Analytics (handle both /api/analytics and /analytics)
app.get(['/api/analytics', '/analytics'], async (req, res) => {
  try {
    const { period = '7d' } = req.query;
    
    // Validate period
    const validPeriods = ['1d', '7d', '30d', '90d'];
    if (!validPeriods.includes(period)) {
      return res.status(400).json({ error: 'Invalid period. Use: 1d, 7d, 30d, 90d' });
    }
    
    // Get total likes
    const likesResult = await pool.query('SELECT COUNT(*) as count FROM likes');
    
    // Get total comments
    const commentsResult = await pool.query('SELECT COUNT(*) as count FROM comments WHERE status = $1', ['approved']);
    
    // Get likes by day
    const likesByDay = await pool.query(`
      SELECT DATE(created_at) as date, COUNT(*) as count 
      FROM likes 
      WHERE created_at >= NOW() - INTERVAL '${period}'
      GROUP BY DATE(created_at) 
      ORDER BY date
    `);
    
    // Get comments by day
    const commentsByDay = await pool.query(`
      SELECT DATE(created_at) as date, COUNT(*) as count 
      FROM comments 
      WHERE created_at >= NOW() - INTERVAL '${period}' AND status = 'approved'
      GROUP BY DATE(created_at) 
      ORDER BY date
    `);
    
    res.json({
      totalLikes: parseInt(likesResult.rows[0].count),
      totalComments: parseInt(commentsResult.rows[0].count),
      likesByDay: likesByDay.rows,
      commentsByDay: commentsByDay.rows,
      period: period
    });
  } catch (error) {
    logger.error('Error getting analytics', error);
    res.status(500).json({ error: error.message });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  logger.error('Unhandled error', err);
  res.status(500).json({ error: 'Something went wrong!' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  logger.info(`Blog backend server running on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  await pool.end();
  await redisClient.quit();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  await pool.end();
  await redisClient.quit();
  process.exit(0);
});
