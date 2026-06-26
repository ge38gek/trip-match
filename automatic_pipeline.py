import json
import hashlib
import uuid
import psycopg2
from psycopg2.extras import RealDictCursor
from pipeline.providers.ticketmaster import TicketmasterProvider

# Replace this with your actual key from developer.ticketmaster.com
TICKETMASTER_API_KEY = "tUzMAZSDKALtOAGiAwOaIFrgRJLBbB7m"

DB_CONFIG = {
    "host": "localhost",
    "port": 5433,
    "database": "postgres",
    "user": "postgres",
    "password": "password"
}

def run_global_sync():
    print("⚡ [ORCHESTRATOR] Launching TripMatch Live Sync Engine...")
    
    # 1. Initialize DB Connection and Provider Driver
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    provider_name = "ticketmaster_v2"
    driver = TicketmasterProvider(api_key=TICKETMASTER_API_KEY)
    
    # 2. Query the core database for active target routing destinations
    cursor.execute("SELECT id, name, english_name, country_code FROM cities;")
    target_cities = cursor.fetchall()
    
    print(f"🗺️  Found {len(target_cities)} destination targets in database to sync.")
    
    for city in target_cities:
        print(f"\n🚀 Processing Sector: {city['english_name']} ({city['country_code']})")
        
        # Open a distinct operational tracking job profile for this city sequence
        job_id = str(uuid.uuid4())
        cursor.execute(
            """
            INSERT INTO ingestion_jobs (id, provider_name, target_city_id, status) 
            VALUES (%s, %s, %s, 'running');
            """,
            (job_id, provider_name, city['id'])
        )
        conn.commit()
        
        # Fetch the live stream payload from Ticketmaster API
        raw_events = driver.fetch_city_music_events(
            city_name=city['english_name'], 
            country_code=city['country_code']
        )
        
        records_found = len(raw_events)
        records_imported = 0
        duplicates_blocked = 0
        
        for item in raw_events:
            # Generate immutable SHA-256 fingerprint hash of the item payload
            serialized_payload = json.dumps(item, sort_keys=True)
            payload_hash = hashlib.sha256(serialized_payload.encode('utf-8')).hexdigest()
            
            # De-duplication check
            cursor.execute(
                """
                SELECT id FROM raw_payloads 
                WHERE provider_name = %s AND provider_event_id = %s AND payload_hash = %s;
                """,
                (provider_name, item['provider_event_id'], payload_hash)
            )
            if cursor.fetchone():
                duplicates_blocked += 1
                continue
                
            # --- Foreign Key Dependency Safeguard ---
            # Check if the provider's venue ID exists inside our database mapping table
            cursor.execute(
                "SELECT canonical_id FROM source_mappings WHERE provider_name = %s AND external_id = %s AND entity_type = 'venue';",
                (provider_name, item['venue_external_id'])
            )
            venue_map = cursor.fetchone()
            
            if venue_map:
                resolved_venue_id = venue_map['canonical_id']
            else:
                # If the venue is new, instantly auto-generate it in the database to prevent foreign key errors
                resolved_venue_id = str(uuid.uuid4())
                cursor.execute(
                    """
                    INSERT INTO venues (id, city_id, name, coordinates, timezone)
                    VALUES (%s, %s, %s, point(0,0), %s) ON CONFLICT DO NOTHING;
                    """,
                    (resolved_venue_id, city['id'], item['venue_name'], item['timezone'])
                )
                # Map the reference for future pipeline runs
                cursor.execute(
                    "INSERT INTO source_mappings (provider_name, external_id, entity_type, canonical_id) VALUES (%s, %s, 'venue', %s);",
                    (provider_name, item['venue_external_id'], resolved_venue_id)
                )
            
            # 3. Store raw API data block securely inside Vault
            cursor.execute(
                """
                INSERT INTO raw_payloads (job_id, provider_name, provider_event_id, payload_json, payload_hash, processing_status)
                VALUES (%s, %s, %s, %s, %s, 'processed');
                """,
                (job_id, provider_name, item['provider_event_id'], json.dumps(item['raw_data']), payload_hash)
            )
            
            # 4. Write record cleanly to Core Events engine
            canonical_event_id = str(uuid.uuid4())
            # Default fallback dates if API returns empty values
            start_dt = item['start_time'] if item['start_time'] else '2026-10-15T20:00:00Z'
            end_dt = item['start_time'] if item['start_time'] else '2026-10-16T02:00:00Z'
            
            cursor.execute(
                """
                INSERT INTO events (id, venue_id, city_id, original_title, english_title, start_time, end_time, timezone, tags)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (canonical_event_id, resolved_venue_id, city['id'], item['title'], item['title'], start_dt, end_dt, item['timezone'], item['tags'])
            )
            
            # 5. Connect mappings route trace
            cursor.execute(
                "INSERT INTO source_mappings (provider_name, external_id, entity_type, canonical_id) VALUES (%s, %s, 'event', %s);",
                (provider_name, item['provider_event_id'], canonical_event_id)
            )
            records_imported += 1
            
        # Complete Job run cycle telemetry profiling logs
        cursor.execute(
            """
            UPDATE ingestion_jobs 
            SET status = 'completed', finished_at = CURRENT_TIMESTAMP,
                records_found = %s, records_imported = %s, duplicates_found = %s
            WHERE id = %s;
            """,
            (records_found, records_imported, duplicates_blocked, job_id)
        )
        conn.commit()
        print(f"📊 {city['english_name']} complete: +{records_imported} added | {duplicates_blocked} skipped.")
        
    cursor.close()
    conn.close()
    print("\n🏁 Global Sync Sequence Completed Successfully.")

if __name__ == "__main__":
    run_global_sync()