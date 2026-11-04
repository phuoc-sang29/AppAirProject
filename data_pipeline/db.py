import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())


LOCAL_URL = os.getenv("LOCAL_DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
SUPABASE_URL = os.getenv("DATABASE_URL")

def get_local():
    return psycopg2.connect(LOCAL_URL)

def get_supabase():
    return psycopg2.connect(SUPABASE_URL)

DDL = """
    CREATE TABLE IF NOT EXISTS air_quality (
        id SERIAL PRIMARY KEY,
        recorded_at TIMESTAMPTZ NOT NULL UNIQUE,
        pm10 FLOAT,
        pm2_5 FLOAT,
        carbon_monoxide FLOAT,
        nitrogen_dioxide FLOAT,
        sulphur_dioxide FLOAT,
        ozone FLOAT
    )
"""

UPSERT_SQL = """
    INSERT INTO air_quality
        (recorded_at, pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (recorded_at) DO UPDATE SET
        pm10 = EXCLUDED.pm10,
        pm2_5 = EXCLUDED.pm2_5,
        carbon_monoxide = EXCLUDED.carbon_monoxide,
        nitrogen_dioxide = EXCLUDED.nitrogen_dioxide,
        sulphur_dioxide = EXCLUDED.sulphur_dioxide,
        ozone = EXCLUDED.ozone
"""

def create_table():
    for get_conn in [get_local, get_supabase]:
        try:
            conn = get_conn()
            cur = conn.cursor()
            cur.execute(DDL)
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"[db] create_table error: {e}")

def upsert_record(recorded_at, pm10, pm2_5, co, no2, so2, o3):
    upsert_batch([(recorded_at, pm10, pm2_5, co, no2, so2, o3)])

def upsert_batch(records):
    if not records:
        return
    for label, get_conn in [("Local", get_local), ("Supabase", get_supabase)]:
        try:
            conn = get_conn()
            cur = conn.cursor()
            cur.execute("SELECT setval(pg_get_serial_sequence('air_quality', 'id'), COALESCE((SELECT MAX(id) FROM air_quality), 1))")
            psycopg2.extras.execute_batch(cur, UPSERT_SQL, records, page_size=200)
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"[db] upsert to {label} error: {e}")
