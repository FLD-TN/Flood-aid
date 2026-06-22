/**
 * Database migrations for FloodAid
 * Run: node src/db/migrations.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '../../.env') });
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('render.com')
    ? { rejectUnauthorized: false }
    : undefined,
});

const migration001 = `
-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enum types
DO $$ BEGIN
  CREATE TYPE case_status AS ENUM ('pending', 'responding', 'on_scene', 'resolved');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;



-- Bảng victims (Nạn nhân)
CREATE TABLE IF NOT EXISTS victims (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash  VARCHAR(64) UNIQUE NOT NULL,
  firebase_uid VARCHAR(128) UNIQUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng volunteers (TNV)
CREATE TABLE IF NOT EXISTS volunteers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash      VARCHAR(64) UNIQUE NOT NULL,
  firebase_uid    VARCHAR(128) UNIQUE,
  full_name       VARCHAR(255),
  cccd_verified   BOOLEAN DEFAULT FALSE,
  admin_approved  BOOLEAN DEFAULT FALSE,
  skills          JSONB DEFAULT '[]',
  current_coords  GEOMETRY(POINT, 4326),
  last_seen_at    TIMESTAMPTZ,
  is_available    BOOLEAN DEFAULT FALSE,
  fcm_token       TEXT,
  flag_count      INT DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng cases (Ca SOS)
CREATE TABLE IF NOT EXISTS cases (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash      VARCHAR(64) NOT NULL,
  coords          GEOMETRY(POINT, 4326) NOT NULL,
  text_raw        TEXT,
  urgency_level   SMALLINT NOT NULL CHECK (urgency_level BETWEEN 1 AND 5),
  tags            JSONB DEFAULT '[]',
  summary_1line   TEXT NOT NULL,
  status          case_status DEFAULT 'pending',
  tnv_distance_m  INT,
  ai_source       VARCHAR(20),
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ
);

-- Bảng case_assignments (TNV nhận ca)
CREATE TABLE IF NOT EXISTS case_assignments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id           UUID NOT NULL REFERENCES cases(id),
  volunteer_id      UUID NOT NULL REFERENCES volunteers(id),
  initial_distance_m INT,
  assigned_at       TIMESTAMPTZ DEFAULT NOW(),
  warned_at         TIMESTAMPTZ,
  confirmed_en_route BOOLEAN DEFAULT TRUE,
  arrived_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  revoked_at        TIMESTAMPTZ,
  notif_sent_300m   BOOLEAN DEFAULT FALSE,
  notif_sent_100m   BOOLEAN DEFAULT FALSE,
  UNIQUE(case_id, volunteer_id)
);

-- Bảng admins
CREATE TABLE IF NOT EXISTS admins (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email       VARCHAR(255) UNIQUE NOT NULL,
  firebase_uid VARCHAR(128) UNIQUE,
  full_name   VARCHAR(255),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
`;

const migration002 = `
-- Cases
CREATE INDEX IF NOT EXISTS idx_cases_coords ON cases USING GIST(coords);
CREATE INDEX IF NOT EXISTS idx_cases_status ON cases (status) WHERE status != 'resolved';
CREATE INDEX IF NOT EXISTS idx_cases_phone_hash ON cases (phone_hash);
CREATE INDEX IF NOT EXISTS idx_cases_urgency ON cases (urgency_level) WHERE status != 'resolved';

-- Volunteers
CREATE INDEX IF NOT EXISTS idx_volunteers_coords ON volunteers USING GIST(current_coords);
CREATE INDEX IF NOT EXISTS idx_volunteers_available ON volunteers (is_available, admin_approved) 
  WHERE is_available = true AND admin_approved = true;


-- Case assignments
CREATE INDEX IF NOT EXISTS idx_assignments_case ON case_assignments (case_id);
CREATE INDEX IF NOT EXISTS idx_assignments_volunteer ON case_assignments (volunteer_id);
`;

const migration003 = `
-- View: Active cases với thông tin đầy đủ cho Admin Dashboard
CREATE OR REPLACE VIEW v_active_cases AS
SELECT 
  c.id,
  c.coords,
  ST_X(c.coords::geometry) AS lon,
  ST_Y(c.coords::geometry) AS lat,
  c.urgency_level,
  c.tags,
  c.summary_1line,
  c.status,
  c.tnv_distance_m,
  c.created_at,
  EXTRACT(EPOCH FROM (NOW() - c.created_at))/60 AS minutes_waiting,
  COUNT(ca.id) FILTER (WHERE ca.revoked_at IS NULL AND ca.completed_at IS NULL) AS responding_count
FROM cases c
LEFT JOIN case_assignments ca ON ca.case_id = c.id
WHERE c.status != 'resolved'
GROUP BY c.id;

-- View: Available volunteers với vị trí hiện tại
CREATE OR REPLACE VIEW v_available_volunteers AS
SELECT 
  v.id,
  v.full_name,
  v.skills,
  v.fcm_token,
  v.flag_count,
  v.is_available,
  ST_X(v.current_coords::geometry) AS lon,
  ST_Y(v.current_coords::geometry) AS lat,
  v.last_seen_at,
  EXTRACT(EPOCH FROM (NOW() - v.last_seen_at))/60 AS minutes_since_update
FROM volunteers v
WHERE v.admin_approved = true
  AND v.current_coords IS NOT NULL;
`;

const migration004 = `
-- C1: FK cases.phone_hash → victims.phone_hash
DO $$ BEGIN
  ALTER TABLE cases ADD CONSTRAINT fk_cases_victim
    FOREIGN KEY (phone_hash) REFERENCES victims(phone_hash);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- C4: Cột lưu SĐT mã hoá cho volunteers (Admin cần gọi GSM)
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS phone_encrypted TEXT;

-- C2: Cleanup — Xoá bảng warning_flags (tính năng đã loại bỏ)
DROP TABLE IF EXISTS volunteer_flag_alerts;
DROP TABLE IF EXISTS warning_flags;
DROP TYPE IF EXISTS flag_type;
`;

const migration005 = `
-- M1: Thêm updated_at cho cases — track thời điểm thay đổi status
ALTER TABLE cases ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- M2: Thêm updated_at cho volunteers — track thời điểm Admin duyệt, TNV đổi availability
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- M3: Index cho assignment timestamp — tăng tốc background jobs (autoResolve, staleChecker)
CREATE INDEX IF NOT EXISTS idx_assignments_active_time
  ON case_assignments (assigned_at)
  WHERE completed_at IS NULL AND revoked_at IS NULL;

-- M6: CHECK constraint cho ai_source — enforce giá trị hợp lệ
ALTER TABLE cases DROP CONSTRAINT IF EXISTS chk_ai_source;
ALTER TABLE cases ADD CONSTRAINT chk_ai_source
  CHECK (ai_source IN ('gemini', 'regex', 'rule_based'));

-- M4: Drop unused user_role enum
DROP TYPE IF EXISTS user_role;
`;

const migration006 = `
-- Smart Notification Radius: Cho phép TNV tự chọn bán kính nhận thông báo SOS
-- NULL = Nhận tất cả (không giới hạn bán kính)
-- Số nguyên (VD: 5) = Chỉ nhận ca trong vòng 5km
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS notification_radius_km INTEGER DEFAULT NULL;
`;

const migration007 = `
-- Thêm 'cancelled' và 'orphaned' vào enum case_status
-- ALTER TYPE ... ADD VALUE là idempotent nếu dùng IF NOT EXISTS (PG 9.3+)
ALTER TYPE case_status ADD VALUE IF NOT EXISTS 'cancelled';
ALTER TYPE case_status ADD VALUE IF NOT EXISTS 'orphaned';
`;

const migration008 = `
-- eKYC: Lưu số CCCD đã mã hóa AES để Admin xác minh danh tính TNV
ALTER TABLE volunteers ADD COLUMN IF NOT EXISTS cccd_number_encrypted TEXT;
`;

const migration009 = `
-- Drop view trước để tránh lỗi "depends on column skills"
DROP VIEW IF EXISTS v_available_volunteers;

-- Xóa cột skills — không còn dùng cho dispatch hay volunteer profile
ALTER TABLE volunteers DROP COLUMN IF EXISTS skills;

-- Tạo lại view v_available_volunteers (bỏ v.skills)
CREATE OR REPLACE VIEW v_available_volunteers AS
SELECT
  v.id,
  v.full_name,
  v.fcm_token,
  v.flag_count,
  v.is_available,
  ST_X(v.current_coords::geometry) AS lon,
  ST_Y(v.current_coords::geometry) AS lat,
  v.last_seen_at,
  EXTRACT(EPOCH FROM (NOW() - v.last_seen_at))/60 AS minutes_since_update
FROM volunteers v
WHERE v.admin_approved = true
  AND v.current_coords IS NOT NULL;
`;

const migration010 = `
-- Xóa cột flag_count khỏi bảng volunteers
ALTER TABLE volunteers DROP COLUMN IF EXISTS flag_count;

-- Cập nhật view v_available_volunteers (bỏ v.flag_count)
CREATE OR REPLACE VIEW v_available_volunteers AS
SELECT
  v.id,
  v.full_name,
  v.fcm_token,
  v.is_available,
  ST_X(v.current_coords::geometry) AS lon,
  ST_Y(v.current_coords::geometry) AS lat,
  v.last_seen_at,
  EXTRACT(EPOCH FROM (NOW() - v.last_seen_at))/60 AS minutes_since_update
FROM volunteers v
WHERE v.admin_approved = true
  AND v.current_coords IS NOT NULL;
`;

const migration011 = `
-- Lưu SĐT mã hoá cho nạn nhân (để TNV đã nhận ca có thể gọi)
ALTER TABLE victims ADD COLUMN IF NOT EXISTS phone_encrypted TEXT;

-- Bảng tin nhắn chat trong ca SOS
CREATE TABLE IF NOT EXISTS chat_messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id     UUID NOT NULL REFERENCES cases(id) ON DELETE CASCADE,
  sender_role VARCHAR(10) NOT NULL CHECK (sender_role IN ('volunteer', 'victim')),
  sender_id   UUID,
  content     TEXT NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_case ON chat_messages (case_id, created_at);
`;

async function runMigrations() {
  const client = await pool.connect();
  try {
    console.log('[Migration] Running migration 001: Extensions & Core Tables...');
    await client.query(migration001);
    console.log('[Migration] ✓ Migration 001 complete');

    console.log('[Migration] Running migration 002: Indexes...');
    await client.query(migration002);
    console.log('[Migration] ✓ Migration 002 complete');

    console.log('[Migration] Running migration 003: Views...');
    await client.query(migration003);
    console.log('[Migration] ✓ Migration 003 complete');

    console.log('[Migration] Running migration 004: FK + phone_encrypted + cleanup...');
    await client.query(migration004);
    console.log('[Migration] ✓ Migration 004 complete');

    console.log('[Migration] Running migration 005: updated_at + index + constraints...');
    await client.query(migration005);
    console.log('[Migration] ✓ Migration 005 complete');

    console.log('[Migration] Running migration 006: Smart Notification Radius...');
    await client.query(migration006);
    console.log('[Migration] ✓ Migration 006 complete');

    console.log('[Migration] Running migration 007: Add cancelled/orphaned to case_status enum...');
    await client.query(migration007);
    console.log('[Migration] ✓ Migration 007 complete');

    console.log('[Migration] Running migration 008: eKYC cccd_number_encrypted...');
    await client.query(migration008);
    console.log('[Migration] ✓ Migration 008 complete');

    console.log('[Migration] Running migration 009: Drop skills column + update view...');
    await client.query(migration009);
    console.log('[Migration] ✓ Migration 009 complete');

    console.log('[Migration] Running migration 010: Drop flag_count column + update view...');
    await client.query(migration010);
    console.log('[Migration] ✓ Migration 010 complete');

    console.log('[Migration] Running migration 011: victims.phone_encrypted + chat_messages table...');
    await client.query(migration011);
    console.log('[Migration] ✓ Migration 011 complete');

    console.log('[Migration] All migrations completed successfully!');
  } catch (err) {
    console.error('[Migration] Error:', err.message);
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

// Run directly if called as script
if (require.main === module) {
  runMigrations()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}

module.exports = { runMigrations };
