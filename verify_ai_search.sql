-- Clear out prior checks to ensure a clean slate
TRUNCATE cities, destination_intelligence RESTART IDENTITY CASCADE;

-- 1. Create a Target Country and City Location
INSERT INTO countries (code, name, region) VALUES ('DE', 'Germany', 'Europe');
INSERT INTO cities (id, country_code, name, english_name, coordinates) 
VALUES ('c1111111-1111-1111-1111-111111111111', 'DE', 'Berlin', 'Berlin', point(52.52, 13.40));

-- 2. Populate Destination Intelligence with Specific AI Vibe Scores and a Sample Mock Vector Array
-- This simulates a 1536-dimensional embedding vector representing an underground techno capital vibe
INSERT INTO destination_intelligence (city_id, cost_index, walkability_score, safety_score, vibe_scores, embedding)
VALUES (
    'c1111111-1111-1111-1111-111111111111', 
    65, 92, 85, 
    '{"nightlife_score": 98, "romantic_score": 40, "underground_vibe": 99}'::jsonb,
    ARRAY_FILL(0.15::real, ARRAY[1536])::vector
);

-- 3. Execute a Vector Distance Search Query (Semantic Request Mock)
-- The '<=>' operator calculates Cosine Distance. Lower distance equals higher matching accuracy.
SELECT 
    c.english_name,
    di.vibe_scores->>'nightlife_score' AS nightlife_rating,
    di.vibe_scores->>'underground_vibe' AS underground_rating,
    (di.embedding <=> ARRAY_FILL(0.14::real, ARRAY[1536])::vector) AS semantic_distance
FROM destination_intelligence di
JOIN cities c ON di.city_id = c.id
ORDER BY semantic_distance ASC
LIMIT 1;