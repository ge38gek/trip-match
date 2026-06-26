-- 1. Simulate an inbound scraping event from Resident Advisor
-- Notice the minor title variations ("Amelie Lens" vs "Amelie Lens Live") and venue name text differences
DO $$
DECLARE
    v_canonical_event_id UUID := 'e3333333-3333-3333-3333-333333333333'; -- Our existing event from Phase 2
    
    -- Inbound data parameters from Resident Advisor
    v_ra_event_title TEXT := 'Amelie Lens';
    v_ra_event_date TIMESTAMPTZ := '2026-10-15 23:00:00+00'; -- Slightly different hour listing
    v_ra_external_id VARCHAR(100) := 'ra-event-554433';
    
    -- Matching score thresholds
    v_title_similarity NUMERIC;
    v_is_duplicate BOOLEAN := FALSE;
BEGIN
    -- Step A: Run a high-performance database trigram match against active events on that night
    SELECT similarity(english_title, v_ra_event_title)
    INTO v_title_similarity
    FROM events
    WHERE start_time::date = v_ra_event_date::date
      AND id = v_canonical_event_id;

    -- Step B: Evaluate if string similarity is greater than a 60% confidence threshold
    IF v_title_similarity > 0.60 THEN
        v_is_duplicate := TRUE;
        
        -- Log the action into our append-only merge history tracking vault before mutating anything
        INSERT INTO merge_history (entity_type, source_uuid, destination_uuid, merge_context)
        VALUES (
            'event',
            '55555555-5555-5555-5555-555555555555'::uuid, -- Generated transient temporary ID
            v_canonical_event_id,
            jsonb_build_object(
                'incoming_title', v_ra_event_title,
                'incoming_provider', 'resident_advisor',
                'similarity_calculated', v_title_similarity
            )
        );

        -- Step C: Map the Resident Advisor ID to point to the same golden Canonical Event
        INSERT INTO source_mappings (provider_name, external_id, entity_type, canonical_id, confidence_score)
        VALUES ('resident_advisor', v_ra_external_id, 'event', v_canonical_event_id, v_title_similarity);
    END IF;
END $$;

-- 2. Verify our Results: Show the unified Knowledge Graph view for this event
SELECT 
    e.english_title AS canonical_master_title,
    string_agg(sm.provider_name, ' & ') AS mapped_data_providers,
    string_agg(sm.external_id, ' , ') AS original_provider_ids,
    mh.merge_context->>'similarity_calculated' AS deduplication_confidence
FROM events e
JOIN source_mappings sm ON e.id = sm.canonical_id
LEFT JOIN merge_history mh ON e.id = mh.destination_uuid
GROUP BY e.english_title, mh.merge_context;