-- ถ้ามีตาราง files อยู่แล้ว
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name='files' AND table_schema='public'
  ) THEN
    -- ถ้ามีคอลัมน์ user_id ให้ rename -> owner_id
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name='files' AND column_name='user_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name='files' AND column_name='owner_id'
    ) THEN
      ALTER TABLE files RENAME COLUMN user_id TO owner_id;
    END IF;

    -- ถ้ายังไม่มี owner_id ให้เพิ่ม
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_name='files' AND column_name='owner_id'
    ) THEN
      ALTER TABLE files ADD COLUMN owner_id uuid;
    END IF;

    -- ตั้ง NOT NULL หลัง backfill (ถ้าจำเป็น)
    -- ถ้ามีแถวที่ owner_id ยัง NULL แล้วมี user_id เดิม ให้ย้ายค่า
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='files' AND column_name='user_id') THEN
      UPDATE files SET owner_id = COALESCE(owner_id, user_id);
    END IF;

    -- บังคับ NOT NULL
    ALTER TABLE files ALTER COLUMN owner_id SET NOT NULL;

    -- เพิ่ม FK ถ้ายังไม่มี
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint WHERE conname='files_owner_id_fkey'
    ) THEN
      ALTER TABLE files
        ADD CONSTRAINT files_owner_id_fkey
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE;
    END IF;

    CREATE INDEX IF NOT EXISTS idx_files_owner_created ON files(owner_id, created_at DESC);
  ELSE

    CREATE EXTENSION IF NOT EXISTS "pgcrypto"; ก
    CREATE TABLE files (
      id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      filename    text NOT NULL,
      mimetype    text NOT NULL,
      size        bigint NOT NULL CHECK (size > 0),
      storage_url text NOT NULL,
      created_at  timestamptz NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS idx_files_owner_created ON files(owner_id, created_at DESC);
  END IF;
END $$;
