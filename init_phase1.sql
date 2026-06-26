-- Enable necessary ecosystem extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "vector";

-- Core Enums
CREATE TYPE event_type_enum AS ENUM ('concert', 'festival', 'dj_set', 'club_night');
CREATE TYPE event_status_enum AS ENUM ('scheduled', 'cancelled', 'postponed', 'rescheduled');

-- ========================================================
-- 1. GEOGRAPHY & RICH DESTINATION INTELLIGENCE
-- ========================================================
CREATE TABLE countries (
    code VARCHAR(2) PRIMARY KEY,
    name TEXT NOT NULL,
    region TEXT NOT NULL
);

CREATE TABLE cities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    country_code VARCHAR(2) REFERENCES countries(code) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    english_name TEXT NOT NULL,
    coordinates POINT NOT NULL,
    airport_code VARCHAR(3),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE destination_intelligence (
    city_id UUID PRIMARY KEY REFERENCES cities(id) ON DELETE CASCADE,
    cost_index INT CHECK (cost_index BETWEEN 1 AND 100),
    walkability_score INT CHECK (walkability_score BETWEEN 1 AND 100),
    safety_score INT CHECK (safety_score BETWEEN 1 AND 100),
    vibe_scores JSONB DEFAULT '{}'::jsonb, 
    embedding vector(1536),
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ========================================================
-- 2. ENHANCED VENUE REGISTRY & TAXONOMY
-- ========================================================
CREATE TABLE venues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    city_id UUID REFERENCES cities(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    capacity INT,
    coordinates POINT NOT NULL,
    timezone TEXT NOT NULL,
    venue_type VARCHAR(50),
    is_indoor BOOLEAN,
    is_outdoor BOOLEAN,
    accessibility_features JSONB DEFAULT '{}'::jsonb,
    website_url TEXT,
    google_rating NUMERIC(3,2),
    tripadvisor_rating NUMERIC(3,2),
    performance_metrics JSONB DEFAULT '{}'::jsonb,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ========================================================
-- 3. THE KNOWLEDGE GRAPH ARTISTS ENGINE
-- ========================================================
CREATE TABLE artists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    aliases TEXT[] DEFAULT '{}',
    spotify_id VARCHAR(100) UNIQUE,
    musicbrainz_id UUID UNIQUE,
    origin_country_code VARCHAR(2) REFERENCES countries(code),
    popularity_score INT DEFAULT 0 CHECK (popularity_score BETWEEN 0 AND 100),
    spotify_followers INT,
    spotify_monthly_listeners INT,
    emerging_artist_score NUMERIC(5,2),
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ========================================================
-- 4. PARTITIONED EVENTS ENGINE WITH EMBEDDINGS
-- ========================================================
CREATE TABLE events (
    id UUID DEFAULT uuid_generate_v4(),
    venue_id UUID REFERENCES venues(id) ON DELETE RESTRICT,
    city_id UUID REFERENCES cities(id) ON DELETE RESTRICT,
    original_title TEXT NOT NULL,
    english_title TEXT NOT NULL,
    original_description TEXT,
    english_description TEXT,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    timezone TEXT NOT NULL,
    event_type event_type_enum NOT NULL DEFAULT 'concert',
    status event_status_enum NOT NULL DEFAULT 'scheduled',
    tags TEXT[] DEFAULT '{}',
    popularity_score INT DEFAULT 0,
    embedding vector(1536),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, start_time)
) PARTITION BY RANGE (start_time);

-- Seed an immediate partition bucket so the engine is active
CREATE TABLE events_y2026_default PARTITION OF events 
    FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');