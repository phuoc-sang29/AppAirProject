import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

import requests
import psycopg2

print("=== Kiem tra ket noi Supabase ===")
try:
    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    cur = conn.cursor()
    cur.execute("SELECT version()")
    version = cur.fetchone()
    print(f"Ket noi thanh cong: {version[0][:40]}")
    cur.close()
    conn.close()
except Exception as e:
    print(f"Loi ket noi: {e}")

print("\n=== Kiem tra API Open-Meteo ===")
try:
    url = (
        "https://air-quality-api.open-meteo.com/v1/air-quality"
        "?latitude=10.9807&longitude=106.6753"
        "&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
        "&forecast_days=1"
    )
    response = requests.get(url, timeout=15)
    response.raise_for_status()
    data = response.json()
    hourly = data.get("hourly", {})
    times = hourly.get("time", [])
    pm25 = hourly.get("pm2_5", [])
    print(f"Lay duoc {len(times)} ban ghi tu Open-Meteo.")
    if times:
        print(f"Ban ghi dau: time={times[0]}, pm2_5={pm25[0]}")
        print(f"Ban ghi cuoi: time={times[-1]}, pm2_5={pm25[-1]}")
except Exception as e:
    print(f"Loi API: {e}")
