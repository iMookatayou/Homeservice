-- 0007_notes_task_fields.sql
-- เพิ่มฟิลด์สำหรับงาน + ดัชนี

ALTER TABLE notes
  ADD COLUMN IF NOT EXISTS created_by  UUID,                -- คนสร้างงาน
  ADD COLUMN IF NOT EXISTS assigned_to UUID,                -- ผู้รับงาน
  ADD COLUMN IF NOT EXISTS due_at      TIMESTAMPTZ,         -- เดดไลน์
  ADD COLUMN IF NOT EXISTS remind_at   TIMESTAMPTZ,         -- แจ้งเตือน (ใช้ทีหลัง)
  ADD COLUMN IF NOT EXISTS done_at     TIMESTAMPTZ,         -- ทำเสร็จเมื่อไหร่ (NULL = ยัง)
  ADD COLUMN IF NOT EXISTS priority    SMALLINT NOT NULL DEFAULT 0, -- 0=ปกติ/1=สูง ฯลฯ
  ADD COLUMN IF NOT EXISTS pinned      BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS category    TEXT,                -- 'general'|'bills'|'chores'|'appointment'...
  ADD COLUMN IF NOT EXISTS location    TEXT;                -- หน้างาน/ที่อยู่

-- ดัชนีใช้บ่อย
CREATE INDEX IF NOT EXISTS idx_notes_assigned_to   ON notes(assigned_to);
CREATE INDEX IF NOT EXISTS idx_notes_created_by    ON notes(created_by);
CREATE INDEX IF NOT EXISTS idx_notes_done_at       ON notes(done_at);
CREATE INDEX IF NOT EXISTS idx_notes_due_at        ON notes(due_at);
CREATE INDEX IF NOT EXISTS idx_notes_priority_desc ON notes(priority DESC);

-- ฟังก์ชันลบงานที่เสร็จเกิน N วัน
CREATE OR REPLACE FUNCTION notes_delete_old_done(days int)
RETURNS void AS $$
BEGIN
  DELETE FROM notes
   WHERE done_at IS NOT NULL
     AND done_at < now() - make_interval(days => days);
END;
$$ LANGUAGE plpgsql;

-- (ถ้ามี pg_cron) ตั้งงานลบทุกวันตี 3
-- หมายเหตุ: ถ้า DB ยังไม่มี pg_cron ให้ข้ามสองบรรทัดนี้ไป
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('notes_cleanup_daily', '0 3 * * *', $$ SELECT notes_delete_old_done(30); $$);
