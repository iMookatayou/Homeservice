-- +goose Up
CREATE TABLE contractors (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name            TEXT NOT NULL,
  types           TEXT[] NOT NULL DEFAULT '{}',
  phone           TEXT,
  address         TEXT,
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  google_maps_url TEXT,
  note            TEXT,
  is_favorite     BOOLEAN NOT NULL DEFAULT false,
  created_by      UUID NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contractors_is_favorite ON contractors(is_favorite);
CREATE INDEX idx_contractors_created_by  ON contractors(created_by);

CREATE TRIGGER contractors_updated_at
  BEFORE UPDATE ON contractors
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS contractors;