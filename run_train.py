import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service"))
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service"))

from train import train

print("=== Bat dau train mo hinh 1D-CNN + LSTM ===")
print("Nguon du lieu: Supabase PostgreSQL")
print("Look-back: 24 gio | Du bao: 24 gio tiep theo")
print("=" * 45)

rmse, mae = train()

print("=" * 45)
print(f"Ket qua danh gia tren tap test:")
print(f"  RMSE = {rmse:.4f} ug/m3")
print(f"  MAE  = {mae:.4f} ug/m3")
print("Model da luu: ai_service/model.keras")
print("Scaler da luu: ai_service/scaler.pkl")
