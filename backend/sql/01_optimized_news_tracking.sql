-- Database Schema Updates for News Engagement & Reminders

-- 1. Create news_views table
CREATE TABLE IF NOT EXISTS news_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    news_id UUID NOT NULL REFERENCES news(id) ON DELETE CASCADE,
    viewed_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, news_id)
);

-- 2. Create notification_delivery table
CREATE TABLE IF NOT EXISTS notification_delivery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    news_id UUID NOT NULL REFERENCES news(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL, -- 'initial' or 'reminder'
    status VARCHAR(20) NOT NULL, -- 'pending', 'processing', 'success', 'failed'
    sent_at TIMESTAMP,
    error_message TEXT,
    device_type VARCHAR(20),
    retry_count INT DEFAULT 0,
    next_retry_at TIMESTAMP,
    UNIQUE(user_id, news_id, type)
);

-- 3. Create scheduler_runs table
CREATE TABLE IF NOT EXISTS scheduler_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    triggered_by VARCHAR(20) NOT NULL, -- 'cron', 'manual', 'retry'
    started_at TIMESTAMP NOT NULL DEFAULT NOW(),
    finished_at TIMESTAMP,
    news_processed INT DEFAULT 0,
    notifications_sent INT DEFAULT 0,
    notifications_failed INT DEFAULT 0,
    execution_time_ms BIGINT,
    status VARCHAR(20) NOT NULL -- 'SUCCESS', 'FAILED'
);

-- 4. Alter news table
ALTER TABLE news 
ADD COLUMN IF NOT EXISTS views_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS reminder_sent_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS reminder_status VARCHAR(20) DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS published_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS last_reminder_attempt_at TIMESTAMP;

-- Set published_at to created_at for existing records
UPDATE news SET published_at = created_at WHERE published_at IS NULL;

-- 5. Create Indexes
CREATE INDEX IF NOT EXISTS idx_news_views_user_id ON news_views(user_id);
CREATE INDEX IF NOT EXISTS idx_news_views_news_id ON news_views(news_id);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_news_id ON notification_delivery(news_id);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_user_id ON notification_delivery(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_delivery_status_next_retry_at ON notification_delivery(status, next_retry_at);
CREATE INDEX IF NOT EXISTS idx_news_published_at ON news(published_at);
CREATE INDEX IF NOT EXISTS idx_news_reminder_status ON news(reminder_status);
