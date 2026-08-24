-- +goose Up
CREATE TABLE notes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT NOT NULL,
  content    TEXT,
  category   TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('general', 'bills', 'chores', 'appointment')),
  pinned     BOOLEAN NOT NULL DEFAULT false,
  priority   SMALLINT NOT NULL DEFAULT 0,
  due_at     TIMESTAMPTZ,
  done_at    TIMESTAMPTZ,
  tags       TEXT[] NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notes_user_id    ON notes(user_id);
CREATE INDEX idx_notes_category   ON notes(category);
CREATE INDEX idx_notes_pinned     ON notes(pinned);
CREATE INDEX idx_notes_due_at     ON notes(due_at);

CREATE TRIGGER notes_updated_at
  BEFORE UPDATE ON notes
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- +goose Down
DROP TABLE IF EXISTS notes;