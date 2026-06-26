-- Clean up any residual data from previous attempts to ensure a clean test slate
TRUNCATE ingestion_jobs, raw_payloads, source_mappings RESTART IDENTITY CASCADE;
DELETE FROM venues WHERE id = 'deadeade-adea-dead-ea00-000000000001';

-- 1. Insert a proper parent Venue (Tresor Berlin) linked to our Phase 1 Berlin City
INSERT INTO venues (id, city_id, name, capacity, coordinates, timezone, venue_type)
VALUES (
    'deadeade-adea-dead-ea00-000000000001',
    'c1111111-1111-1111-1111-111111111111', -- Berlin City ID from Phase 1
    'Tresor Berlin',
    800,
    point(52.51, 13.41),
    'Europe/Berlin',
    'club'
);

-- 2. Register a new ingestion job using a valid hex UUID (a-f, 0-9)
INSERT INTO ingestion_jobs (id, provider_name, target_city_id, status)
VALUES (
    'a2222222-2222-2222-2222-222222222222', 
    'ticketmaster', 
    'c1111111-1111-1111-1111-111111111111', 
    'running'
);

-- 3. Store the raw API response in our immutable vault
INSERT INTO raw_payloads (job_id, provider_name, provider_event_id, payload_json, payload_hash, processing_status)
VALUES (
    'a2222222-2222-2222-2222-222222222222',
    'ticketmaster',
    'tm-evt-998877',
    '{"title": "Amelie Lens Live", "venue": "Tresor", "date": "2026-10-15", "price_eur": 45.00}'::jsonb,
    'mock_sha256_hash_value_123456789',
    'pending'
);

-- 4. Create the beautifully structured canonical event record
INSERT INTO events (id, venue_id, city_id, original_title, english_title, start_time, end_time, timezone, event_type)
VALUES (
    'e3333333-3333-3333-3333-333333333333',
    'deadeade-adea-dead-ea00-000000000001', -- Correctly pointing to the Tresor Venue ID!
    'c1111111-1111-1111-1111-111111111111', -- Berlin
    'Amelie Lens Live',
    'Amelie Lens Live',
    '2026-10-15 22:00:00+00',
    '2026-10-16 06:00:00+00',
    'Europe/Berlin',
    'dj_set'
);

-- 5. Map the external reference cleanly to our internal canonical ID
INSERT INTO source_mappings (provider_name, external_id, entity_type, canonical_id, confidence_score)
VALUES ('ticketmaster', 'tm-evt-998877', 'event', 'e3333333-3333-3333-3333-333333333333', 1.0000);

-- 6. Complete the job and log pipeline telemetry metrics
UPDATE ingestion_jobs 
SET status = 'completed', 
    finished_at = CURRENT_TIMESTAMP,
    records_found = 1,
    records_imported = 1
WHERE id = 'a2222222-2222-2222-2222-222222222222';

-- 7. Execute provenance lookup verification
SELECT 
    e.english_title,
    sm.provider_name AS data_source,
    sm.external_id AS original_provider_id,
    rp.payload_json->>'price_eur' AS original_ticket_price,
    ij.status AS processing_job_status
FROM events e
JOIN source_mappings sm ON e.id = sm.canonical_id
JOIN raw_payloads rp ON sm.external_id = rp.provider_event_id AND sm.provider_name = rp.provider_name
JOIN ingestion_jobs ij ON rp.job_id = ij.id;