-- +goose Up
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin'));

CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- (ตั้ง admin เริ่มต้นตามอีเมลของคุณ ถ้าต้องการ)
-- UPDATE users SET role='admin' WHERE email='admin@homeservice.local';

-- +goose Down
ALTER TABLE users DROP COLUMN IF EXISTS role;
DROP INDEX IF EXISTS idx_users_role;
