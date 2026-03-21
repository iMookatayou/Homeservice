-- +goose Up
CREATE TABLE purchases (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title            TEXT NOT NULL,
  note             TEXT,
  items            JSONB NOT NULL DEFAULT '[]',
  amount_estimated NUMERIC(14,2),
  amount_paid      NUMERIC(14,2),
  currency         TEXT NOT NULL DEFAULT 'THB',
  category         TEXT,
  store            TEXT,
  status           TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'ordered', 'bought', 'delivered', 'cancelled')),
  requester_id     UUID NOT NULL REFERENCES users(id),
  buyer_id         UUID REFERENCES users(id),
  editable_until   TIMESTAMPTZ NOT NULL DEFAULT now() + INTERVAL '10 minutes',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_purchases_status       ON purchases(status);
CREATE INDEX idx_purchases_requester_id ON purchases(requester_id);
CREATE INDEX idx_purchases_buyer_id     ON purchases(buyer_id);

CREATE TRIGGER purchases_updated_at
  BEFORE UPDATE ON purchases
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS purchases;