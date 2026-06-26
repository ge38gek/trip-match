-- Core Enums for the Ingestion Pipeline
CREATE TYPE job_status_enum AS ENUM ('running', 'completed', 'failed');
CREATE TYPE payload_status_enum AS ENUM ('pending', 'processed', 'failed', 'ignored');

-- ========================================================
-- 1. THE OPERATIONAL LEDGER (IngestionJob)
-- ========================================================
CREATE TABLE ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name VARCHAR(50) NOT NULL,    -- e.g., 'ticketmaster', 'resident_advisor'
    target_city_id UUID REFERENCES cities(id), -- If a job targets a specific city
    status job_status_enum NOT NULL DEFAULT 'running',
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMPTZ,
    
    -- Telemetry Metrics for monitoring pipeline health
    records_found INT DEFAULT 0,
    records_imported INT DEFAULT 0,
    duplicates_found INT DEFAULT 0,
    error_count INT DEFAULT 0,
    
    error_log TEXT,
    next_scheduled_run TIMESTAMPTZ
);

-- ========================================================
-- 2. THE RAW DATA VAULT (raw_payloads)
-- ========================================================
CREATE TABLE raw_payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES ingestion_jobs(id), -- Links directly back to the execution run
    provider_name VARCHAR(50) NOT NULL,
    provider_event_id VARCHAR(100) NOT NULL,
    
    payload_json JSONB NOT NULL,
    -- SHA-256 fingerprint of the data. If the event details haven't changed, 
    -- the hash will match, allowing us to skip processing.
    payload_hash VARCHAR(64) NOT NULL, 
    
    fetch_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    processing_status payload_status_enum NOT NULL DEFAULT 'pending',
    
    CONSTRAINT unique_provider_event_hash UNIQUE (provider_name, provider_event_id, payload_hash)
);

-- ========================================================
-- 3. THE TRANSLATION LAYER (source_mappings)
-- ========================================================
CREATE TABLE source_mappings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_name VARCHAR(50) NOT NULL,
    external_id VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50) NOT NULL,     -- 'event', 'artist', 'venue'
    canonical_id UUID NOT NULL,           -- Soft reference pointing to the unified table ID
    
    -- Pipeline Confidence Metrics
    confidence_score NUMERIC(5,4) DEFAULT 1.0000 CHECK (confidence_score BETWEEN 0 AND 1),
    last_verified TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT unique_source_entity UNIQUE (provider_name, external_id, entity_type)
);