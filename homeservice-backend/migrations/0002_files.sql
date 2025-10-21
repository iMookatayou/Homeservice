-- +goose Up
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS files (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filename    text NOT NULL,
  mimetype    text NOT NULL,
  size        bigint NOT NULL CHECK (size > 0),
  storage_url text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_files_owner_created ON files(owner_id, created_at DESC);

-- +goose Down
DROP TABLE IF EXISTS files;
