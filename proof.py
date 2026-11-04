import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "ai_service", ".env"))

import psycopg2
import numpy as np
import pandas as pd
import joblib
import math
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta
from tensorflow.keras.models import load_model
from sklearn.metrics import mean_squared_error, mean_absolute_error

FEATURES = ["pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"]
TARGET_IDX = FEATURES.index("pm2_5")
LOOK_BACK = 24
FORECAST_STEPS = 24

AI_DIR = os.path.join(os.path.dirname(__file__), "ai_service")
MODEL_PATH = os.path.join(AI_DIR, "model.keras")
SCALER_PATH = os.path.join(AI_DIR, "scaler.pkl")
METRICS_PATH = os.path.join(AI_DIR, "metrics.txt")

print("=" * 60)
print("CHUNG MINH MO HINH 1D-CNN + LSTM DA CHAY THANH CONG")
print("De tai: Giam sat va Du bao Chat luong Khong khi - Thu Dau Mot")
print("=" * 60)

print("\n[1] CAU TRUC MO HINH 1D-CNN + LSTM")
print("-" * 60)
model = load_model(MODEL_PATH)
model.summary()

print("\n[2] KET QUA DANH GIA SAI SO TREN TAP TEST")
print("-" * 60)
rmse, mae = 0.0, 0.0
with open(METRICS_PATH) as f:
    for line in f:
        if line.startswith("RMSE="):
            rmse = float(line.split("=")[1])
        elif line.startswith("MAE="):
            mae = float(line.split("=")[1])
print(f"  RMSE (Root Mean Square Error) = {rmse:.4f} ug/m3")
print(f"  MAE  (Mean Absolute Error)    = {mae:.4f} ug/m3")
print(f"  => Mo hinh sai lech trung binh {mae:.2f} ug/m3 khi du bao PM2.5")

print("\n[3] DU BAO PM2.5 TRONG 24 GIO TOI")
print("-" * 60)
conn = psycopg2.connect(os.getenv("DATABASE_URL"))
cur = conn.cursor()
cur.execute(f"""
    SELECT recorded_at, {', '.join(FEATURES)}
    FROM air_quality ORDER BY recorded_at DESC LIMIT {LOOK_BACK}
""")
rows = cur.fetchall()

cur.execute("""
    SELECT recorded_at, pm2_5 FROM air_quality
    ORDER BY recorded_at DESC LIMIT 48
""")
history_rows = cur.fetchall()
cur.close()
conn.close()

rows.reverse()
last_time = rows[-1][0]
input_data = [list(r[1:]) for r in rows]

scaler = joblib.load(SCALER_PATH)
scaled = scaler.transform(input_data)
X = scaled.reshape(1, LOOK_BACK, len(FEATURES))
pred_scaled = model.predict(X, verbose=0)[0]

dummy = np.zeros((FORECAST_STEPS, len(FEATURES)))
dummy[:, TARGET_IDX] = pred_scaled
pred_values = scaler.inverse_transform(dummy)[:, TARGET_IDX]

forecast_times = [last_time + timedelta(hours=i+1) for i in range(FORECAST_STEPS)]

for i, (t, v) in enumerate(zip(forecast_times, pred_values)):
    level = "Tot" if v <= 15 else "Trung binh" if v <= 25 else "Kem" if v <= 50 else "Xau"
    print(f"  +{i+1:02d}h ({t.strftime('%H:%M')}): {v:.2f} ug/m3  [{level}]")

print(f"\n  PM2.5 hien tai: {input_data[-1][1]:.2f} ug/m3")
print(f"  PM2.5 dinh cao du bao: {max(pred_values):.2f} ug/m3 tai gio +{pred_values.tolist().index(max(pred_values))+1}")

print("\n[4] VE BIEU DO SO SANH THUC TE vs DU BAO")
print("-" * 60)

history_rows.reverse()
hist_times = [r[0] for r in history_rows]
hist_pm25  = [r[1] for r in history_rows]

fig, ax = plt.subplots(figsize=(14, 6))
fig.patch.set_facecolor("#0f172a")
ax.set_facecolor("#1e293b")

ax.plot(hist_times, hist_pm25, color="#38bdf8", linewidth=2, marker="o",
        markersize=4, label="PM2.5 thuc te (48h qua)")

ax.plot(forecast_times, pred_values, color="#f97316", linewidth=2.5,
        linestyle="--", marker="s", markersize=4, label=f"Du bao CNN+LSTM (24h toi) | RMSE={rmse:.2f}")

ax.axvline(x=last_time, color="#94a3b8", linestyle=":", linewidth=1.5, label="Hien tai")

ax.axhspan(0,  15,  alpha=0.1, color="#22c55e")
ax.axhspan(15, 25,  alpha=0.1, color="#eab308")
ax.axhspan(25, 50,  alpha=0.1, color="#f97316")
ax.axhspan(50, 100, alpha=0.1, color="#ef4444")

ax.text(hist_times[0], 7,   "Tot (<15)",        color="#22c55e", fontsize=8, alpha=0.8)
ax.text(hist_times[0], 19,  "Trung binh (15-25)", color="#eab308", fontsize=8, alpha=0.8)
ax.text(hist_times[0], 35,  "Kem (25-50)",       color="#f97316", fontsize=8, alpha=0.8)

ax.set_title("Mo hinh 1D-CNN + LSTM: Du bao PM2.5 tai Thu Dau Mot\n"
             f"QCVN 05:2023/BTNMT | RMSE={rmse:.2f} ug/m3 | MAE={mae:.2f} ug/m3",
             color="white", fontsize=13, fontweight="bold", pad=15)
ax.set_xlabel("Thoi gian", color="#94a3b8", fontsize=10)
ax.set_ylabel("PM2.5 (ug/m3)", color="#94a3b8", fontsize=10)
ax.tick_params(colors="#94a3b8")
ax.xaxis.set_major_formatter(mdates.DateFormatter("%d/%m %Hh"))
ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
plt.setp(ax.xaxis.get_majorticklabels(), rotation=45, ha="right")

for spine in ax.spines.values():
    spine.set_edgecolor("#334155")
ax.grid(color="#334155", linestyle="--", linewidth=0.5, alpha=0.7)
ax.legend(facecolor="#1e293b", edgecolor="#334155", labelcolor="white", fontsize=9)

plt.tight_layout()
out_path = os.path.join(os.path.dirname(__file__), "bieu_do_du_bao.png")
plt.savefig(out_path, dpi=150, bbox_inches="tight")
print(f"  Da luu bieu do: {out_path}")
print("\n[HOAN THANH] Tat ca ket qua da duoc xuat ra.")
print("=" * 60)
