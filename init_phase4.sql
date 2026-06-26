-- Clean up from previous partial run attempts to ensure a clean slate
DELETE FROM events WHERE id IN ('e4444444-4444-4444-4444-444444444444', 'e5555555-5555-5555-5555-555555555555');
DELETE FROM venues WHERE id IN ('b2222222-2222-2222-2222-222222222222', 'b3333333-3333-3333-3333-333333333333');
DELETE FROM destination_intelligence WHERE city_id IN ('c2222222-2222-2222-2222-222222222222', 'c3333333-3333-3333-3333-333333333333');
DELETE FROM cities WHERE id IN ('c2222222-2222-2222-2222-222222222222', 'c3333333-3333-3333-3333-333333333333');
DELETE FROM countries WHERE code IN ('ES', 'FR');

-- 1. Insert Spanish and French Country Records
INSERT INTO countries (code, name, region) VALUES 
('ES', 'Spain', 'Europe'),
('FR', 'France', 'Europe');

-- 2. Insert Cities (Ibiza and Paris)
INSERT INTO cities (id, country_code, name, english_name, coordinates, airport_code) VALUES 
('c2222222-2222-2222-2222-222222222222', 'ES', 'Ibiza', 'Ibiza', point(38.90, 1.43), 'IBZ'),
('c3333333-3333-3333-3333-333333333333', 'FR', 'Paris', 'Paris', point(48.85, 2.35), 'CDG');

-- 3. Populate Destination Intelligence with Vector Embeddings and Vibe Profiles
INSERT INTO destination_intelligence (city_id, cost_index, walkability_score, safety_score, vibe_scores, embedding) VALUES 
(
    'c2222222-2222-2222-2222-222222222222', 
    90, 45, 88, 
    '{"nightlife_score": 100, "romantic_score": 50, "electronic_focus": 98, "jazz_focus": 5}'::jsonb,
    ARRAY_FILL(0.85::real, ARRAY[1536])::vector 
),
(
    'c3333333-3333-3333-3333-333333333333', 
    75, 95, 82, 
    '{"nightlife_score": 75, "romantic_score": 98, "electronic_focus": 40, "jazz_focus": 90}'::jsonb,
    ARRAY_FILL(0.22::real, ARRAY[1536])::vector 
);

-- 4. Set up Venues in those cities (Swapped "v" for "b" to make them valid hexadecimal UUIDs)
INSERT INTO venues (id, city_id, name, capacity, coordinates, timezone, venue_type) VALUES 
('b2222222-2222-2222-2222-222222222222', 'c2222222-2222-2222-2222-222222222222', 'Hï Ibiza', 5000, point(38.87, 1.40), 'Europe/Madrid', 'club'),
('b3333333-3333-3333-3333-333333333333', 'c3333333-3333-3333-3333-333333333333', 'Le Duc des Lombards', 150, point(48.86, 2.34), 'Europe/Paris', 'jazz_club');

-- 5. Set up the specific events happening in October 2026
INSERT INTO events (id, venue_id, city_id, original_title, english_title, start_time, end_time, timezone, event_type, tags) VALUES 
(
    'e4444444-4444-4444-4444-444444444444', 
    'b2222222-2222-2222-2222-222222222222', 
    'c2222222-2222-2222-2222-222222222222',
    'The Grand Closing Party', 'The Grand Closing Party',
    '2026-10-10 22:00:00+00', '2026-10-11 08:00:00+00', 'Europe/Madrid', 'festival',
    ARRAY['#electronic', '#mega-club', '#expensive', '#closing-party']
),
(
    'e5555555-5555-5555-5555-555555555555', 
    'b3333333-3333-3333-3333-333333333333', 
    'c3333333-3333-3333-3333-333333333333',
    'Autumn Jazz Quartet Sessions', 'Autumn Jazz Quartet Sessions',
    '2026-10-16 20:00:00+00', '2026-10-16 23:00:00+00', 'Europe/Paris', 'concert',
    ARRAY['#jazz', '#romantic', '#intimate', '#cozy']
);