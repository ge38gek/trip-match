import json
import hashlib
import uuid
import urllib.request
import psycopg2
from psycopg2.extras import RealDictCursor

DB_CONFIG = {
    "host": "localhost",
    "port": 5433,
    "database": "postgres",
    "user": "postgres",
    "password": "password"
}

def fetch_live_provider_payloads():
    """
    Simulates a live network request pulling raw data directly matching 
    the Ticketmaster Discovery API /v2/events.json payload structure.
    """
    print("📡 Fetching latest event data streaming feed...")
    
    # In a fully deployed environment, this replaces with:
    # url = "https://app.ticketmaster.com/discovery/v2/events.json?apikey=YOUR_KEY&city=Berlin"
    # response = urllib.request.urlopen(url).read()
    
    # We explicitly simulate the real-time nested schema structure Ticketmaster feeds back:
    sample_api_response = {
        "_embedded": {
            "events": [
                {
                    "id": "tm-ticket-101010",
                    "name": "Charlotte de Witte - KNTXT Berlin",
                    "dates": {
                        "start": {
                            "dateTime": "2026-10-31T22:00:00Z",
                            "timezone": "Europe/Berlin"
                        },
                        "end": {
                            "dateTime": "2026-11-01T08:00:00Z"
                        }
                    },
                    "classifications": [{"genre": {"name": "Techno"}}],
                    "venue_external_id": "deadeade-adea-dead-ea00-000000000001", # Tresor Berlin
                    "city_external_id": "c1111111-1111-1111-1111-111111111111",  # Berlin
                    "tags": ["#electronic", "#techno", "#kntxt"]
                }
            ]
        }
    }
    return sample_api_response["_embedded"]["events"]

def run_automated_sync():
    print("⚡ Launching TripMatch Orchestrator Loop...")
    conn = psycopg2.connect(**DB_CONFIG)
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    job_id = str(uuid.uuid4())
    provider = "ticketmaster_v2"
    
    # 1. Log Ingestion Job run entry
    cursor.execute(
        "INSERT INTO ingestion_jobs (id, provider_name, status) VALUES (%s, %s, 'running');",
        (job_id, provider)
    )
    conn.commit()
    
    try:
        raw_events = fetch_live_provider_payloads()
        imported = 0
        skipped = 0
        
        for ext_event in raw_events:
            # Generate immutable hash fingerprint from the raw data block
            serialized_payload = json.dumps(ext_event, sort_keys=True)
            payload_hash = hashlib.sha256(serialized_payload.encode('utf-8')).hexdigest()
            
            # De-duplication Protection check via exact fingerprint lookup
            cursor.execute(
                "SELECT id FROM raw_payloads WHERE provider_name = %s AND provider_event_id = %s AND payload_hash = %s;",
                (provider, ext_event["id"], payload_hash)
            )
            if cursor.fetchone():
                skipped += 1
                continue
                
            # Store raw provider data payload
            cursor.execute(
                """
                INSERT INTO raw_payloads (job_id, provider_name, provider_event_id, payload_json, payload_hash, processing_status)
                VALUES (%s, %s, %s, %s, %s, 'processed');
                """,
                (job_id, provider, ext_event["id"], serialized_payload, payload_hash)
            )
            
            # Map items to our master database tables
            canonical_id = str(uuid.uuid4())
            cursor.execute(
                """
                INSERT INTO events (id, venue_id, city_id, original_title, english_title, start_time, end_time, timezone, tags)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
                """,
                (
                    canonical_id, 
                    ext_event["venue_external_id"], 
                    ext_event["city_external_id"],
                    ext_event["name"], 
                    ext_event["name"],
                    ext_event["dates"]["start"]["dateTime"],
                    ext_event["dates"]["end"]["dateTime"],
                    ext_event["dates"]["start"]["timezone"],
                    ext_event["tags"]
                )
            )
            
            # Record structural mapping route entry
            cursor.execute(
                "INSERT INTO source_mappings (provider_name, external_id, entity_type, canonical_id) VALUES (%s, %s, 'event', %s);",
                (provider, ext_event["id"], canonical_id)
            )
            imported += 1
            print(f"📡 Event Parsed & Ingested: {ext_event['name']}")
            
        # Update job progress tracking stats
        cursor.execute(
            """
            UPDATE ingestion_jobs 
            SET status = 'completed', finished_at = CURRENT_TIMESTAMP, 
                records_found = %s, records_imported = %s, duplicates_found = %s
            WHERE id = %s;
            """,
            (len(raw_events), imported, skipped, job_id)
        )
        conn.commit()
        print(f"📊 Completed. New Records Added: {imported} | Duplicates Blocked: {skipped}")
        
    except Exception as e:
        conn.rollback()
        cursor.execute("UPDATE ingestion_jobs SET status = 'failed', error_log = %s WHERE id = %s;", (str(e), job_id))
        conn.commit()
        print(f"❌ Automation Error Encountered: {e}")
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    run_automated_sync()