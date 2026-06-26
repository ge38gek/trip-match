import urllib.request
import urllib.parse
import json

class TicketmasterProvider:
    def __init__(self, api_key: str):
        self.api_key = "tUzMAZSDKALtOAGiAwOaIFrgRJLBbB7m"
        self.base_url = "https://app.ticketmaster.com/discovery/v2/events.json"

    def fetch_city_music_events(self, city_name: str, country_code: str):
        """
        Queries live Ticketmaster instances for upcoming electronic/music concerts
        """
        params = {
            "apikey": self.api_key,
            "city": city_name,
            "countryCode": country_code,
            "classificationName": "music",
            "size": 50
        }
        
        url_values = urllib.parse.urlencode(params)
        full_url = f"{self.base_url}?{url_values}"
        
        try:
            print(f"📡 Dispatching Live HTTP GET request to Ticketmaster for {city_name}...")
            req = urllib.request.Request(full_url, headers={'User-Agent': 'TripMatchBot/1.0'})
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode('utf-8'))
                
            raw_events = data.get("_embedded", {}).get("events", [])
            return self._normalize_schema(raw_events)
        except Exception as e:
            print(f"❌ Ticketmaster Network Extraction Failure: {e}")
            return []

    def _normalize_schema(self, raw_events: list) -> list:
        """
        Translates erratic multi-vendor properties into TripMatch canonical values
        """
        normalized = []
        for event in raw_events:
            try:
                # Safely parse deeply nested values
                venues = event.get("_embedded", {}).get("venues", [{}])
                venue_name = venues[0].get("name", "Unknown Venue")
                venue_id = venues[0].get("id", f"tm-venue-{venue_name}")
                
                normalized.append({
                    "provider_event_id": event["id"],
                    "title": event["name"],
                    "venue_name": venue_name,
                    "venue_external_id": venue_id,
                    "start_time": event["dates"]["start"].get("dateTime"),
                    "timezone": event["dates"]["start"].get("timezone", "UTC"),
                    "tags": [f"#{cat['genre']['name'].lower()}" for cat in event.get("classifications", []) if 'genre' in cat],
                    "raw_data": event  # Keep copy for immutable raw_payload storage vault
                })
            except KeyError:
                continue
        return normalized