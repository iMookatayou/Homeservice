-- purchase_attachments: link files <-> purchase_requests

CREATE TABLE IF NOT EXISTS purchase_attachments (
  purchase_id uuid NOT NULL REFERENCES purchase_requests(id) ON DELETE CASCADE,
  file_id     uuid NOT NULL REFERENCES files(id)            ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (purchase_id, file_id)
);

CREATE INDEX IF NOT EXISTS idx_purchase_attachments_file
  ON purchase_attachments(file_id);
