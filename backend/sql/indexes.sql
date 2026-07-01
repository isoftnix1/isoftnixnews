-- =============================================================
-- Phase 5.8 – Database Performance Indexes Migration
-- Run once against the production database.
-- All statements use IF NOT EXISTS so this file is safe to re-run.
-- =============================================================

-- news table: primary feed sort + filter
CREATE INDEX IF NOT EXISTS idx_news_created_at     ON news(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_news_category_id    ON news(category_id);
CREATE INDEX IF NOT EXISTS idx_news_is_published   ON news(is_published);

-- Composite: published articles sorted by date (most common query)
CREATE INDEX IF NOT EXISTS idx_news_published_date ON news(is_published, created_at DESC);

-- users table: login lookup
CREATE INDEX IF NOT EXISTS idx_users_email         ON users(email);

-- notifications table: per-user inbox + sorted list
CREATE INDEX IF NOT EXISTS idx_notifications_user_id    ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- device_tokens table: FCM push by user
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);

-- news_categories junction table: both directions
CREATE INDEX IF NOT EXISTS idx_news_categories_news_id     ON news_categories(news_id);
CREATE INDEX IF NOT EXISTS idx_news_categories_category_id ON news_categories(category_id);
