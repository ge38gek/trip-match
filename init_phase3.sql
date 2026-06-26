-- ========================================================
-- 1. THE AUDIT TRAIL LEDGER (merge_history)
-- ========================================================
CREATE TABLE merge_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entity_type VARCHAR(50) NOT NULL,       -- 'event', 'artist', 'venue'
    
    -- The target record that was consumed, deactivated, or deleted
    source_uuid UUID NOT NULL,              
    
    -- The master golden record that remains active
    destination_uuid UUID NOT NULL,         
    
    merged_by VARCHAR(100) DEFAULT 'system_dedup_v1',
    
    -- A perfect snapshot copy of the exact fields before they were modified or merged
    merge_context JSONB NOT NULL,           
    
    timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);