const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { Pool } = require('pg');
const redis = require('redis');
const rateLimit = require('express-rate-limit');
const client = require('prom-client');
const winston = require('winston');
const crypto = require('crypto');
const fetch = require('node-fetch');

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

const newsletterSubscriptions = new client.Counter({
  name: 'newsletter_subscriptions_total',
  help: 'Total number of newsletter subscriptions',
  labelNames: ['status'],
  registers: [register]
});

const newsletterUnsubscriptions = new client.Counter({
  name: 'newsletter_unsubscriptions_total',
  help: 'Total number of newsletter unsubscriptions',
  registers: [register]
});

const feedbackSubmissions = new client.Counter({
  name: 'feedback_submissions_total',
  help: 'Total number of feedback submissions',
  labelNames: ['rating'],
  registers: [register]
});

const feedbackRateLimitHits = new client.Counter({
  name: 'feedback_rate_limit_hits_total',
  help: 'Total number of feedback rate limit hits',
  registers: [register]
});

const pageViews = new client.Counter({
  name: 'page_views_total',
  help: 'Total number of page views',
  labelNames: ['page_url', 'device_type'],
  registers: [register]
});

const clicks = new client.Counter({
  name: 'clicks_total',
  help: 'Total number of clicks',
  labelNames: ['element_type', 'element_id'],
  registers: [register]
});

const userSessions = new client.Counter({
  name: 'user_sessions_total',
  help: 'Total number of user sessions',
  labelNames: ['device_type', 'browser'],
  registers: [register]
});

const bounceRate = new client.Gauge({
  name: 'bounce_rate',
  help: 'Bounce rate percentage',
  registers: [register]
});

const averageSessionDuration = new client.Gauge({
  name: 'average_session_duration_seconds',
  help: 'Average session duration in seconds',
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
  origin: [
    'https://blog.sudharsana.dev',
    'http://localhost:3000',
    'http://localhost:4200',
    'http://localhost:8080',
    'http://localhost:5173',
    'http://localhost:3001',
    'https://sudharsana.dev'
  ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting - skip health/ready endpoints to prevent K8s probe failures
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  // Skip rate limiting for health checks and metrics to prevent K8s probe failures
  skip: (req) => {
    const skipPaths = ['/health', '/api/health', '/ready', '/metrics'];
    return skipPaths.includes(req.path);
  }
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

// Helper function to check if IP is allowed
const isAllowedIP = (ip, allowedIPs) => {
  // Handle IPv6-mapped IPv4 addresses
  if (ip.startsWith('::ffff:')) {
    ip = ip.substring(7);
  }

  // Check exact matches first
  if (allowedIPs.includes(ip)) {
    return true;
  }

  // Check CIDR ranges
  for (const allowedIP of allowedIPs) {
    if (allowedIP.includes('/')) {
      // Simple CIDR check for common private ranges
      const [network, prefix] = allowedIP.split('/');
      if (isIPInRange(ip, network, parseInt(prefix))) {
        return true;
      }
    }
  }

  return false;
};

// Simple CIDR range checker
const isIPInRange = (ip, network, prefix) => {
  const ipParts = ip.split('.').map(Number);
  const networkParts = network.split('.').map(Number);

  if (ipParts.length !== 4 || networkParts.length !== 4) return false;

  const mask = (0xffffffff << (32 - prefix)) >>> 0;
  const ipNum = (ipParts[0] << 24) + (ipParts[1] << 16) + (ipParts[2] << 8) + ipParts[3];
  const networkNum = (networkParts[0] << 24) + (networkParts[1] << 16) + (networkParts[2] << 8) + networkParts[3];

  return (ipNum & mask) === (networkNum & mask);
};

// Health check endpoints
// Health check (handle both /health and /api/health)
app.get(['/health', '/api/health'], async (req, res) => {
  try {
    // IP restriction for health endpoint
    const clientIP = req.ip || req.connection.remoteAddress || req.socket.remoteAddress;
    const allowedIPs = [
      '127.0.0.1',           // localhost
      '::1',                 // IPv6 localhost
      '10.0.0.0/8',          // Kubernetes internal
      '172.16.0.0/12',       // Docker internal
      '192.168.0.0/16',      // Private networks
      '99.35.22.29'          // Your server IP
    ];

    if (!isAllowedIP(clientIP, allowedIPs)) {
      logger.warn(`Health check blocked from IP: ${clientIP}`);
      return res.status(403).json({
        status: 'forbidden',
        message: 'Access denied',
        timestamp: new Date().toISOString()
      });
    }

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

// Comment rate limiting per IP
const commentRateLimit = new Map();

const checkCommentRateLimit = (ip) => {
  const now = Date.now();
  const windowMs = 60000; // 1 minute
  const maxComments = 5; // Max 5 comments per minute

  if (!commentRateLimit.has(ip)) {
    commentRateLimit.set(ip, []);
  }

  const timestamps = commentRateLimit.get(ip);
  const validTimestamps = timestamps.filter(time => now - time < windowMs);

  if (validTimestamps.length >= maxComments) {
    throw new Error('Too many comments. Please wait before posting again.');
  }

  validTimestamps.push(now);
  commentRateLimit.set(ip, validTimestamps);
};

// Enhanced comment validation
const validateComment = (content, displayName) => {
  // 1. Required fields
  if (!content || !displayName) {
    throw new Error('Content and display name are required');
  }

  // 2. Length validation
  if (content.length < 10 || content.length > 2000) {
    throw new Error('Comment must be between 10 and 2000 characters');
  }

  if (displayName.length > 50) {
    throw new Error('Display name must be less than 50 characters');
  }

  // 3. HTML/Script filtering - remove potentially dangerous tags
  const cleanContent = content
    .replace(/<script[^>]*>.*?<\/script>/gi, '') // Remove script tags
    .replace(/<[^>]*>/g, '') // Remove all HTML tags
    .replace(/javascript:/gi, '') // Remove javascript: URLs
    .replace(/on\w+\s*=/gi, ''); // Remove event handlers

  // 4. Basic spam detection (simple keyword filtering)
  const spamKeywords = [
    'buy now', 'click here', 'free money', 'make money fast',
    'viagra', 'casino', 'loan', 'credit', 'debt consolidation',
    'work from home', 'get rich', 'win money', 'lottery'
  ];

  const lowerContent = cleanContent.toLowerCase();
  const hasSpam = spamKeywords.some(keyword => lowerContent.includes(keyword));

  if (hasSpam) {
    throw new Error('Comment contains inappropriate content');
  }

  // 5. Check for excessive repetition
  const words = cleanContent.split(/\s+/);
  const wordCount = {};
  words.forEach(word => {
    wordCount[word.toLowerCase()] = (wordCount[word.toLowerCase()] || 0) + 1;
  });

  const maxRepetition = Math.max(...Object.values(wordCount));
  if (maxRepetition > words.length * 0.3) {
    throw new Error('Comment contains excessive repetition');
  }

  return cleanContent;
};

// Add comment (handle both /api/posts/:postId/comments and /posts/:postId/comments)
app.post(['/api/posts/:postId/comments', '/posts/:postId/comments'], async (req, res) => {
  try {
    const { postId } = req.params;
    const { content, displayName, clientId, userIP } = req.body;

    // Get client IP for rate limiting
    const clientIP = req.ip || req.connection.remoteAddress || req.socket.remoteAddress || 'unknown';

    // Check rate limit
    checkCommentRateLimit(clientIP);

    // Validate and clean input
    const cleanContent = validateComment(content, displayName);

    // Check for duplicate comments (same content in last hour)
    const duplicateCheck = await pool.query(
      'SELECT id FROM comments WHERE content = $1 AND post_id = $2 AND created_at > NOW() - INTERVAL \'1 hour\'',
      [cleanContent, postId]
    );

    if (duplicateCheck.rows.length > 0) {
      return res.status(400).json({ error: 'Duplicate comment detected. Please wait before posting similar content.' });
    }

    // Generate display name if not provided
    const finalDisplayName = displayName || 'Anonymous';
    const finalClientId = clientId || generateClientId();
    const ipHash = userIP ? hashIP(userIP) : hashIP(clientIP);

    const result = await pool.query(
      'INSERT INTO comments (post_id, display_name, content, client_id, ip_hash, created_at) VALUES ($1, $2, $3, $4, $5, NOW()) RETURNING id, created_at',
      [postId, finalDisplayName, cleanContent, finalClientId, ipHash]
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

    // Handle validation errors with 400 status
    if (error.message.includes('Comment must be') ||
      error.message.includes('Display name must be') ||
      error.message.includes('inappropriate content') ||
      error.message.includes('excessive repetition') ||
      error.message.includes('Too many comments') ||
      error.message.includes('Duplicate comment')) {
      return res.status(400).json({ error: error.message });
    }

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

// Newsletter subscription endpoints

// Email validation function
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
}

// Subscribe to newsletter
app.post(['/api/newsletter/subscribe', '/newsletter/subscribe'], async (req, res) => {
  try {
    const { email } = req.body;

    // Validate input
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check if already subscribed
    const existingSubscription = await pool.query(
      'SELECT id, status, bounce_count FROM newsletter_subscriptions WHERE email = $1',
      [normalizedEmail]
    );

    if (existingSubscription.rows.length > 0) {
      const subscription = existingSubscription.rows[0];

      // If already active, return success
      if (subscription.status === 'active') {
        return res.json({
          success: true,
          message: 'Email is already subscribed to newsletter',
          alreadySubscribed: true
        });
      }

      // If unsubscribed, reactivate
      if (subscription.status === 'unsubscribed') {
        await pool.query(
          'UPDATE newsletter_subscriptions SET status = $1, subscribed_at = NOW(), unsubscribed_at = NULL, updated_at = NOW() WHERE email = $2',
          ['active', normalizedEmail]
        );

        newsletterSubscriptions.inc({ status: 'reactivated' });
        logger.info(`Newsletter subscription reactivated: ${normalizedEmail}`);

        return res.json({
          success: true,
          message: 'Newsletter subscription reactivated successfully',
          reactivated: true
        });
      }

      // If bounced, don't allow subscription
      if (subscription.status === 'bounced') {
        return res.status(400).json({
          error: 'This email address has been blocked due to previous bounces',
          bounceCount: subscription.bounce_count
        });
      }
    }

    // Create new subscription
    await pool.query(
      'INSERT INTO newsletter_subscriptions (email, status, subscribed_at, verified) VALUES ($1, $2, NOW(), $3)',
      [normalizedEmail, 'active', false]
    );

    newsletterSubscriptions.inc({ status: 'new' });
    logger.info(`New newsletter subscription: ${normalizedEmail}`);

    res.json({
      success: true,
      message: 'Successfully subscribed to newsletter',
      email: normalizedEmail
    });

  } catch (error) {
    logger.error('Error subscribing to newsletter', error);
    res.status(500).json({ error: error.message });
  }
});

// Unsubscribe from newsletter
app.post(['/api/newsletter/unsubscribe', '/newsletter/unsubscribe'], async (req, res) => {
  try {
    const { email } = req.body;

    // Validate input
    if (!email) {
      return res.status(400).json({ error: 'Email is required' });
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check if subscribed
    const existingSubscription = await pool.query(
      'SELECT id, status FROM newsletter_subscriptions WHERE email = $1',
      [normalizedEmail]
    );

    if (existingSubscription.rows.length === 0) {
      return res.status(404).json({
        error: 'Email not found in newsletter subscriptions',
        notFound: true
      });
    }

    const subscription = existingSubscription.rows[0];

    if (subscription.status === 'unsubscribed') {
      return res.json({
        success: true,
        message: 'Email is already unsubscribed',
        alreadyUnsubscribed: true
      });
    }

    // Unsubscribe
    await pool.query(
      'UPDATE newsletter_subscriptions SET status = $1, unsubscribed_at = NOW(), updated_at = NOW() WHERE email = $2',
      ['unsubscribed', normalizedEmail]
    );

    newsletterUnsubscriptions.inc();
    logger.info(`Newsletter unsubscription: ${normalizedEmail}`);

    res.json({
      success: true,
      message: 'Successfully unsubscribed from newsletter',
      email: normalizedEmail
    });

  } catch (error) {
    logger.error('Error unsubscribing from newsletter', error);
    res.status(500).json({ error: error.message });
  }
});

// Get subscription status
app.get(['/api/newsletter/status', '/newsletter/status'], async (req, res) => {
  try {
    const { email } = req.query;

    if (!email) {
      return res.status(400).json({ error: 'Email parameter is required' });
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    const normalizedEmail = email.toLowerCase().trim();

    const result = await pool.query(
      'SELECT email, status, subscribed_at, unsubscribed_at, bounce_count, verified FROM newsletter_subscriptions WHERE email = $1',
      [normalizedEmail]
    );

    if (result.rows.length === 0) {
      return res.json({
        subscribed: false,
        status: 'not_found',
        message: 'Email not found in newsletter subscriptions'
      });
    }

    const subscription = result.rows[0];
    res.json({
      subscribed: subscription.status === 'active',
      status: subscription.status,
      subscribedAt: subscription.subscribed_at,
      unsubscribedAt: subscription.unsubscribed_at,
      bounceCount: subscription.bounce_count,
      verified: subscription.verified
    });

  } catch (error) {
    logger.error('Error checking newsletter status', error);
    res.status(500).json({ error: error.message });
  }
});

// Feedback submission endpoints

// Generate random name for anonymous feedback
function generateRandomName() {
  const adjectives = ['Happy', 'Curious', 'Creative', 'Bright', 'Kind', 'Wise', 'Brave', 'Gentle', 'Smart', 'Cheerful'];
  const nouns = ['Reader', 'Visitor', 'Explorer', 'Learner', 'Friend', 'Guest', 'Fan', 'Supporter', 'Enthusiast', 'Admirer'];
  const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
  const noun = nouns[Math.floor(Math.random() * nouns.length)];
  return `${adjective} ${noun}`;
}

// Rate limiting for feedback (10 per minute per UUID)
const feedbackRateLimit = new Map();

function checkFeedbackRateLimit(uuid) {
  const now = Date.now();
  const minute = Math.floor(now / 60000); // Current minute

  if (!feedbackRateLimit.has(uuid)) {
    feedbackRateLimit.set(uuid, { minute: minute, count: 0 });
  }

  const userLimit = feedbackRateLimit.get(uuid);

  // Reset if it's a new minute
  if (userLimit.minute !== minute) {
    userLimit.minute = minute;
    userLimit.count = 0;
  }

  // Check if limit exceeded
  if (userLimit.count >= 10) {
    return false;
  }

  // Increment count
  userLimit.count++;
  return true;
}

// Submit feedback
app.post(['/api/feedback', '/feedback'], async (req, res) => {
  try {
    const { uuid, name, email, rating, feedback_text } = req.body;
    const userIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent');

    // Validate required fields
    if (!uuid) {
      return res.status(400).json({ error: 'UUID is required' });
    }

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating is required and must be between 1 and 5' });
    }

    if (!feedback_text || feedback_text.trim().length === 0) {
      return res.status(400).json({ error: 'Feedback text is required' });
    }

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(uuid)) {
      return res.status(400).json({ error: 'Invalid UUID format' });
    }

    // Check rate limit
    if (!checkFeedbackRateLimit(uuid)) {
      feedbackRateLimitHits.inc();
      logger.warn(`Feedback rate limit exceeded for UUID: ${uuid}`);
      return res.status(429).json({
        error: 'Rate limit exceeded. Maximum 10 feedback submissions per minute per user.',
        retryAfter: 60
      });
    }

    // Generate name if not provided
    const finalName = name && name.trim() ? name.trim() : generateRandomName();

    // Validate email if provided
    let finalEmail = null;
    if (email && email.trim()) {
      if (!isValidEmail(email)) {
        return res.status(400).json({ error: 'Invalid email format' });
      }
      finalEmail = email.toLowerCase().trim();
    }

    // Insert feedback
    const result = await pool.query(
      'INSERT INTO feedback (uuid, name, email, rating, feedback_text, ip_address, user_agent) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at',
      [uuid, finalName, finalEmail, rating, feedback_text.trim(), userIP, userAgent]
    );

    feedbackSubmissions.inc({ rating: rating.toString() });
    logger.info(`Feedback submitted: UUID=${uuid}, Rating=${rating}, Name=${finalName}`);

    res.json({
      success: true,
      message: 'Feedback submitted successfully',
      feedbackId: result.rows[0].id,
      submittedAt: result.rows[0].created_at,
      name: finalName
    });

  } catch (error) {
    logger.error('Error submitting feedback', error);
    res.status(500).json({ error: error.message });
  }
});

// Get feedback statistics (admin endpoint)
app.get(['/api/feedback/stats', '/feedback/stats'], async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        COUNT(*) as total_feedback,
        AVG(rating) as average_rating,
        COUNT(CASE WHEN rating = 5 THEN 1 END) as five_star,
        COUNT(CASE WHEN rating = 4 THEN 1 END) as four_star,
        COUNT(CASE WHEN rating = 3 THEN 1 END) as three_star,
        COUNT(CASE WHEN rating = 2 THEN 1 END) as two_star,
        COUNT(CASE WHEN rating = 1 THEN 1 END) as one_star,
        COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
        COUNT(CASE WHEN status = 'reviewed' THEN 1 END) as reviewed
      FROM feedback
    `);

    const stats = result.rows[0];
    res.json({
      totalFeedback: parseInt(stats.total_feedback),
      averageRating: parseFloat(stats.average_rating).toFixed(2),
      ratingDistribution: {
        fiveStar: parseInt(stats.five_star),
        fourStar: parseInt(stats.four_star),
        threeStar: parseInt(stats.three_star),
        twoStar: parseInt(stats.two_star),
        oneStar: parseInt(stats.one_star)
      },
      statusDistribution: {
        pending: parseInt(stats.pending),
        reviewed: parseInt(stats.reviewed)
      }
    });

  } catch (error) {
    logger.error('Error getting feedback stats', error);
    res.status(500).json({ error: error.message });
  }
});

// Get recent feedback (admin endpoint)
app.get(['/api/feedback/recent', '/feedback/recent'], async (req, res) => {
  try {
    const { limit = 10, status = 'all' } = req.query;
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));

    let query = 'SELECT id, uuid, name, email, rating, feedback_text, created_at, status FROM feedback';
    let params = [];

    if (status !== 'all') {
      query += ' WHERE status = $1';
      params.push(status);
    }

    query += ' ORDER BY created_at DESC LIMIT $' + (params.length + 1);
    params.push(limitNum);

    const result = await pool.query(query, params);

    res.json({
      feedback: result.rows,
      count: result.rows.length,
      limit: limitNum,
      status: status
    });

  } catch (error) {
    logger.error('Error getting recent feedback', error);
    res.status(500).json({ error: error.message });
  }
});

// Analytics tracking endpoints

// Track analytics event
app.post(['/api/analytics/track', '/analytics/track'], async (req, res) => {
  try {
    const {
      uuid,
      session_id,
      event_type,
      event_name,
      page_url,
      page_title,
      element_id,
      element_class,
      element_text,
      element_type,
      click_x,
      click_y,
      viewport_width,
      viewport_height,
      scroll_depth,
      time_on_page,
      metadata
    } = req.body;

    const userIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent');
    const referrer = req.get('Referer');

    // Validate required fields
    if (!uuid || !session_id || !event_type) {
      return res.status(400).json({ error: 'uuid, session_id, and event_type are required' });
    }

    // Validate UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(uuid) || !uuidRegex.test(session_id)) {
      return res.status(400).json({ error: 'Invalid UUID format' });
    }

    // Insert analytics event
    const result = await pool.query(`
      INSERT INTO analytics_events (
        uuid, session_id, event_type, event_name, page_url, page_title,
        element_id, element_class, element_text, element_type,
        click_x, click_y, viewport_width, viewport_height,
        scroll_depth, time_on_page, referrer, user_agent, ip_address, metadata
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
      RETURNING id, created_at
    `, [
      uuid, session_id, event_type, event_name, page_url, page_title,
      element_id, element_class, element_text, element_type,
      click_x, click_y, viewport_width, viewport_height,
      scroll_depth, time_on_page, referrer, userAgent, userIP,
      metadata ? JSON.stringify(metadata) : null
    ]);

    // Update Prometheus metrics
    if (event_type === 'pageview') {
      pageViews.inc({ page_url: page_url || 'unknown', device_type: 'unknown' });
    } else if (event_type === 'click') {
      clicks.inc({ element_type: element_type || 'unknown', element_id: element_id || 'unknown' });
    }

    logger.info(`Analytics event tracked: ${event_type} for UUID ${uuid}`);

    res.json({
      success: true,
      eventId: result.rows[0].id,
      timestamp: result.rows[0].created_at
    });

  } catch (error) {
    logger.error('Error tracking analytics event', error);
    res.status(500).json({ error: error.message });
  }
});

// Start or update user session
app.post(['/api/analytics/session', '/analytics/session'], async (req, res) => {
  try {
    const {
      session_id,
      uuid,
      entry_page,
      referrer,
      device_type,
      browser,
      os,
      country,
      city
    } = req.body;

    const userIP = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('User-Agent');

    if (!session_id || !uuid) {
      return res.status(400).json({ error: 'session_id and uuid are required' });
    }

    // Check if session exists
    const existingSession = await pool.query(
      'SELECT id FROM user_sessions WHERE session_id = $1',
      [session_id]
    );

    if (existingSession.rows.length === 0) {
      // Create new session
      await pool.query(`
        INSERT INTO user_sessions (
          session_id, uuid, entry_page, referrer, user_agent, ip_address,
          device_type, browser, os, country, city
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [session_id, uuid, entry_page, referrer, userAgent, userIP, device_type, browser, os, country, city]);

      userSessions.inc({ device_type: device_type || 'unknown', browser: browser || 'unknown' });
      logger.info(`New session started: ${session_id} for UUID ${uuid}`);
    } else {
      // Update existing session
      await pool.query(
        'UPDATE user_sessions SET updated_at = NOW() WHERE session_id = $1',
        [session_id]
      );
    }

    res.json({ success: true });

  } catch (error) {
    logger.error('Error managing user session', error);
    res.status(500).json({ error: error.message });
  }
});

// End user session
app.post(['/api/analytics/session/end', '/analytics/session/end'], async (req, res) => {
  try {
    const { session_id, exit_page, total_time, page_views, clicks, scroll_depth } = req.body;

    if (!session_id) {
      return res.status(400).json({ error: 'session_id is required' });
    }

    await pool.query(`
      UPDATE user_sessions 
      SET 
        end_time = NOW(),
        exit_page = $2,
        total_time_on_site = $3,
        page_views = $4,
        total_clicks = $5,
        total_scroll_depth = $6,
        is_bounce = CASE WHEN $4 <= 1 AND $3 < 30 THEN true ELSE false END,
        updated_at = NOW()
      WHERE session_id = $1
    `, [session_id, exit_page, total_time, page_views, clicks, scroll_depth]);

    logger.info(`Session ended: ${session_id}`);
    res.json({ success: true });

  } catch (error) {
    logger.error('Error ending user session', error);
    res.status(500).json({ error: error.message });
  }
});

// Get analytics dashboard data
app.get(['/api/analytics/dashboard', '/analytics/dashboard'], async (req, res) => {
  try {
    const { days = 7 } = req.query;
    const daysNum = Math.min(365, Math.max(1, parseInt(days)));

    // Get page views
    const pageViewsResult = await pool.query(`
      SELECT page_url, COUNT(*) as views
      FROM analytics_events 
      WHERE event_type = 'pageview' 
        AND created_at >= NOW() - INTERVAL '${daysNum} days'
      GROUP BY page_url
      ORDER BY views DESC
      LIMIT 10
    `);

    // Get top clicked elements
    const clicksResult = await pool.query(`
      SELECT element_type, element_id, COUNT(*) as clicks
      FROM analytics_events 
      WHERE event_type = 'click' 
        AND created_at >= NOW() - INTERVAL '${daysNum} days'
      GROUP BY element_type, element_id
      ORDER BY clicks DESC
      LIMIT 10
    `);

    // Get session statistics
    const sessionStats = await pool.query(`
      SELECT 
        COUNT(*) as total_sessions,
        AVG(total_time_on_site) as avg_session_duration,
        COUNT(CASE WHEN is_bounce THEN 1 END) * 100.0 / COUNT(*) as bounce_rate,
        COUNT(CASE WHEN device_type = 'mobile' THEN 1 END) as mobile_sessions,
        COUNT(CASE WHEN device_type = 'desktop' THEN 1 END) as desktop_sessions
      FROM user_sessions 
      WHERE created_at >= NOW() - INTERVAL '${daysNum} days'
    `);

    // Get hourly page views
    const hourlyViews = await pool.query(`
      SELECT 
        EXTRACT(HOUR FROM created_at) as hour,
        COUNT(*) as views
      FROM analytics_events 
      WHERE event_type = 'pageview' 
        AND created_at >= NOW() - INTERVAL '${daysNum} days'
      GROUP BY EXTRACT(HOUR FROM created_at)
      ORDER BY hour
    `);

    res.json({
      period: `${daysNum} days`,
      pageViews: pageViewsResult.rows,
      topClicks: clicksResult.rows,
      sessionStats: sessionStats.rows[0],
      hourlyViews: hourlyViews.rows
    });

  } catch (error) {
    logger.error('Error getting analytics dashboard', error);
    res.status(500).json({ error: error.message });
  }
});

// Prometheus metrics endpoint - receive metrics from frontend and forward to Prometheus
app.post(['/api/analytics/prometheus', '/analytics/prometheus'], async (req, res) => {
  try {
    const { metrics, job = 'blog-frontend', instance = 'default' } = req.body;

    if (!metrics || !Array.isArray(metrics)) {
      return res.status(400).json({ error: 'Metrics array is required' });
    }

    // Format metrics for Prometheus Pushgateway
    const prometheusMetrics = metrics.map(metric => {
      const { name, value, labels = {}, help = '' } = metric;

      // Build metric line for Prometheus format
      let metricLine = `# HELP ${name} ${help}\n# TYPE ${name} ${metric.type || 'counter'}\n`;

      // Build labels string
      const labelPairs = Object.entries({ instance, ...labels })
        .map(([key, val]) => `${key}="${val}"`)
        .join(',');

      // Add metric value
      metricLine += `${name}{${labelPairs}} ${value}`;

      return metricLine;
    }).join('\n');

    // Forward to Prometheus Pushgateway
    const pushgatewayUrl = process.env.PROMETHEUS_PUSHGATEWAY_URL || 'http://prometheus-service:9091';
    const targetUrl = `${pushgatewayUrl}/metrics/job/${job}/instance/${instance}`;

    try {
      const response = await fetch(targetUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'text/plain; charset=utf-8',
          'Content-Encoding': 'identity'
        },
        body: prometheusMetrics
      });

      if (!response.ok) {
        logger.warn(`Prometheus push failed: ${response.status} ${response.statusText}`);
        // Don't fail the request if Prometheus is down
      } else {
        logger.info(`Successfully pushed ${metrics.length} metrics to Prometheus`);
      }
    } catch (prometheusError) {
      logger.error('Error pushing to Prometheus:', prometheusError);
      // Don't fail the request if Prometheus is unreachable
    }

    // Store metrics in database for backup
    for (const metric of metrics) {
      try {
        await pool.query(`
          INSERT INTO analytics_events (uuid, session_id, event_type, page_url, metadata, created_at)
          VALUES ($1, $2, 'prometheus_metric', $3, $4, NOW())
        `, [
          metric.uuid || 'unknown',
          metric.session_id || 'unknown',
          metric.page_url || '/',
          JSON.stringify(metric)
        ]);
      } catch (dbError) {
        logger.error('Error storing metric in database:', dbError);
      }
    }

    res.json({
      success: true,
      message: `Processed ${metrics.length} metrics`,
      prometheusStatus: 'forwarded',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    logger.error('Error processing Prometheus metrics', error);
    res.status(500).json({ error: error.message });
  }
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
