import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service"))

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ai_service")

print("=== KIỂM TRA METRICS ===")
print(f"Thư mục gốc: {BASE}")

metrics_path = os.path.join(BASE, "metrics.txt")
model_path   = os.path.join(BASE, "model.keras")
scaler_path  = os.path.join(BASE, "scaler.pkl")

print(f"metrics.txt tồn tại: {os.path.exists(metrics_path)}")
print(f"model.keras tồn tại: {os.path.exists(model_path)}")
print(f"scaler.pkl  tồn tại: {os.path.exists(scaler_path)}")

if os.path.exists(metrics_path):
    with open(metrics_path) as f:
        content = f.read()
    print(f"Nội dung metrics.txt:\n{content.strip()}")
else:
    print("Không tìm thấy metrics.txt — cần chạy run_train.py trước")

print("\n=== KIỂM TRA HÀM GET_METRICS() ===")
os.chdir(BASE)
from predict import get_metrics
rmse, mae = get_metrics()
print(f"rmse = {rmse}")
print(f"mae  = {mae}")

print("\n=== KIỂM TRA API QUA HTTP ===")
try:
    import requests
    res = requests.get("http://localhost:8000/metrics", timeout=5)
    print(f"Trạng thái: {res.status_code}")
    print(f"Kết quả: {res.json()}")
except Exception as e:
    print(f"Server chưa chạy hoặc lỗi: {e}")
