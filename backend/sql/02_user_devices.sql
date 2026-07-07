-- 02_user_devices.sql

-- Create the user_devices table
CREATE TABLE IF NOT EXISTS user_devices (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token                 TEXT NOT NULL,
  device_id                 TEXT NOT NULL,
  device_name               TEXT,
  manufacturer              TEXT,
  model                     TEXT,
  platform                  TEXT NOT NULL DEFAULT 'android',
  os_version                TEXT,
  app_version               TEXT,
  notification_status       TEXT NOT NULL DEFAULT 'active'
                              CHECK (notification_status IN ('active','invalid')),
  app_status                TEXT NOT NULL DEFAULT 'active'
                              CHECK (app_status IN ('active','inactive','possible_uninstalled')),
  last_seen_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_notification_sent_at TIMESTAMPTZ,
  last_notification_status  TEXT,
  uninstall_detected_at     TIMESTAMPTZ,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for fast lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_device_token ON user_devices(device_id, user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_devices_fcm_token    ON user_devices(fcm_token);
CREATE INDEX IF NOT EXISTS idx_user_devices_user_id             ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_app_status          ON user_devices(app_status);
CREATE INDEX IF NOT EXISTS idx_user_devices_last_seen           ON user_devices(last_seen_at);
