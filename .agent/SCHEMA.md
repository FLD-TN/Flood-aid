# SCHEMA.md — Database Migrations

> File này chứa SQL migration đầy đủ cho dự án FloodAid.
> Chạy theo thứ tự: 001 → 002 → 003 ...

---

## Migration 001: Extensions & Core Tables

```sql
-- Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enum types
CREATE TYPE case_status AS ENUM ('pending', 'responding', 'on_scene', 'resolved');
CREATE TYPE flag_type AS ENUM ('tree_down', 'bridge_collapsed', 'flooded_road');
CREATE TYPE user_role AS ENUM ('victim', 'volunteer', 'admin');

-- Bảng victims (Nạn nhân)
CREATE TABLE victims (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash  VARCHAR(64) UNIQUE NOT NULL,
  firebase_uid VARCHAR(128) UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng volunteers (TNV)
CREATE TABLE volunteers (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash      VARCHAR(64) UNIQUE NOT NULL,
  firebase_uid    VARCHAR(128) UNIQUE NOT NULL,
  cccd_verified   BOOLEAN DEFAULT FALSE,
  admin_approved  BOOLEAN DEFAULT FALSE,
  skills          JSONB DEFAULT '[]',        -- ["cpr", "y_ta", "bac_si"]
  current_coords  GEOMETRY(POINT, 4326),
  last_seen_at    TIMESTAMPTZ,
  is_available    BOOLEAN DEFAULT FALSE,
  fcm_token       TEXT,
  flag_count      INT DEFAULT 0,             -- số lần vi phạm
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng cases (Ca SOS)
CREATE TABLE cases (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone_hash      VARCHAR(64) NOT NULL,
  coords          GEOMETRY(POINT, 4326) NOT NULL,
  text_raw        TEXT,
  urgency_level   SMALLINT NOT NULL CHECK (urgency_level BETWEEN 1 AND 5),
  tags            JSONB DEFAULT '[]',        -- ["y_te", "tre_em", ...]
  summary_1line   TEXT NOT NULL,
  status          case_status DEFAULT 'pending',
  tnv_distance_m  INT,                       -- cache khoảng cách TNV gần nhất
  ai_source       VARCHAR(20),               -- 'gemini' | 'rule_based'
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  resolved_at     TIMESTAMPTZ
);

-- Bảng case_assignments (TNV nhận ca)
CREATE TABLE case_assignments (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  case_id           UUID NOT NULL REFERENCES cases(id),
  volunteer_id      UUID NOT NULL REFERENCES volunteers(id),
  initial_distance_m INT,                   -- khoảng cách khi nhận ca
  assigned_at       TIMESTAMPTZ DEFAULT NOW(),
  warned_at         TIMESTAMPTZ,            -- đã gửi FCM "bạn có còn đang đi không"
  confirmed_en_route BOOLEAN DEFAULT TRUE,
  arrived_at        TIMESTAMPTZ,
  completed_at      TIMESTAMPTZ,
  revoked_at        TIMESTAMPTZ,
  notif_sent_300m   BOOLEAN DEFAULT FALSE,
  notif_sent_100m   BOOLEAN DEFAULT FALSE,
  UNIQUE(case_id, volunteer_id)
);

-- Bảng warning_flags (Cờ cảnh báo tuyến đường)
CREATE TABLE warning_flags (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  coords          GEOMETRY(POINT, 4326) NOT NULL,
  type            flag_type NOT NULL,
  created_by      UUID NOT NULL,            -- admin id
  is_active       BOOLEAN DEFAULT TRUE,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  deactivated_at  TIMESTAMPTZ
);

-- Bảng admins
CREATE TABLE admins (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email       VARCHAR(255) UNIQUE NOT NULL,
  firebase_uid VARCHAR(128) UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Bảng chống spam FCM cờ
CREATE TABLE volunteer_flag_alerts (
  volunteer_id UUID NOT NULL REFERENCES volunteers(id),
  flag_id      UUID NOT NULL REFERENCES warning_flags(id),
  alerted_at   TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (volunteer_id, flag_id, alerted_at)
);
```

---

## Migration 002: Indexes

```sql
-- Cases
CREATE INDEX idx_cases_coords ON cases USING GIST(coords);
CREATE INDEX idx_cases_status ON cases (status) WHERE status != 'resolved';
CREATE INDEX idx_cases_phone_hash ON cases (phone_hash);
CREATE INDEX idx_cases_urgency ON cases (urgency_level) WHERE status != 'resolved';

-- Volunteers
CREATE INDEX idx_volunteers_coords ON volunteers USING GIST(current_coords);
CREATE INDEX idx_volunteers_available ON volunteers (is_available, admin_approved) 
  WHERE is_available = true AND admin_approved = true;

-- Warning flags
CREATE INDEX idx_flags_coords ON warning_flags USING GIST(coords) WHERE is_active = true;

-- Case assignments
CREATE INDEX idx_assignments_case ON case_assignments (case_id);
CREATE INDEX idx_assignments_volunteer ON case_assignments (volunteer_id);
```

---

## Migration 003: Useful Views

```sql
-- View: Active cases với thông tin đầy đủ cho Admin Dashboard
CREATE VIEW v_active_cases AS
SELECT 
  c.id,
  c.coords,
  ST_X(c.coords::geometry) AS lon,
  ST_Y(c.coords::geometry) AS lat,
  c.urgency_level,
  c.tags,
  c.summary_1line,
  c.status,
  c.created_at,
  EXTRACT(EPOCH FROM (NOW() - c.created_at))/60 AS minutes_waiting,
  COUNT(ca.id) FILTER (WHERE ca.revoked_at IS NULL AND ca.completed_at IS NULL) AS responding_count
FROM cases c
LEFT JOIN case_assignments ca ON ca.case_id = c.id
WHERE c.status != 'resolved'
GROUP BY c.id;

-- View: Available volunteers với vị trí hiện tại
CREATE VIEW v_available_volunteers AS
SELECT 
  v.id,
  v.skills,
  v.fcm_token,
  v.flag_count,
  ST_X(v.current_coords::geometry) AS lon,
  ST_Y(v.current_coords::geometry) AS lat,
  v.last_seen_at,
  EXTRACT(EPOCH FROM (NOW() - v.last_seen_at))/60 AS minutes_since_update
FROM volunteers v
WHERE v.is_available = true 
  AND v.admin_approved = true
  AND v.current_coords IS NOT NULL;
```
