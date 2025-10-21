-- Ensure extensions
CREATE EXTENSION IF NOT EXISTS plpgsql;

-- Ensure schema safety
ALTER TABLE files
  ALTER COLUMN bytes DROP NOT NULL,
  ALTER COLUMN bytes SET DEFAULT 0,
  ALTER COLUMN mime SET DEFAULT 'application/octet-stream',
  ALTER COLUMN created_by DROP NOT NULL;

-- Backfill existing data
UPDATE files
SET
  bytes = COALESCE(bytes, size, 0),
  mime  = COALESCE(mime, mimetype, 'application/octet-stream'),
  created_by = COALESCE(created_by, owner_id)
WHERE bytes IS NULL OR mime IS NULL OR created_by IS NULL;

-- Trigger function
CREATE OR REPLACE FUNCTION files_before_write()
RETURNS trigger
AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.created_at IS NULL THEN
    NEW.created_at := now();
  END IF;
  NEW.updated_at := now();

  NEW.file_name := COALESCE(NEW.file_name, NEW.filename);
  NEW.filename  := COALESCE(NEW.filename, NEW.file_name);

  NEW.mimetype := COALESCE(NEW.mimetype, NEW.mime);
  NEW.mime     := COALESCE(NEW.mime, NEW.mimetype, 'application/octet-stream');

  NEW.storage_url := COALESCE(NEW.storage_url, NEW.url, NEW.file_url);
  NEW.url         := COALESCE(NEW.url,         NEW.storage_url);
  NEW.file_url    := COALESCE(NEW.file_url,    NEW.storage_url);

  NEW.bytes := COALESCE(NEW.bytes, NEW.size, 0);
  NEW.size  := COALESCE(NEW.size,  NEW.bytes, 0);

  NEW.created_by := COALESCE(NEW.created_by, NEW.owner_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger binding
DROP TRIGGER IF EXISTS trg_files_before_write ON files;
CREATE TRIGGER trg_files_before_write
BEFORE INSERT OR UPDATE ON files
FOR EACH ROW
EXECUTE FUNCTION files_before_write();
