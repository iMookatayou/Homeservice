-- purchase_attachments: link files <-> purchases
-- ใช้เชื่อมตาราง purchases (คำขอซื้อ) กับ files (รูปภาพ/สลิปแนบ)

CREATE TABLE IF NOT EXISTS purchase_attachments (
  purchase_id uuid NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  file_id     uuid NOT NULL REFERENCES files(id)     ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (purchase_id, file_id)
);

-- index ช่วยค้นหาเร็วขึ้น
CREATE INDEX IF NOT EXISTS idx_purchase_attachments_purchase
  ON purchase_attachments(purchase_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_purchase_attachments_file
  ON purchase_attachments(file_id);
