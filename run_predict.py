import sys
import os
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service"))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service", ".env"))

import psycopg2
from predict import predict, LOOK_BACK, FEATURES
from notify import get_notification

print("=== Test du bao tu database ===")

conn = psycopg2.connect(os.getenv("DATABASE_URL"))
cur = conn.cursor()
cur.execute(
    f"""
    SELECT pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone
    FROM air_quality
    ORDER BY recorded_at DESC
    LIMIT {LOOK_BACK}
    """
)
rows = cur.fetchall()
cur.close()
conn.close()

print(f"So ban ghi lay tu DB: {len(rows)}")

if len(rows) < LOOK_BACK:
    print(f"Can it nhat {LOOK_BACK} ban ghi. Hien co {len(rows)}.")
    print("Dang dung du lieu gia lap de test...")
    import pandas as pd
    import numpy as np
    df = pd.read_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)), "TLTK_BCTN", "Data_ThuDauMot_1Nam.csv"))
    rows = df[FEATURES].tail(LOOK_BACK).values.tolist()

rows_ordered = list(reversed(rows)) if len(rows) == LOOK_BACK else rows
result = predict(rows_ordered)

print(f"\nDu bao PM2.5 trong {result['hours_ahead']} gio toi:")
for i, val in enumerate(result["forecast_pm2_5"]):
    print(f"  +{i+1:02d}h: {val:.2f} ug/m3")

print(f"\nSai so mo hinh:")
print(f"  RMSE = {result['rmse']:.4f} ug/m3")
print(f"  MAE  = {result['mae']:.4f} ug/m3")

max_pm25 = max(result["forecast_pm2_5"])
print(f"\n=== Kiem tra canh bao ===")
for group in ["binh_thuong", "tre_em", "hen_suyen", "benh_ho_hap"]:
    notif = get_notification(max_pm25, group)
    msg_safe = notif["message"][:60].encode("ascii", "replace").decode("ascii")
    print(f"[{group}] Muc: {notif['level']} | {msg_safe}")
