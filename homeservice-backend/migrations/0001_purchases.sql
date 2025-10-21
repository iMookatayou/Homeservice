-- enums
DO $$ BEGIN
  CREATE TYPE purchase_priority AS ENUM ('low','medium','high','urgent');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE purchase_status AS ENUM ('draft','requested','approved','rejected','purchased','cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- trigger function
CREATE OR REPLACE FUNCTION trg_touch_updated_at() RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

-- requests
CREATE TABLE IF NOT EXISTS purchase_requests (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL,
  title            TEXT NOT NULL,
  description      TEXT,
  priority         purchase_priority NOT NULL DEFAULT 'medium',
  status           purchase_status   NOT NULL DEFAULT 'requested',
  price_estimate   NUMERIC(14,2),
  media_urls       TEXT[] NOT NULL DEFAULT '{}',
  notes_admin      TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_user_id ON purchase_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_status  ON purchase_requests(status);
CREATE INDEX IF NOT EXISTS idx_purchase_requests_created ON purchase_requests(created_at DESC);
DROP TRIGGER IF EXISTS purchase_requests_touch ON purchase_requests;
CREATE TRIGGER purchase_requests_touch BEFORE UPDATE ON purchase_requests
FOR EACH ROW EXECUTE FUNCTION trg_touch_updated_at();

-- items
CREATE TABLE IF NOT EXISTS purchase_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id       UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  qty              NUMERIC(12,2) NOT NULL DEFAULT 1,
  unit             TEXT NOT NULL DEFAULT 'item',
  price_estimate   NUMERIC(14,2),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_purchase_items_req ON purchase_items(request_id);
DROP TRIGGER IF EXISTS purchase_items_touch ON purchase_items;
CREATE TRIGGER purchase_items_touch BEFORE UPDATE ON purchase_items
FOR EACH ROW EXECUTE FUNCTION trg_touch_updated_at();

-- messages
CREATE TABLE IF NOT EXISTS purchase_messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id  UUID NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL,
  body        TEXT NOT NULL,
  media_urls  TEXT[] NOT NULL DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_purchase_messages_req ON purchase_messages(request_id);
DROP TRIGGER IF EXISTS purchase_messages_touch ON purchase_messages;
CREATE TRIGGER purchase_messages_touch BEFORE UPDATE ON purchase_messages
FOR EACH ROW EXECUTE FUNCTION trg_touch_updated_at();
