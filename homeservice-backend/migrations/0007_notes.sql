-- 0006_notes.sql
CREATE TABLE IF NOT EXISTS notes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  body        TEXT NOT NULL,
  tags        TEXT[] NOT NULL DEFAULT '{}',
  link        TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notes_created_at_desc ON notes (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_tags_gin ON notes USING GIN (tags);

-- updated_at auto
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notes_updated_at ON notes;
CREATE TRIGGER trg_notes_updated_at
BEFORE UPDATE ON notes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- (optional) seed demo
INSERT INTO notes (title, body, tags, link)
VALUES
('Uploads module is LIVE ✅',
 'อัปโหลดผ่าน POST /api/v1/uploads (JWT + form-data:file)\nbytes/size และ mime sync ผ่าน trigger files_before_write',
 ARRAY['uploads','trigger','jwt'],
 'http://localhost:8080/static/')
ON CONFLICT DO NOTHING;
