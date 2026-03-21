-- +goose Up
CREATE TABLE chores (
  id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title        TEXT NOT NULL,
  category     TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('general', 'kitchen', 'bathroom', 'outdoor')),
  status       TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'claimed', 'completed')),
  note         TEXT,
  claimed_by   UUID REFERENCES users(id),
  claimed_at   TIMESTAMPTZ,
  completed_by UUID REFERENCES users(id),
  completed_at TIMESTAMPTZ,
  created_by   UUID NOT NULL REFERENCES users(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chores_status     ON chores(status);
CREATE INDEX idx_chores_created_by ON chores(created_by);

CREATE TRIGGER chores_updated_at
  BEFORE UPDATE ON chores
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS chores;