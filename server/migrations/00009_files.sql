-- +goose Up
CREATE TABLE files (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  filename   TEXT NOT NULL,
  mime       TEXT NOT NULL,
  size       BIGINT NOT NULL CHECK (size > 0),
  url        TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_files_owner_id ON files(owner_id);

-- +goose Down
DROP TABLE IF EXISTS files;