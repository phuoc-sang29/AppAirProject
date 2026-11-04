import requests
from datetime import datetime, timezone
from db import upsert_batch, create_table

LAT = 10.9807
LON = 106.6753
API_URL = (
    f"https://air-quality-api.open-meteo.com/v1/air-quality"
    f"?latitude={LAT}&longitude={LON}"
    f"&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"
    f"&past_days=10&forecast_days=1"
)

def collect():
    try:
        response = requests.get(API_URL, timeout=30)
        response.raise_for_status()
        data = response.json()
        hourly = data.get("hourly", {})

        times = hourly.get("time", [])
        pm10_list = hourly.get("pm10", [])
        pm25_list = hourly.get("pm2_5", [])
        co_list = hourly.get("carbon_monoxide", [])
        no2_list = hourly.get("nitrogen_dioxide", [])
        so2_list = hourly.get("sulphur_dioxide", [])
        o3_list = hourly.get("ozone", [])

        records = []
        for i, t in enumerate(times):
            pm10 = pm10_list[i] if i < len(pm10_list) else None
            pm25 = pm25_list[i] if i < len(pm25_list) else None
            co = co_list[i] if i < len(co_list) else None
            no2 = no2_list[i] if i < len(no2_list) else None
            so2 = so2_list[i] if i < len(so2_list) else None
            o3 = o3_list[i] if i < len(o3_list) else None

            if None in (pm10, pm25, co, no2, so2, o3):
                continue

            records.append((t, pm10, pm25, co, no2, so2, o3))

        upsert_batch(records)
        print(f"[{datetime.now()}] Da luu {len(records)} ban ghi vao ca Local va Supabase.")

    except Exception as e:
        print(f"[{datetime.now()}] Loi thu thap du lieu: {e}")

if __name__ == "__main__":
    create_table()
    collect()
