const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');
const redis = require('redis');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const rateLimit = require('express-rate-limit');
const client = require('prom-client');
const winston = require('winston');

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
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
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

// Middleware
app.use(helmet());
app.use(cors({
  origin: ['https://blog.sudharsana.dev', 'http://localhost:3000'],
  credentials: true
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
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    // Check Redis connection
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

// Get post likes
app.get('/api/posts/:postId/likes', async (req, res) => {
  try {
    const { postId } = req.params;
    
    // Try cache first
    const cached = await redisClient.get(`likes:${postId}`);
    if (cached) {
      return res.json({ postId, likes: parseInt(cached), cached: true });
    }
    
    const result = await pool.query('SELECT COUNT(*) as count FROM likes WHERE post_id = $1', [postId]);
    const count = parseInt(result.rows[0].count);
    
    // Cache for 5 minutes
    await redisClient.setEx(`likes:${postId}`, 300, count);
    
    res.json({ postId, likes: count, cached: false });
  } catch (error) {
    logger.error('Error getting likes', error);
    res.status(500).json({ error: error.message });
  }
});

// Like a post
app.post('/api/posts/:postId/like', async (req, res) => {
  try {
    const { postId } = req.params;
    const { userId, userIP } = req.body;
    
    // Validate input
    if (!postId) {
      return res.status(400).json({ error: 'Post ID is required' });
    }
    
    // Check if already liked (by user or IP)
    const existingLike = await pool.query(
      'SELECT id FROM likes WHERE post_id = $1 AND (user_id = $2 OR user_ip = $3)',
      [postId, userId, userIP]
    );
    
    if (existingLike.rows.length > 0) {
      return res.status(400).json({ error: 'Already liked' });
    }
    
    // Add like
    await pool.query(
      'INSERT INTO likes (post_id, user_id, user_ip, created_at) VALUES ($1, $2, $3, NOW())',
      [postId, userId, userIP]
    );
    
    // Update metrics
    likesTotal.inc({ post_id: postId });
    
    // Cache the like count
    const countResult = await pool.query('SELECT COUNT(*) as count FROM likes WHERE post_id = $1', [postId]);
    const count = parseInt(countResult.rows[0].count);
    await redisClient.setEx(`likes:${postId}`, 300, count);
    
    logger.info(`Post ${postId} liked by ${userId || userIP}`);
    res.json({ success: true, likes: count });
  } catch (error) {
    logger.error('Error liking post', error);
    res.status(500).json({ error: error.message });
  }
});

// Get post comments
app.get('/api/posts/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const { page = 1, limit = 10 } = req.query;
    const offset = (page - 1) * limit;
    
    // Validate pagination
    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offsetNum = (pageNum - 1) * limitNum;
    
    const result = await pool.query(
      'SELECT id, content, author_name, author_email, created_at FROM comments WHERE post_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
      [postId, limitNum, offsetNum]
    );
    
    const countResult = await pool.query('SELECT COUNT(*) as count FROM comments WHERE post_id = $1', [postId]);
    
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

// Add comment
app.post('/api/posts/:postId/comments', async (req, res) => {
  try {
    const { postId } = req.params;
    const { content, authorName, authorEmail } = req.body;
    
    // Validate input
    if (!content || !authorName) {
      return res.status(400).json({ error: 'Content and author name are required' });
    }
    
    if (content.length > 1000) {
      return res.status(400).json({ error: 'Comment too long (max 1000 characters)' });
    }
    
    const result = await pool.query(
      'INSERT INTO comments (post_id, content, author_name, author_email, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at',
      [postId, content, authorName, authorEmail]
    );
    
    // Update metrics
    commentsTotal.inc({ post_id: postId });
    
    logger.info(`Comment added to post ${postId} by ${authorName}`);
    res.status(201).json({
      success: true,
      comment: result.rows[0]
    });
  } catch (error) {
    logger.error('Error adding comment', error);
    res.status(500).json({ error: error.message });
  }
});

// Get analytics data
app.get('/api/analytics', async (req, res) => {
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
    const commentsResult = await pool.query('SELECT COUNT(*) as count FROM comments');
    
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
      WHERE created_at >= NOW() - INTERVAL '${period}'
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