-- Create tables for blog backend
CREATE TABLE IF NOT EXISTS likes (
    id SERIAL PRIMARY KEY,
    post_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255),
    user_ip INET,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(post_id, user_id),
    UNIQUE(post_id, user_ip)
);

CREATE TABLE IF NOT EXISTS comments (
    id SERIAL PRIMARY KEY,
    post_id VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    author_name VARCHAR(255) NOT NULL,
    author_email VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS newsletter_subscriptions (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'unsubscribed', 'bounced')),
    subscribed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    unsubscribed_at TIMESTAMP NULL,
    bounce_count INTEGER DEFAULT 0,
    last_bounce_at TIMESTAMP NULL,
    verification_token VARCHAR(255) NULL,
    verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS feedback (
    id SERIAL PRIMARY KEY,
    uuid VARCHAR(36) NOT NULL,
    name VARCHAR(255),
    email VARCHAR(255),
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    feedback_text TEXT NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'archived'))
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON likes(post_id);
CREATE INDEX IF NOT EXISTS idx_likes_created_at ON likes(created_at);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON comments(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_created_at ON comments(created_at);
CREATE INDEX IF NOT EXISTS idx_newsletter_email ON newsletter_subscriptions(email);
CREATE INDEX IF NOT EXISTS idx_newsletter_status ON newsletter_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_newsletter_created_at ON newsletter_subscriptions(created_at);
CREATE INDEX IF NOT EXISTS idx_feedback_uuid ON feedback(uuid);
CREATE INDEX IF NOT EXISTS idx_feedback_rating ON feedback(rating);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback(status);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback(created_at);
CREATE INDEX IF NOT EXISTS idx_feedback_uuid_created ON feedback(uuid, created_at);

-- Insert some sample data
INSERT INTO likes (post_id, user_id, user_ip) VALUES 
('sample-post-1', 'user1', '192.168.1.1'),
('sample-post-1', 'user2', '192.168.1.2'),
('sample-post-2', 'user3', '192.168.1.3')
ON CONFLICT DO NOTHING;

INSERT INTO comments (post_id, content, author_name, author_email) VALUES 
('sample-post-1', 'Great article!', 'John Doe', 'john@example.com'),
('sample-post-1', 'Very informative', 'Jane Smith', 'jane@example.com'),
('sample-post-2', 'Thanks for sharing', 'Bob Johnson', 'bob@example.com')
ON CONFLICT DO NOTHING;

-- Insert sample newsletter subscriptions
INSERT INTO newsletter_subscriptions (email, status, subscribed_at, verified) VALUES 
('newsletter@example.com', 'active', NOW(), true),
('subscriber@example.com', 'active', NOW(), false),
('unsubscribed@example.com', 'unsubscribed', NOW() - INTERVAL '7 days', true)
ON CONFLICT (email) DO NOTHING;

-- Insert sample feedback
INSERT INTO feedback (uuid, name, email, rating, feedback_text, ip_address, status) VALUES 
('550e8400-e29b-41d4-a716-446655440000', 'John Doe', 'john@example.com', 5, 'Great blog! Love the content and design.', '192.168.1.100', 'reviewed'),
('550e8400-e29b-41d4-a716-446655440001', 'Jane Smith', 'jane@example.com', 4, 'Very informative articles. Keep up the good work!', '192.168.1.101', 'pending'),
('550e8400-e29b-41d4-a716-446655440002', NULL, NULL, 3, 'Good content but could use more images.', '192.168.1.102', 'pending')
ON CONFLICT DO NOTHING;
