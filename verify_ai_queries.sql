-- ==============================================================================
-- SCENARIO A: "I want a romantic weekend with jazz concerts in October 2026."
-- ==============================================================================
SELECT 'SCENARIO A' AS test_case;

SELECT 
    c.english_name AS destination,
    e.english_title AS event_name,
    v.name AS venue_location,
    (di.vibe_scores->>'romantic_score')::int AS romance_rating,
    e.tags
FROM events e
JOIN cities c ON e.city_id = c.id
JOIN venues v ON e.venue_id = v.id
JOIN destination_intelligence di ON c.id = di.city_id
WHERE e.start_time BETWEEN '2026-10-01 00:00:00+00' AND '2026-10-31 23:59:59+00'
  AND e.tags @> ARRAY['#jazz']
  AND (di.vibe_scores->>'romantic_score')::int >= 80;


-- ==============================================================================
-- SCENARIO B: "Find me high-energy electronic music trips, but prioritize 
--             destinations that closely match a high-intensity summer clubbing vibe vector."
-- ==============================================================================
SELECT 'SCENARIO B' AS test_case;

SELECT 
    c.english_name AS destination,
    e.english_title AS event_name,
    v.name AS venue_location,
    c.airport_code,
    (di.embedding <=> ARRAY_FILL(0.80::real, ARRAY[1536])::vector) AS semantic_distance
FROM events e
JOIN cities c ON e.city_id = c.id
JOIN venues v ON e.venue_id = v.id
JOIN destination_intelligence di ON c.id = di.city_id
WHERE e.tags @> ARRAY['#electronic']
ORDER BY semantic_distance ASC
LIMIT 3;