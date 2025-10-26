-- files schema (idempotent + align naming)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ถ้ามีตาราง files อยู่แล้ว -> ปรับโครงสร้างให้ตรงมาตรฐานกลาง
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='files'
  ) THEN
    -- rename user_id -> owner_id (ถ้ายังไม่เปลี่ยน)
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='files' AND column_name='user_id'
    ) AND NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='files' AND column_name='owner_id'
    ) THEN
      ALTER TABLE public.files RENAME COLUMN user_id TO owner_id;
    END IF;

    -- ensure owner_id exists
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='files' AND column_name='owner_id'
    ) THEN
      ALTER TABLE public.files ADD COLUMN owner_id uuid;
    END IF;

    -- backfill owner_id จาก user_id ถ้ายังมีคอลัมน์ user_id อยู่
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='files' AND column_name='user_id'
    ) THEN
      UPDATE public.files SET owner_id = COALESCE(owner_id, user_id);
    END IF;

    -- บังคับ NOT NULL
    ALTER TABLE public.files ALTER COLUMN owner_id SET NOT NULL;

    -- ตั้งชื่อคอลัมน์ให้มาตรฐาน
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='files' AND column_name='filename') THEN
      ALTER TABLE public.files RENAME COLUMN filename TO file_name;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='files' AND column_name='mimetype') THEN
      ALTER TABLE public.files RENAME COLUMN mimetype TO mime;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='files' AND column_name='storage_url') THEN
      ALTER TABLE public.files RENAME COLUMN storage_url TO url;
    END IF;

    -- ถ้ายังไม่มีคอลัมน์ตามมาตรฐานให้เพิ่ม
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='files' AND column_name='file_name') THEN
      ALTER TABLE public.files ADD COLUMN file_name text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='files' AND column_name='mime') THEN
      ALTER TABLE public.files ADD COLUMN mime text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='files' AND column_name='size') THEN
      ALTER TABLE public.files ADD COLUMN size bigint CHECK (size > 0);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='files' AND column_name='url') THEN
      ALTER TABLE public.files ADD COLUMN url text;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='files' AND column_name='updated_at') THEN
      ALTER TABLE public.files ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
    END IF;

    -- index + FK
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='files_owner_id_fkey') THEN
      ALTER TABLE public.files
        ADD CONSTRAINT files_owner_id_fkey
        FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;
    END IF;

    CREATE INDEX IF NOT EXISTS idx_files_owner_created ON public.files(owner_id, created_at DESC);

    -- trigger updated_at (ใช้ฟังก์ชันจาก 0000_init.sql)
    DROP TRIGGER IF EXISTS files_set_updated_at ON public.files;
    CREATE TRIGGER files_set_updated_at
      BEFORE UPDATE ON public.files
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();

  ELSE
    -- ไม่มีตาราง files -> สร้างใหม่ตามมาตรฐาน
    CREATE TABLE public.files (
      id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id    uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
      file_name   text NOT NULL,
      mime        text NOT NULL,
      size        bigint NOT NULL CHECK (size > 0),
      url         text NOT NULL,
      created_at  timestamptz NOT NULL DEFAULT now(),
      updated_at  timestamptz NOT NULL DEFAULT now()
    );

    CREATE INDEX IF NOT EXISTS idx_files_owner_created ON public.files(owner_id, created_at DESC);

    DROP TRIGGER IF EXISTS files_set_updated_at ON public.files;
    CREATE TRIGGER files_set_updated_at
      BEFORE UPDATE ON public.files
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  END IF;
END $$;
