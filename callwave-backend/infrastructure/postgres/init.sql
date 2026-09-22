-- PostgreSQL Schema for Callwave Microservices Backend

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enums
CREATE TYPE auth_provider_enum AS ENUM ('LOCAL', 'GOOGLE', 'PHONE');
CREATE TYPE account_role_enum AS ENUM ('STANDARD', 'ADMIN');
CREATE TYPE account_status_enum AS ENUM ('ACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION', 'DELETED');
CREATE TYPE presence_status_enum AS ENUM ('ONLINE', 'OFFLINE', 'IN_CALL', 'BUSY', 'AWAY', 'DND');
CREATE TYPE call_type_enum AS ENUM ('DIRECT_AUDIO', 'DIRECT_VIDEO', 'GROUP_AUDIO', 'GROUP_VIDEO');
CREATE TYPE call_status_enum AS ENUM ('COMPLETED', 'MISSED', 'REJECTED', 'CANCELLED', 'FAILED');
CREATE TYPE participant_status_enum AS ENUM ('JOINED', 'MISSED', 'DECLINED');

-- 1. Users Table (Core Auth & Account)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    matricule VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    password_salt VARCHAR(255),
    auth_provider auth_provider_enum NOT NULL DEFAULT 'LOCAL',
    role account_role_enum NOT NULL DEFAULT 'STANDARD',
    status account_status_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMPTZ,
    last_ip_address VARCHAR(45),
    last_location VARCHAR(255)
);

-- 2. User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(150),
    department VARCHAR(100),
    ministry VARCHAR(100),
    division VARCHAR(100),
    position_title VARCHAR(100),
    office_location VARCHAR(150),
    avatar_url TEXT,
    is_searchable BOOLEAN NOT NULL DEFAULT TRUE,
    hide_phone_email BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. User Presences Table
CREATE TABLE IF NOT EXISTS user_presences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_status presence_status_enum NOT NULL DEFAULT 'OFFLINE',
    custom_status_message VARCHAR(255),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    socket_id VARCHAR(255),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. User Contacts Table (Saved Contacts)
CREATE TABLE IF NOT EXISTS user_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    contact_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    custom_alias VARCHAR(150),
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    is_blocked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_user_contact UNIQUE (owner_user_id, contact_user_id)
);

-- 5. Call Logs Table
CREATE TABLE IF NOT EXISTS call_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_title VARCHAR(150),
    call_type call_type_enum NOT NULL,
    caller_id UUID REFERENCES users(id) ON DELETE SET NULL,
    room_id VARCHAR(255) NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    call_status call_status_enum NOT NULL DEFAULT 'COMPLETED'
);

-- 6. Call Participants Table
CREATE TABLE IF NOT EXISTS call_participants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    call_id UUID NOT NULL REFERENCES call_logs(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    participant_status participant_status_enum NOT NULL DEFAULT 'JOINED',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT unique_call_participant UNIQUE (call_id, user_id)
);

-- 7. User Settings Table
CREATE TABLE IF NOT EXISTS user_settings (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    theme VARCHAR(20) NOT NULL DEFAULT 'system',
    language VARCHAR(10) NOT NULL DEFAULT 'fr_CM',
    enable_ringtone BOOLEAN NOT NULL DEFAULT TRUE,
    enable_notifications BOOLEAN NOT NULL DEFAULT TRUE,
    mute_missed_alerts BOOLEAN NOT NULL DEFAULT FALSE,
    auto_mute_mic BOOLEAN NOT NULL DEFAULT FALSE,
    auto_turn_off_cam BOOLEAN NOT NULL DEFAULT FALSE,
    low_data_mode BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. User Sessions Table
CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(255) NOT NULL,
    client_info VARCHAR(255),
    ip_address VARCHAR(45),
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    last_activity_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_matricule ON users(matricule);
CREATE INDEX IF NOT EXISTS idx_user_contacts_owner ON user_contacts(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_user_contacts_contact ON user_contacts(contact_user_id);
CREATE INDEX IF NOT EXISTS idx_call_logs_caller ON call_logs(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_logs_room ON call_logs(room_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_call ON call_participants(call_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_user ON call_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_call_participants_status ON call_participants(participant_status);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON user_sessions(refresh_token_hash);
