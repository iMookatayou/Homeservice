-- +goose Up
CREATE TABLE medicine_items (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  form        TEXT,
  unit        TEXT,
  category    TEXT,
  stock_qty   NUMERIC(10,2) NOT NULL DEFAULT 0,
  expiry_date DATE,
  location    TEXT,
  note        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE medicine_alerts (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id            UUID NOT NULL UNIQUE REFERENCES medicine_items(id) ON DELETE CASCADE,
  min_qty            NUMERIC(10,2),
  expiry_window_days INT,
  is_enabled         BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX idx_medicine_items_name ON medicine_items(name);

CREATE TRIGGER medicine_items_updated_at
  BEFORE UPDATE ON medicine_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS medicine_alerts;
DROP TABLE IF EXISTS medicine_items;