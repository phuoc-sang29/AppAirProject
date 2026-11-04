import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "data_pipeline", ".env"))

import pandas as pd
import requests
import psycopg2
from datetime import datetime, date, timedelta

LAT = 10.9807
LON = 106.6753

def get_conn():
    return psycopg2.connect(os.getenv("DATABASE_URL"))

def get_last_date(conn):
    cur = conn.cursor()
    cur.execute("SELECT MAX(recorded_at) FROM air_quality")
    result = cur.fetchone()[0]
    cur.close()
    if result is None:
        return date(2026, 8, 21)
    if hasattr(result, 'date'):
        return result.date()
    return datetime.strptime(str(result)[:10], "%Y-%m-%d").date()

def fetch_openmeteo(start, end):
    url = (
        "https://air-quality-api.open-meteo.com/v1/air-quality"
        f"?latitude={LAT}&longitude={LON}"
        "&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
        f"&start_date={start}&end_date={end}"
    )
    print(f"Fetching: {start} -> {end}")
    res = requests.get(url, timeout=30)
    res.raise_for_status()
    return res.json()["hourly"]

def clean_series(values):
    s = pd.Series(values, dtype=float)
    s = s.ffill().bfill()
    s = s.fillna(0)
    return s.tolist()

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

def main():
    conn = get_conn()
    last = get_last_date(conn)
    start_date = last + timedelta(days=1)
    end_date = date.today() - timedelta(days=1)

    if start_date > end_date:
        print(f"Du lieu da cap nhat den: {last}. Khong can cap nhat.")
        conn.close()
        return

    print(f"Cap nhat du lieu tu {start_date} den {end_date}")

    chunk_days = 30
    current = start_date
    total = 0

    while current <= end_date:
        chunk_end = min(current + timedelta(days=chunk_days - 1), end_date)
        try:
            data = fetch_openmeteo(str(current), str(chunk_end))
            times = data["time"]
            pm10_c = clean_series(data["pm10"])
            pm25_c = clean_series(data["pm2_5"])
            co_c   = clean_series(data["carbon_monoxide"])
            no2_c  = clean_series(data["nitrogen_dioxide"])
            so2_c  = clean_series(data["sulphur_dioxide"])
            o3_c   = clean_series(data["ozone"])

            for i, t in enumerate(times):
                upsert(conn, t, pm10_c[i], pm25_c[i], co_c[i], no2_c[i], so2_c[i], o3_c[i])
                total += 1

            conn.commit()
            print(f"  Luu {len(times)} ban ghi ({current} - {chunk_end})")
        except Exception as e:
            print(f"  Loi chunk {current}: {e}")
            conn.rollback()

        current = chunk_end + timedelta(days=1)

    cur = conn.cursor()
    cur.execute("SELECT COUNT(*), MIN(recorded_at), MAX(recorded_at) FROM air_quality")
    cnt, mn, mx = cur.fetchone()
    cur.close()
    conn.close()

    print(f"\nHoan thanh! Them {total} ban ghi moi.")
    print(f"Tong cong: {cnt} ban ghi")
    print(f"Tu: {mn}")
    print(f"Den: {mx}")

if __name__ == "__main__":
    main()
