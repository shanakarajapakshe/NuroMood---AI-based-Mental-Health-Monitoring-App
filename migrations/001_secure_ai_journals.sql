-- NeuroMood production schema additions for PostgreSQL.
-- Run after creating the base users table. Passwords should be stored as hashes,
-- never as plaintext.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS password_hash TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS subscription_tier TEXT NOT NULL DEFAULT 'free',
  ADD COLUMN IF NOT EXISTS premium_until TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS user_streaks (
  user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  current_streak INTEGER NOT NULL DEFAULT 0,
  longest_streak INTEGER NOT NULL DEFAULT 0,
  last_journal_date DATE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS journals_secure (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  encrypted_text TEXT NOT NULL,
  encryption_iv TEXT NOT NULL,
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  model_text_hash TEXT NOT NULL,
  primary_emotion TEXT NOT NULL,
  confidence NUMERIC(5, 4) NOT NULL CHECK (confidence >= 0 AND confidence <= 1),
  emotion_scores JSONB NOT NULL DEFAULT '{}'::jsonb,
  trigger_words JSONB NOT NULL DEFAULT '[]'::jsonb,
  trigger_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
  sentiment_shifts JSONB NOT NULL DEFAULT '{}'::jsonb,
  image_path TEXT,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journals_secure_user_created
  ON journals_secure(user_id, created_at DESC)
  WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_journals_secure_emotion
  ON journals_secure(user_id, primary_emotion, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_journals_secure_triggers
  ON journals_secure USING GIN(trigger_categories);

CREATE TABLE IF NOT EXISTS crisis_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  journal_id UUID REFERENCES journals_secure(id) ON DELETE SET NULL,
  signal TEXT NOT NULL,
  confidence NUMERIC(5, 4) NOT NULL,
  user_action TEXT NOT NULL DEFAULT 'shown',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crisis_events_user_created
  ON crisis_events(user_id, created_at DESC);

CREATE OR REPLACE FUNCTION update_journal_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_journals_secure_updated_at ON journals_secure;
CREATE TRIGGER trg_journals_secure_updated_at
BEFORE UPDATE ON journals_secure
FOR EACH ROW EXECUTE FUNCTION update_journal_updated_at();
