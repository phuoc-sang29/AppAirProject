import os
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
import json

import time
import subprocess
from datetime import datetime

try:
    import requests
except ImportError:
    print("[!] Thieu requests. Cai bang: pip install requests")
    sys.exit(1)

try:
    import psycopg2
    from dotenv import load_dotenv
    load_dotenv(os.path.join(os.path.dirname(__file__), "ai_service", ".env"))
except ImportError:
    pass

AI_URL      = os.getenv("AI_SERVICE_URL", "http://localhost:8000")
BACKEND_URL = os.getenv("BACKEND_URL",    "http://localhost:3000")
FLUTTER_URL = "http://localhost:8080"
DB_URL      = os.getenv("DATABASE_URL", "")

PASS = "PASS"
FAIL = "FAIL"
SKIP = "SKIP"

results = []

def log(status, label, detail=""):
    color = {"PASS": "\033[92m", "FAIL": "\033[91m", "SKIP": "\033[93m"}.get(status, "")
    reset = "\033[0m"
    icon  = {"PASS": "OK", "FAIL": "FAIL", "SKIP": "--"}.get(status, "?")
    print(f"  [{icon}] {label}")
    if detail:
        print(f"       {detail}")
    results.append({"status": status, "label": label, "detail": detail})

def section(title):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")

def http_get(url, timeout=5):
    try:
        r = requests.get(url, timeout=timeout)
        return r.status_code, r.json() if r.headers.get("content-type","").startswith("application/json") else r.text
    except requests.exceptions.ConnectionError:
        return None, "Connection refused"
    except requests.exceptions.Timeout:
        return None, "Timeout"
    except Exception as e:
        return None, str(e)

def http_post(url, payload, timeout=5):
    try:
        r = requests.post(url, json=payload, timeout=timeout)
        return r.status_code, r.json() if r.headers.get("content-type","").startswith("application/json") else r.text
    except requests.exceptions.ConnectionError:
        return None, "Connection refused"
    except Exception as e:
        return None, str(e)

print("\n" + "=" * 60)
print("  KIỂM TRA HỆ THỐNG APPAIR – DEMO HỘI ĐỒNG")
print(f"  Thời gian: {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}")
print("=" * 60)

section("1. CƠ SỞ DỮ LIỆU (Supabase / PostgreSQL)")

if DB_URL:
    try:
        conn = psycopg2.connect(DB_URL, connect_timeout=10)
        cur  = conn.cursor()

        cur.execute("SELECT COUNT(*) FROM air_quality")
        total = cur.fetchone()[0]
        log(PASS, "Kết nối Supabase PostgreSQL", f"Thành công")

        log(PASS, "Bảng air_quality", f"Có {total:,} bản ghi")

        cur.execute("SELECT recorded_at FROM air_quality ORDER BY recorded_at DESC LIMIT 1")
        last = cur.fetchone()
        if last:
            log(PASS, "Bản ghi mới nhất", str(last[0]))

        cur.execute("SELECT COUNT(*) FROM users")
        u = cur.fetchone()[0]
        log(PASS, "Bảng users", f"{u} người dùng")

        cur.execute("SELECT COUNT(*) FROM ratings")
        r = cur.fetchone()[0]
        log(PASS, "Bảng ratings", f"{r} đánh giá")

        cur.close()
        conn.close()
    except Exception as e:
        log(FAIL, "Kết nối Supabase", str(e))
else:
    log(SKIP, "DATABASE_URL chưa được cấu hình trong .env")

section("2. AI SERVICE (Python FastAPI – port 8000)")

print(f"\n  URL: {AI_URL}")
print("  Lệnh khởi động: cd ai_service && uvicorn main:app --host 0.0.0.0 --port 8000 --reload\n")

code, data = http_get(f"{AI_URL}/docs", timeout=3)
if code == 200:
    log(PASS, "AI Service đang chạy", f"HTTP {code}")
elif code is None:
    log(FAIL, "AI Service chưa khởi động", data)
    print("\n  Chạy lệnh sau để khởi động:")
    print("  cd D:\\AppAir\\ai_service")
    print("  uvicorn main:app --host 0.0.0.0 --port 8000 --reload")
else:
    log(FAIL, "AI Service lỗi", f"HTTP {code}")

code, data = http_get(f"{AI_URL}/current")
if code == 200 and isinstance(data, dict):
    pm25 = data.get("pm2_5", "N/A")
    ts   = data.get("recorded_at", "N/A")
    log(PASS, "GET /current", f"PM2.5={pm25} µg/m³ | Thời gian={ts}")
elif code is None:
    log(FAIL, "GET /current – Service chưa chạy", str(data))
else:
    log(FAIL, "GET /current", f"HTTP {code}: {str(data)[:80]}")

code, data = http_get(f"{AI_URL}/predict", timeout=15)
if code == 200 and isinstance(data, dict):
    fc = data.get("forecast_pm2_5", [])
    rmse = data.get("rmse", "N/A")
    log(PASS, "GET /predict", f"{len(fc)} giờ dự báo | RMSE={rmse}")
    if fc:
        lo, hi = min(fc), max(fc)
        log(PASS, "  Kết quả dự báo", f"Min={lo:.1f} | Max={hi:.1f} µg/m³")
elif code is None:
    log(FAIL, "GET /predict – Service chưa chạy hoặc model chưa sẵn sàng", str(data))
else:
    log(FAIL, "GET /predict", f"HTTP {code}: {str(data)[:80]}")

code, data = http_get(f"{AI_URL}/metrics")
if code == 200 and isinstance(data, dict):
    ev   = data.get("evaluation", {})
    arch = data.get("model", {}).get("architecture", "N/A")
    log(PASS, "GET /metrics", f"Kiến trúc={arch} | RMSE={ev.get('rmse','N/A')} | MAE={ev.get('mae','N/A')}")
elif code is None:
    log(FAIL, "GET /metrics", str(data))
else:
    log(FAIL, "GET /metrics", f"HTTP {code}")

code, data = http_post(f"{AI_URL}/notify/check",
                       {"pm2_5": 35.0, "health_group": "hen_suyen"})
if code == 200 and isinstance(data, dict):
    level = data.get("level", "N/A")
    msg   = data.get("message", "")[:60]
    log(PASS, "POST /notify/check", f"Level={level} | {msg}...")
elif code is None:
    log(FAIL, "POST /notify/check", str(data))
else:
    log(FAIL, "POST /notify/check", f"HTTP {code}")

section("3. BACKEND API (Node.js Express – port 3000)")

print(f"\n  URL: {BACKEND_URL}")
print("  Lệnh khởi động: cd D:\\AppAir\\backend && npm start\n")

code, data = http_get(f"{BACKEND_URL}/api/air/history")
if code == 200 and isinstance(data, list):
    log(PASS, "GET /api/air/history", f"Trả về {len(data)} bản ghi")
    if data:
        last_rec = data[-1]
        log(PASS, "  Bản ghi cuối", f"Time={last_rec.get('recorded_at','?')} | PM2.5={last_rec.get('pm2_5','?')}")
elif code is None:
    log(FAIL, "Backend chưa khởi động", str(data))
    print("\n  Chạy lệnh sau để khởi động:")
    print("  cd D:\\AppAir\\backend && npm start")
else:
    log(FAIL, "GET /api/air/history", f"HTTP {code}: {str(data)[:60]}")

code, data = http_get(f"{BACKEND_URL}/api/air/current")
if code == 200 and isinstance(data, dict):
    log(PASS, "GET /api/air/current", f"PM2.5={data.get('pm2_5','N/A')}")
elif code is None:
    log(FAIL, "GET /api/air/current (cần AI Service chạy trước)", str(data))
else:
    log(FAIL, "GET /api/air/current", f"HTTP {code}")

code, data = http_get(f"{BACKEND_URL}/api/air/forecast")
if code == 200 and isinstance(data, dict):
    log(PASS, "GET /api/air/forecast", f"Trả về {len(data.get('forecast_pm2_5',[]))} giờ dự báo")
elif code is None:
    log(FAIL, "GET /api/air/forecast (cần AI Service chạy trước)", str(data))
else:
    log(FAIL, "GET /api/air/forecast", f"HTTP {code}")

section("4. FLUTTER WEB APP (port 8080)")

print(f"\n  URL: {FLUTTER_URL}")
print("  Lệnh khởi động: cd D:\\AppAir\\mobile && flutter run -d chrome --web-port 8080\n")

code, data = http_get(FLUTTER_URL, timeout=3)
if code == 200:
    log(PASS, "Flutter Web App đang chạy", f"HTTP {code} tại {FLUTTER_URL}")
elif code is None:
    log(FAIL, "Flutter chưa khởi động", str(data))
    print("\n  Chạy lệnh sau để khởi động:")
    print("  cd D:\\AppAir\\mobile")
    print("  flutter run -d chrome --web-port 8080")
else:
    log(FAIL, "Flutter", f"HTTP {code}")

env_path = os.path.join(os.path.dirname(__file__), "mobile", ".env")
if os.path.exists(env_path):
    log(PASS, "File mobile/.env tồn tại")
    with open(env_path) as f:
        keys = [l.split("=")[0].strip() for l in f if "=" in l and not l.startswith("#")]
    log(PASS, "  Các biến cấu hình", " | ".join(keys))
else:
    log(FAIL, "File mobile/.env KHÔNG TỒN TẠI", "Cần kiểm tra lại")

section("5. KIỂM TRA FILE MODEL AI")

ai_dir = os.path.join(os.path.dirname(__file__), "ai_service")
model_files = {
    "model.keras": "Mô hình CNN+LSTM đã huấn luyện",
    "scaler.pkl":  "MinMaxScaler (chuẩn hóa dữ liệu)",
    "metrics.txt": "Chỉ số RMSE/MAE trên tập test",
}
for fname, desc in model_files.items():
    fp = os.path.join(ai_dir, fname)
    if os.path.exists(fp):
        kb = os.path.getsize(fp) / 1024
        log(PASS, f"{fname} ({desc})", f"{kb:.0f} KB")
    else:
        log(FAIL, f"{fname} KHÔNG TỒN TẠI", f"Cần chạy: python ai_service/train.py")

eval_dir = os.path.join(ai_dir, "eval")
if os.path.isdir(eval_dir):
    charts = [f for f in os.listdir(eval_dir) if f.endswith(".png") or f.endswith(".md")]
    log(PASS, f"Thư mục eval/ có {len(charts)} biểu đồ", " | ".join(charts))
else:
    log(SKIP, "Chưa tạo biểu đồ", "Chạy: python ai_service/generate_charts.py")

section("6. THỐNG KÊ KẾT QUẢ")

total_tests = len(results)
passed = sum(1 for r in results if r["status"] == PASS)
failed = sum(1 for r in results if r["status"] == FAIL)
skipped = sum(1 for r in results if r["status"] == SKIP)

print(f"\n  Tổng số kiểm tra : {total_tests}")
print(f"  Thành công (PASS): {passed}")
print(f"  Thất bại   (FAIL): {failed}")
print(f"  Bỏ qua     (SKIP): {skipped}")
print(f"\n  Tỉ lệ đạt : {passed / max(total_tests - skipped, 1) * 100:.0f}%")

if failed == 0:
    print("\n  HỆ THỐNG HOẠT ĐỘNG HOÀN TOÀN – SẴN SÀNG DEMO!")
elif failed <= 2:
    print("\n  Có một vài dịch vụ chưa khởi động (xem chi tiết ở trên).")
else:
    print("\n  CẢNH BÁO: Nhiều dịch vụ bị lỗi. Kiểm tra lại trước khi demo.")

report_path = os.path.join(os.path.dirname(__file__), "verify_report.json")
with open(report_path, "w", encoding="utf-8") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "summary": {"total": total_tests, "passed": passed, "failed": failed, "skipped": skipped},
        "results": results,
    }, f, ensure_ascii=False, indent=2)
print(f"\n  Bao cao chi tiet: {report_path}")
print("=" * 60 + "\n")
