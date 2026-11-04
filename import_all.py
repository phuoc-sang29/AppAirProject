import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "data_pipeline", ".env"))

import pandas as pd
import requests
import psycopg2
from datetime import datetime

FEATURES = ["pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"]
CSV_COLS  = ["pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"]
CSV_PATH  = os.path.join(os.path.dirname(__file__), "TLTK_BCTN", "Data_ThuDauMot_1Nam.csv")

LAT = 10.9807
LON = 106.6753

def get_conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))

def upsert(conn, t, pm10, pm25, co, no2, so2, o3):
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO air_quality (recorded_at, pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (recorded_at) DO UPDATE SET
            pm10=EXCLUDED.pm10, pm2_5=EXCLUDED.pm2_5,
            carbon_monoxide=EXCLUDED.carbon_monoxide,
            nitrogen_dioxide=EXCLUDED.nitrogen_dioxide,
            sulphur_dioxide=EXCLUDED.sulphur_dioxide,
            ozone=EXCLUDED.ozone
    """, (t, pm10, pm25, co, no2, so2, o3))
    cur.close()

def step1_import_csv():
    print("Buoc 1: Nap du lieu CSV (14/7/2025 - 14/7/2026)...")
    df = pd.read_csv(CSV_PATH)
    df = df.ffill().bfill()
    conn = get_conn()
    count = 0
    for _, row in df.iterrows():
        upsert(conn, row["time"], row["pm10"], row["pm2_5"],
               row["carbon_monoxide"], row["nitrogen_dioxide"],
               row["sulphur_dioxide"], row["ozone"])
        count += 1
    conn.commit()
    conn.close()
    print(f"Da nap: {count} ban ghi tu CSV.")

def step2_fill_gap():
    print("Buoc 2: Lay du lieu khoang trong (15/7/2026 - 21/8/2026)...")
    start = "2026-07-15"
    end   = "2026-08-21"
    url = (
        f"https://air-quality-api.open-meteo.com/v1/air-quality"
        f"?latitude={LAT}&longitude={LON}"
        f"&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
        f"&start_date={start}&end_date={end}"
    )
    res = requests.get(url, timeout=30)
    res.raise_for_status()
    data = res.json()["hourly"]

    conn = get_conn()
    count = 0
    for i, t in enumerate(data["time"]):
        pm10 = data["pm10"][i]
        pm25 = data["pm2_5"][i]
        co   = data["carbon_monoxide"][i]
        no2  = data["nitrogen_dioxide"][i]
        so2  = data["sulphur_dioxide"][i]
        o3   = data["ozone"][i]
        if None in (pm10, pm25, co, no2, so2, o3):
            continue
        upsert(conn, t, pm10, pm25, co, no2, so2, o3)
        count += 1
    conn.commit()
    conn.close()
    print(f"Da nap: {count} ban ghi khoang trong.")

def step3_check():
    print("Buoc 3: Kiem tra tong hop...")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT COUNT(*) FROM air_quality")
    total = cur.fetchone()[0]
    cur.execute("SELECT MIN(recorded_at), MAX(recorded_at) FROM air_quality")
    mn, mx = cur.fetchone()
    cur.execute("""
        SELECT recorded_at, COUNT(*) FROM air_quality
        GROUP BY recorded_at HAVING COUNT(*) > 1
    """)
    dups = cur.fetchall()
    cur.close()
    conn.close()
    print(f"Tong so ban ghi : {total}")
    print(f"Tu             : {mn}")
    print(f"Den            : {mx}")
    print(f"Ban ghi trung lap: {len(dups)}")

step1_import_csv()
step2_fill_gap()
step3_check()
