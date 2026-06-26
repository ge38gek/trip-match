import streamlit as st
import psycopg2
from psycopg2.extras import RealDictCursor
import plotly.express as px
import pandas as pd

# Page Configuration
st.set_page_config(page_title="TripMatch | AI Architecture Control Center", page_icon="✈️", layout="wide")

DB_CONFIG = {
    "host": "localhost",
    "port": 5433,
    "database": "postgres",
    "user": "postgres",
    "password": "password"
}

def get_db_connection():
    return psycopg2.connect(**DB_CONFIG)

# Custom Styling
st.markdown("""
    <style>
    .main { background-color: #0f1116; color: #ffffff; }
    h1, h2, h3 { color: #00ffd0 !important; font-family: 'Inter', sans-serif; }
    .stButton>button { background-color: #00ffd0; color: #000; border-radius: 5px; font-weight: bold; }
    </style>
    """, unsafe_allow_html=True)

st.title("✈️ TripMatch // AI Travel Knowledge Graph")
st.write("Production Dashboard running directly on top of Docker PostgreSQL + `pgvector` extension.")

# ==============================================================================
# SIDEBAR METRICS & INGESTION STATUS
# ==============================================================================
st.sidebar.header("📡 Ingestion Telemetry")

try:
    conn = get_db_connection()
    cursor = conn.cursor(cursor_factory=RealDictCursor)
    
    # Fetch Counts
    cursor.execute("SELECT COUNT(*) FROM cities;")
    city_count = cursor.fetchone()['count']
    
    cursor.execute("SELECT COUNT(*) FROM events;")
    event_count = cursor.fetchone()['count']
    
    cursor.execute("SELECT COUNT(*) FROM raw_payloads;")
    payload_count = cursor.fetchone()['count']
    
    st.sidebar.metric("Canonical Cities Loaded", city_count)
    st.sidebar.metric("Unified Events Processed", event_count)
    st.sidebar.metric("Raw Payload Vault Size", payload_count)
    
    # Recent Jobs Log
    st.sidebar.subheader("🔄 Pipeline Execution Log")
    cursor.execute("SELECT provider_name, status, records_imported FROM ingestion_jobs ORDER BY started_at DESC LIMIT 4;")
    jobs = cursor.fetchall()
    for job in jobs:
        status_icon = "🟢" if job['status'] == 'completed' else "🟡"
        st.sidebar.text(f"{status_icon} {job['provider_name']} (+{job['records_imported']})")
        
except Exception as e:
    st.sidebar.error(f"Database Offline: {e}")

# ==============================================================================
# MAIN PAGE: HYBRID SEMANTIC SEARCH LAB
# ==============================================================================
st.header("🔍 Hybrid Search Playground")
st.write("Simulate how the travel engine parses user intent vectors paired with strict metadata constraints.")

col1, col2 = st.columns([1, 2])

with col1:
    st.subheader("Filter Matrix")
    # Date constraint placeholder
    st.date_input("Travel Window Start", value=pd.to_datetime("2026-10-01"))
    
    # Vibe Score Constraint
    min_romance = st.slider("Minimum Romance Score Required", 0, 100, 50)
    
    # Core Tag Filtering
    selected_tag = st.selectbox("Select Target Music Genre Filter", ["#electronic", "#jazz", "#techno", "#underground"])
    
    # Semantic Match Profile Selector
    vibe_profile = st.radio(
        "AI Semantic Similarity Targeting Vector",
        ("High-Intensity Summer Clubbing/Festival", "Cozy, Historical Intimate Jazz Getaway")
    )
    
    search_triggered = st.button("Execute Hybrid Graph Query")

with col2:
    st.subheader("Unified Knowledge Graph Results")
    
    if search_triggered:
        # Build Vector Array Parameter depending on toggle selection
        vector_val = 0.80 if "Clubbing" in vibe_profile else 0.22
        
        query = """
        SELECT 
            c.english_name AS destination,
            e.english_title AS event_name,
            v.name AS venue,
            (di.vibe_scores->>'romantic_score')::int AS romance,
            (di.embedding <=> ARRAY_FILL(%s::real, ARRAY[1536])::vector) AS vector_distance,
            e.tags
        FROM events e
        JOIN cities c ON e.city_id = c.id
        JOIN venues v ON e.venue_id = v.id
        JOIN destination_intelligence di ON c.id = di.city_id
        WHERE e.tags @> ARRAY[%s]
          AND (di.vibe_scores->>'romantic_score')::int >= %s
        ORDER BY vector_distance ASC
        LIMIT 5;
        """
        
        cursor.execute(query, (vector_val, selected_tag, min_romance))
        results = cursor.fetchall()
        
        if results:
            df = pd.DataFrame(results)
            # Invert cosine distance to show a "Match Score %"
            df['AI Match Score %'] = ((1 - df['vector_distance']) * 100).round(2)
            
            # Display Clean Table
            st.dataframe(df[['destination', 'event_name', 'venue', 'romance', 'AI Match Score %', 'tags']], use_container_width=True)
            
            # Beautiful Visualization Component
            fig = px.bar(df, x='destination', y='AI Match Score %', color='romance',
                         title="AI Relevance Score vs. Destination Romance Index",
                         labels={'romance': 'Romance Level'},
                         color_continuous_scale=px.colors.sequential.Viridis)
            st.plotly_chart(fig, use_container_width=True)
        else:
            st.info("No destinations matched that explicit mix of constraint scores and vector values. Try lower romance limits!")
            
    else:
        st.info("Adjust the parameters on the left and hit 'Execute Hybrid Graph Query' to watch pgvector work live.")

cursor.close()
conn.close()