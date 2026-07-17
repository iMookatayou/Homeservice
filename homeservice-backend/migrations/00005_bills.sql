-- +goose Up
CREATE TABLE bills (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type       TEXT NOT NULL CHECK (type IN ('electric', 'water', 'internet', 'phone', 'other')),
  title      TEXT NOT NULL,
  amount     NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  due_date   TIMESTAMPTZ NOT NULL,
  status     TEXT NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid')),
  paid_at    TIMESTAMPTZ,
  note       TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_bills_status     ON bills(status);
CREATE INDEX idx_bills_due_date   ON bills(due_date);
CREATE INDEX idx_bills_created_by ON bills(created_by);

CREATE TRIGGER bills_updated_at
  BEFORE UPDATE ON bills
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS bills;