import os
import re
import sys
import json
import requests
import psycopg2
import psycopg2.extras
from datetime import datetime, timedelta
from dotenv import load_dotenv, find_dotenv

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from predict import predict, FEATURES, LOOK_BACK
from notify import get_notification

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(find_dotenv())
load_dotenv(os.path.join(BASE_DIR, "..", "mobile", ".env"))
sys.path.insert(0, os.path.join(BASE_DIR, "..", "data_pipeline"))


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    local_url = os.getenv("LOCAL_DATABASE_URL")
    if local_url:
        try:
            return psycopg2.connect(local_url, connect_timeout=3)
        except Exception:
            pass
    return psycopg2.connect(os.getenv("DATABASE_URL"), connect_timeout=8)

def fetch_recent_data():
    conn = get_db()
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
    if len(rows) < LOOK_BACK:
        return None
    rows.reverse()
    return [list(row) for row in rows]

@app.get("/predict")
def api_predict():
    data = fetch_recent_data()
    if data is None:
        raise HTTPException(status_code=400, detail=f"Cần ít nhất {LOOK_BACK} bản ghi trong database.")
    result = predict(data)
    return result

@app.get("/current")
def api_current():
    conn = get_db()
    cur = conn.cursor()
    cur.execute(
        """
        SELECT pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, recorded_at
        FROM air_quality
        ORDER BY recorded_at DESC
        LIMIT 1
        """
    )
    row = cur.fetchone()
    cur.close()
    conn.close()
    if row is None:
        raise HTTPException(status_code=404, detail="Chưa có dữ liệu.")
    return {
        "pm10": row[0],
        "pm2_5": row[1],
        "carbon_monoxide": row[2],
        "nitrogen_dioxide": row[3],
        "sulphur_dioxide": row[4],
        "ozone": row[5],
        "recorded_at": str(row[6]),
    }

class NotifyRequest(BaseModel):
    pm2_5: float
    health_group: str

@app.post("/notify/check")
def api_notify(req: NotifyRequest):
    result = get_notification(req.pm2_5, req.health_group)
    return result

@app.get("/metrics")
def api_metrics():
    from predict import get_metrics, MODEL_PATH, LOOK_BACK, FORECAST_STEPS, FEATURES
    rmse, mae = get_metrics()
    model_size_kb = round(os.path.getsize(MODEL_PATH) / 1024, 1)
    return {
        "model": {
            "architecture": "1D-CNN + LSTM",
            "layers": [
                "Conv1D (64 filters, kernel=3, relu)",
                "MaxPooling1D (pool=2)",
                "Conv1D (32 filters, kernel=3, relu)",
                "LSTM (64 units, return_sequences=True)",
                "Dropout (0.2)",
                "LSTM (32 units)",
                "Dropout (0.2)",
                "Dense (24 outputs)"
            ],
            "trainable_params": 45432,
            "model_size_kb": model_size_kb,
            "look_back_hours": LOOK_BACK,
            "forecast_hours": FORECAST_STEPS,
            "features": FEATURES,
            "target": "pm2_5"
        },
        "evaluation": {
            "rmse": rmse,
            "mae": mae,
            "unit": "ug/m3",
            "standard": "QCVN 05:2023/BTNMT",
            "note": "Danh gia tren tap test 20% du lieu"
        },
        "training": {
            "data_source": "Supabase PostgreSQL",
            "total_records": 9696,
            "train_split": "80%",
            "test_split": "20%",
            "epochs_max": 50,
            "early_stopping_patience": 5,
            "optimizer": "Adam",
            "loss_function": "MSE"
        }
    }

def _sync_auxiliary_tables(get_local, get_supabase):
    try:
        supa = get_supabase()
        loc = get_local()
        scur = supa.cursor()
        lcur = loc.cursor()

        for cur in (scur, lcur):
            cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT")
            cur.execute("UPDATE users SET health_group = 'benh_ho_hap' WHERE health_group = 'hen_suyen'")
        supa.commit()
        loc.commit()

        scur.execute("SELECT id, email, full_name, health_group, role, fcm_token, created_at, COALESCE(is_blocked, false) FROM users")
        for r in scur.fetchall():
            lcur.execute("""
                INSERT INTO users (id, email, full_name, health_group, role, fcm_token, created_at, is_blocked)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    email = EXCLUDED.email,
                    full_name = EXCLUDED.full_name,
                    health_group = EXCLUDED.health_group,
                    role = EXCLUDED.role,
                    fcm_token = COALESCE(EXCLUDED.fcm_token, users.fcm_token),
                    is_blocked = EXCLUDED.is_blocked
            """, r)

        scur.execute("SELECT id, title, category, summary, content, author, is_published, created_at, updated_at FROM news_articles")
        for r in scur.fetchall():
            lcur.execute("""
                INSERT INTO news_articles (id, title, category, summary, content, author, is_published, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    title = EXCLUDED.title,
                    category = EXCLUDED.category,
                    summary = EXCLUDED.summary,
                    content = EXCLUDED.content,
                    author = EXCLUDED.author,
                    is_published = EXCLUDED.is_published,
                    updated_at = EXCLUDED.updated_at
            """, r)

        scur.execute("SELECT id, user_id, message, level, is_read, created_at FROM notifications")
        for r in scur.fetchall():
            lcur.execute("""
                INSERT INTO notifications (id, user_id, message, level, is_read, created_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    message = EXCLUDED.message,
                    level = EXCLUDED.level,
                    is_read = EXCLUDED.is_read
            """, r)

        scur.execute("SELECT id, user_id, stars, feedback, created_at FROM ratings")
        for r in scur.fetchall():
            lcur.execute("""
                INSERT INTO ratings (id, user_id, stars, feedback, created_at)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    stars = EXCLUDED.stars,
                    feedback = EXCLUDED.feedback
            """, r)

        scur.execute("SELECT id, user_id, address, lat, lon, pm25, searched_at FROM map_searches")
        for r in scur.fetchall():
            lcur.execute("""
                INSERT INTO map_searches (id, user_id, address, lat, lon, pm25, searched_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (id) DO UPDATE SET
                    address = EXCLUDED.address,
                    lat = EXCLUDED.lat,
                    lon = EXCLUDED.lon,
                    pm25 = EXCLUDED.pm25,
                    searched_at = EXCLUDED.searched_at
            """, r)

        for tbl in ("news_articles", "notifications", "map_searches"):
            lcur.execute(f"SELECT setval(pg_get_serial_sequence('{tbl}', 'id'), COALESCE((SELECT MAX(id) FROM {tbl}), 1))")

        loc.commit()
        scur.close()
        lcur.close()
        supa.close()
        loc.close()
    except Exception:
        pass

@app.get("/geocode")
def api_geocode(q: str):
    q_clean = q.strip()
    if not q_clean:
        return {"candidates": []}
    search_text = q_clean
    if "bình dương" not in q_clean.lower() and "thủ dầu một" not in q_clean.lower():
        search_text = f"{q_clean}, Thủ Dầu Một, Bình Dương, Việt Nam"
    try:
        url = "https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/findAddressCandidates"
        params = {
            "SingleLine": search_text,
            "location": "106.6753,10.9807",
            "distance": 25000,
            "countryCode": "VNM",
            "maxLocations": 6,
            "outFields": "Match_addr,PlaceName,StAddr,City,Subregion",
            "f": "json",
        }
        r = requests.get(url, params=params, timeout=7)
        if r.status_code == 200:
            data = r.json()
            cands = []
            for c in data.get("candidates", []):
                loc = c.get("location", {})
                lat = loc.get("y")
                lon = loc.get("x")
                addr = c.get("address") or q_clean
                if lat is not None and lon is not None:
                    cands.append({
                        "name": addr,
                        "lat": float(lat),
                        "lon": float(lon),
                        "score": c.get("score", 0),
                    })
            return {"candidates": cands}
    except Exception as e:
        return {"candidates": [], "error": str(e)}
    return {"candidates": []}

@app.post("/sync")
def api_sync():
    try:
        from collect import API_URL
        from db import get_local, get_supabase, UPSERT_SQL
        res = requests.get(API_URL, timeout=25)
        res.raise_for_status()
        hourly = res.json().get("hourly", {})
        times = hourly.get("time", [])
        pm10_list = hourly.get("pm10", [])
        pm25_list = hourly.get("pm2_5", [])
        co_list = hourly.get("carbon_monoxide", [])
        no2_list = hourly.get("nitrogen_dioxide", [])
        so2_list = hourly.get("sulphur_dioxide", [])
        o3_list = hourly.get("ozone", [])

        records = []
        for i, t in enumerate(times):
            vals = (
                pm10_list[i] if i < len(pm10_list) else None,
                pm25_list[i] if i < len(pm25_list) else None,
                co_list[i] if i < len(co_list) else None,
                no2_list[i] if i < len(no2_list) else None,
                so2_list[i] if i < len(so2_list) else None,
                o3_list[i] if i < len(o3_list) else None,
            )
            if None in vals:
                continue
            records.append((t, *vals))

        _sync_auxiliary_tables(get_local, get_supabase)

        status = {}
        for label, get_conn in [("local", get_local), ("supabase", get_supabase)]:
            try:
                conn = get_conn()
                cur = conn.cursor()
                cur.execute("SELECT setval(pg_get_serial_sequence('air_quality', 'id'), COALESCE((SELECT MAX(id) FROM air_quality), 1))")
                psycopg2.extras.execute_batch(cur, UPSERT_SQL, records, page_size=200)
                conn.commit()
                cur.execute("SELECT COUNT(*), MAX(recorded_at) FROM air_quality")
                cnt, latest = cur.fetchone()
                cur.close()
                conn.close()
                status[label] = {"ok": True, "total": cnt, "latest": str(latest)}
            except Exception as db_err:
                status[label] = {"ok": False, "error": str(db_err)}

        return {
            "success": True,
            "fetched": len(records),
            "databases": status,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

_LAST_ANGLE_IDX = -1

EDITORIAL_ANGLES = [
    {
        "id": "angle_1",
        "label": "Khung giờ vàng và Lịch trình di chuyển 24h",
        "category": "Cảnh báo hôm nay",
        "author": "Hệ thống Cảnh báo Sớm AppAir",
        "focus": (
            "Phân tích chi tiết các khung giờ an toàn nhất để tập thể dục, đi học, đi làm "
            "và mở cửa thông gió tại Thủ Dầu Một trong 24 giờ tới dựa trên dự báo 1D-CNN + LSTM."
        ),
    },
    {
        "id": "angle_2",
        "label": "Phân tích tương quan 6 khí thải (PM2.5, PM10, CO, NO2, SO2, O3)",
        "category": "Phân tích khoa học",
        "author": "Trung tâm Phân tích Dữ liệu Môi trường",
        "focus": (
            "Đi sâu phân tích mối tương quan giữa tỷ lệ bụi mịn PM2.5/PM10 và các khí thải giao thông "
            "công nghiệp (NO2, CO, SO2, O3) tại các trục đường lớn và khu dân cư Thủ Dầu Một."
        ),
    },
    {
        "id": "angle_3",
        "label": "Bảo vệ sức khỏe hô hấp cho trẻ nhỏ và người có bệnh nền",
        "category": "Sức khỏe hô hấp",
        "author": "Chuyên gia Tư vấn Sức khỏe Cộng đồng",
        "focus": (
            "Hướng dẫn thực hành phòng ngừa cụ thể cho trẻ em, người cao tuổi và người mắc bệnh hen suyễn, "
            "viêm mũi dị ứng trước mức biến động bụi mịn trong ngày."
        ),
    },
    {
        "id": "angle_4",
        "label": "Giải mã biến động không khí giữa Ban ngày và Ban đêm",
        "category": "Phân tích khoa học",
        "author": "Ban Biên tập Khí tượng AppAir",
        "focus": (
            "So sánh sự chênh lệch nồng độ bụi mịn giữa ban ngày và ban đêm trong 24 giờ qua, "
            "giải thích cơ chế đối lưu nhiệt ban ngày và nghịch nhiệt bức xạ ban đêm."
        ),
    },
    {
        "id": "angle_5",
        "label": "Đối chiếu số liệu thực tế với quy chuẩn QCVN 05:2023/BTNMT",
        "category": "Tiêu chuẩn QCVN",
        "author": "Ban Biên tập Tiêu chuẩn Môi trường",
        "focus": (
            "Đánh giá mức độ đạt chuẩn QCVN 05:2023/BTNMT và khuyến nghị WHO của các chỉ số không khí "
            "tại Thủ Dầu Một trong 24 giờ qua và dự báo 24 giờ tới."
        ),
    },
]

STOPWORDS_VI = {
    "và", "của", "là", "có", "trong", "tại", "với", "cho", "các", "những",
    "được", "đến", "từ", "theo", "về", "khi", "như", "này", "đó", "để",
    "một", "hai", "giờ", "ngày", "hôm", "nay", "tới", "qua", "mức",
}

def _tokenize_vi(text: str) -> set:
    words = re.findall(r"[a-zA-Z0-9àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]+", text.lower())
    return {w for w in words if len(w) > 2 and w not in STOPWORDS_VI}

def _calc_max_similarity(title: str, summary: str, existing_rows: list) -> float:
    cand_tokens = _tokenize_vi(f"{title} {summary}")
    if not cand_tokens or not existing_rows:
        return 0.0
    max_sim = 0.0
    for row in existing_rows:
        old_tokens = _tokenize_vi(f"{row.get('title', '')} {row.get('summary', '')}")
        if not old_tokens:
            continue
        inter = len(cand_tokens & old_tokens)
        union = len(cand_tokens | old_tokens)
        if union > 0:
            sim = inter / union
            if sim > max_sim:
                max_sim = sim
    return round(max_sim, 3)

def _call_gemini_news(prompt: str):
    keys = []
    for k_name in ["GEMINI_API_KEY_1", "GEMINI_API_KEY_2", "GEMINI_API_KEY_3", "GEMINI_API_KEY_4"]:
        val = os.getenv(k_name, "").strip()
        if val and val not in keys:
            keys.append(val)
    for k in keys:
        try:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={k}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}],
                "generationConfig": {
                    "temperature": 0.85,
                    "responseMimeType": "application/json",
                },
            }
            r = requests.post(url, json=payload, timeout=7)
            if r.status_code == 200:
                data = r.json()
                text = data["candidates"][0]["content"]["parts"][0]["text"]
                return json.loads(text)
            if r.status_code not in (429, 503):
                break
        except Exception:
            continue
    return None

def _build_angle_fallback(angle_obj: dict, stats: dict) -> dict:
    aid = angle_obj["id"]
    now_str = stats["now_str"]
    cur_pm25 = stats["cur_pm25"]
    cur_pm10 = stats["cur_pm10"]
    cur_no2 = stats["cur_no2"]
    cur_co = stats["cur_co"]
    cur_so2 = stats["cur_so2"]
    cur_o3 = stats["cur_o3"]
    avg_24h = stats["avg_24h"]
    min_fc = stats["min_fc"]
    max_fc = stats["max_fc"]
    best_time = stats["best_time"]
    peak_time = stats["peak_time"]
    lvl = stats["lvl"]

    if aid == "angle_1":
        title = f"Lịch trình di chuyển và khung giờ không khí sạch tại Thủ Dầu Một ({now_str})"
        summary = (
            f"Dự báo 24 giờ tới cho thấy khung giờ lý tưởng nhất để hoạt động ngoài trời là quanh {best_time} "
            f"({min_fc:.1f} ug/m3), trong khi nồng độ bụi mịn đạt đỉnh {max_fc:.1f} ug/m3 vào lúc {peak_time}."
        )
        content = (
            f"1. Khung giờ vàng cho hoạt động ngoài trời và thể thao:\n"
            f"- Theo kết quả dự báo từ mô hình 1D-CNN + LSTM, thời điểm không khí thông thoáng nhất trong 24 giờ tới rơi vào khoảng {best_time} với nồng độ PM2.5 giảm về mức {min_fc:.1f} ug/m3.\n"
            f"- Đây là thời gian phù hợp nhất để người dân mở cửa thông gió tự nhiên, đi bộ hoặc tập thể dục ngoài trời.\n\n"
            f"2. Khung giờ cần hạn chế tiếp xúc trực tiếp:\n"
            f"- Đỉnh bụi mịn dự kiến xuất hiện quanh mốc {peak_time} với nồng độ lên tới {max_fc:.1f} ug/m3 (so với mức hiện tại {cur_pm25:.1f} ug/m3).\n"
            f"- Người dân di chuyển trên các tuyến giao thông chính vào khung giờ này nên trang bị khẩu trang lọc bụi mịn đạt chuẩn."
        )
    elif aid == "angle_2":
        ratio = (cur_pm25 / cur_pm10 * 100) if cur_pm10 > 0 else 75.0
        title = f"Phân tích tương quan 6 chỉ số khí thải tại Thủ Dầu Một: PM2.5 chiếm {ratio:.0f}% tổng bụi lơ lửng"
        summary = (
            f"Quan trắc mới nhất ghi nhận PM2.5 ở mức {cur_pm25:.1f} ug/m3, PM10 đạt {cur_pm10:.1f} ug/m3 "
            f"cùng các chỉ số NO2 ({cur_no2:.1f} ug/m3), O3 ({cur_o3:.1f} ug/m3) và CO ({cur_co:.0f} ug/m3)."
        )
        content = (
            f"1. Tỷ trọng bụi mịn PM2.5 trên tổng bụi PM10:\n"
            f"- Số liệu thực tế từ hệ thống ghi nhận PM2.5 đạt {cur_pm25:.1f} ug/m3 và PM10 đạt {cur_pm10:.1f} ug/m3 (tỷ lệ PM2.5/PM10 đạt {ratio:.0f}%).\n"
            f"- Tỷ lệ này phản ánh nguồn phát thải chủ yếu đến từ quá trình đốt nhiên liệu phương tiện giao thông và hoạt động sản xuất thay vì bụi cơ học thông thường.\n\n"
            f"2. Diễn biến nhóm khí thải vô cơ (NO2, SO2, CO, O3):\n"
            f"- Khí Nitrogen Dioxide (NO2): {cur_no2:.1f} ug/m3; Sulphur Dioxide (SO2): {cur_so2:.1f} ug/m3.\n"
            f"- Khí Carbon Monoxide (CO): {cur_co:.0f} ug/m3; Ozone tầng mặt đất (O3): {cur_o3:.1f} ug/m3.\n"
            f"- Các chỉ số khí phụ trợ hiện vẫn nằm trong ngưỡng kiểm soát nhưng kết hợp cùng bụi mịn tạo áp lực lên hệ hô hấp vào giờ cao điểm."
        )
    elif aid == "angle_3":
        title = f"Khuyến nghị bảo vệ hô hấp cho trẻ nhỏ và người có bệnh nền khi PM2.5 ở mức {cur_pm25:.1f} ug/m3"
        summary = (
            f"Với mức chất lượng không khí {lvl} hiện tại và dự báo biên độ {min_fc:.1f} - {max_fc:.1f} ug/m3, "
            f"nhóm người nhạy cảm cần chủ động điều chỉnh sinh hoạt theo từng khung giờ."
        )
        content = (
            f"1. Đánh giá tác động đối với nhóm nhạy cảm hôm nay:\n"
            f"- Nồng độ PM2.5 hiện tại đang ở mức {cur_pm25:.1f} ug/m3 (trung bình 24 giờ qua là {avg_24h:.1f} ug/m3).\n"
            f"- Đối với người mắc bệnh hen suyễn hoặc viêm mũi dị ứng, sự chênh lệch nồng độ bụi từ {min_fc:.1f} lên {max_fc:.1f} ug/m3 trong ngày dễ kích thích niêm mạc đường thở.\n\n"
            f"2. Hướng dẫn chăm sóc sức khỏe chủ động:\n"
            f"- Ưu tiên cho trẻ nhỏ vui chơi ngoài trời quanh khung giờ {best_time} khi bụi mịn hạ xuống mức thấp nhất ({min_fc:.1f} ug/m3).\n"
            f"- Đóng bớt cửa sổ phòng ngủ trước khung giờ {peak_time} và vệ sinh mũi họng bằng nước muối sinh lý sau khi di chuyển ngoài đường."
        )
    elif aid == "angle_4":
        title = f"So sánh biên độ bụi mịn Ngày và Đêm tại Thủ Dầu Một: Chênh lệch dự kiến {(max_fc - min_fc):.1f} ug/m3"
        summary = (
            f"Dữ liệu 24 giờ qua (trung bình {avg_24h:.1f} ug/m3) và dự báo 24 giờ tới cho thấy sự phân hóa rõ rệt "
            f"giữa thời điểm khuếch tán tốt ({best_time}) và thời điểm tích tụ bụi ({peak_time})."
        )
        content = (
            f"1. Phân tích biên độ dao động trong chu kỳ 24 giờ:\n"
            f"- Trong 24 giờ qua, nồng độ PM2.5 trung bình đạt {avg_24h:.1f} ug/m3, hiện tại ghi nhận {cur_pm25:.1f} ug/m3.\n"
            f"- Trong 24 giờ tiếp theo, biên độ giữa ngưỡng thấp nhất ({min_fc:.1f} ug/m3 lúc {best_time}) và ngưỡng cao nhất ({max_fc:.1f} ug/m3 lúc {peak_time}) lên tới {(max_fc - min_fc):.1f} ug/m3.\n\n"
            f"2. Cơ chế khí tượng tác động:\n"
            f"- Khi bức xạ mặt trời tăng, lớp biên khí quyển mở rộng giúp pha loãng bụi mịn nhanh chóng.\n"
            f"- Ngược lại, khi nhiệt độ mặt đất giảm vào ban đêm và sáng sớm, hiện tượng nghịch nhiệt giữ các hạt lơ lửng ở tầng thấp khiến chỉ số tăng cao."
        )
    else:
        title = f"Đối chiếu chất lượng không khí Thủ Dầu Một ({cur_pm25:.1f} ug/m3) theo quy chuẩn QCVN 05:2023/BTNMT"
        summary = (
            f"Đánh giá thực trạng bụi mịn PM2.5 ({cur_pm25:.1f} ug/m3) và PM10 ({cur_pm10:.1f} ug/m3) "
            f"so với các ngưỡng phân cấp an toàn sức khỏe của Bộ Tài nguyên và Môi trường."
        )
        content = (
            f"1. Đối chiếu trực tiếp với thang đo áp dụng trên AppAir:\n"
            f"- Chỉ số PM2.5 hiện tại ({cur_pm25:.1f} ug/m3) đang xếp ở mức {lvl} (ngưỡng Tốt <= 15 ug/m3; Trung bình 15.1 - 25 ug/m3; Kém 25.1 - 50 ug/m3).\n"
            f"- Trung bình 24 giờ liên tục đạt {avg_24h:.1f} ug/m3, phản ánh mặt bằng chất lượng không khí chung của khu vực đô thị Thủ Dầu Một.\n\n"
            f"2. Dự báo khả năng duy trì ngưỡng an toàn trong 24 giờ tới:\n"
            f"- Hệ thống dự báo AI ghi nhận thời điểm tốt nhất đạt {min_fc:.1f} ug/m3 lúc {best_time} và cao nhất đạt {max_fc:.1f} ug/m3 lúc {peak_time}.\n"
            f"- Người dân có thể dựa vào mốc giờ này để chủ động sắp xếp công việc ngoài trời đạt hiệu quả và an toàn cao nhất."
        )

    return {
        "title": title,
        "category": angle_obj["category"],
        "summary": summary,
        "content": content,
        "author": angle_obj["author"],
    }

@app.get("/news/draft")
def api_news_draft(angle: str = "auto"):
    global _LAST_ANGLE_IDX
    try:
        conn = get_db()
        cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        cur.execute("""
            SELECT pm2_5, pm10, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, recorded_at
            FROM air_quality
            ORDER BY recorded_at DESC
            LIMIT 24
        """)
        rows = cur.fetchall()

        existing_articles = []
        try:
            cur.execute("""
                SELECT id, title, category, summary, created_at
                FROM news_articles
                ORDER BY created_at DESC
                LIMIT 15
            """)
            existing_articles = [dict(r) for r in cur.fetchall()]
        except Exception:
            conn.rollback()

        cur.close()
        conn.close()

        if not rows:
            raise HTTPException(status_code=404, detail="Chưa có dữ liệu không khí.")

        latest = rows[0]
        cur_pm25 = float(latest["pm2_5"] or 0)
        cur_pm10 = float(latest["pm10"] or 0)
        cur_co = float(latest["carbon_monoxide"] or 0)
        cur_no2 = float(latest["nitrogen_dioxide"] or 0)
        cur_so2 = float(latest["sulphur_dioxide"] or 0)
        cur_o3 = float(latest["ozone"] or 0)
        avg_24h = sum(float(r["pm2_5"] or 0) for r in rows) / len(rows)

        data = fetch_recent_data()
        fc_vals = []
        if data is not None:
            pred = predict(data)
            fc_vals = pred.get("forecast_pm2_5", [])

        min_fc = min(fc_vals) if fc_vals else cur_pm25
        max_fc = max(fc_vals) if fc_vals else cur_pm25
        best_idx = fc_vals.index(min_fc) + 1 if fc_vals else 1
        peak_idx = fc_vals.index(max_fc) + 1 if fc_vals else 6

        now_dt = datetime.now()
        best_dt = now_dt + timedelta(hours=best_idx)
        peak_dt = now_dt + timedelta(hours=peak_idx)
        best_time = best_dt.strftime("%H:00")
        peak_time = peak_dt.strftime("%H:00")

        if cur_pm25 <= 15:
            lvl = "Tốt"
        elif cur_pm25 <= 25:
            lvl = "Trung bình"
        elif cur_pm25 <= 50:
            lvl = "Kém"
        else:
            lvl = "Xấu"

        chosen_angle = None
        if angle != "auto":
            for idx, a in enumerate(EDITORIAL_ANGLES):
                if a["id"] == angle:
                    chosen_angle = a
                    _LAST_ANGLE_IDX = idx
                    break
        if chosen_angle is None:
            _LAST_ANGLE_IDX = (_LAST_ANGLE_IDX + 1) % len(EDITORIAL_ANGLES)
            chosen_angle = EDITORIAL_ANGLES[_LAST_ANGLE_IDX]

        stats = {
            "now_str": now_dt.strftime("%H:%M %d/%m/%Y"),
            "cur_pm25": cur_pm25,
            "cur_pm10": cur_pm10,
            "cur_co": cur_co,
            "cur_no2": cur_no2,
            "cur_so2": cur_so2,
            "cur_o3": cur_o3,
            "avg_24h": avg_24h,
            "min_fc": min_fc,
            "max_fc": max_fc,
            "best_time": best_time,
            "peak_time": peak_time,
            "lvl": lvl,
        }

        old_titles_block = "\n".join(
            f"- [{a.get('category', '')}] {a.get('title', '')}"
            for a in existing_articles[:10]
        ) or "- Chưa có bài cũ"

        prompt = f"""Bạn là biên tập viên bản tin môi trường và sức khỏe của ứng dụng AppAir tại TP. Thủ Dầu Một.
Hãy viết 1 bản tin MỚI HOÀN TOÀN bằng tiếng Việt có dấu đầy đủ dựa trên số liệu thực tế dưới đây.

GÓC KHAI THÁC BẮT BUỘC CHO BÀI NÀY:
- Tên góc viết: {chosen_angle['label']}
- Chuyên mục: {chosen_angle['category']}
- Trọng tâm phân tích: {chosen_angle['focus']}

SỐ LIỆU THỰC TẾ TỪ DATABASE (Thời điểm: {stats['now_str']}):
- PM2.5 hiện tại: {cur_pm25:.1f} ug/m3 (Mức {lvl}), trung bình 24h qua: {avg_24h:.1f} ug/m3
- PM10: {cur_pm10:.1f} ug/m3 | CO: {cur_co:.0f} ug/m3 | NO2: {cur_no2:.1f} ug/m3 | SO2: {cur_so2:.1f} ug/m3 | O3: {cur_o3:.1f} ug/m3
- Dự báo 24h tới (1D-CNN + LSTM): Sạch nhất lúc {best_time} ({min_fc:.1f} ug/m3), cao nhất lúc {peak_time} ({max_fc:.1f} ug/m3).

DANH SÁCH CÁC BÀI ĐÃ ĐĂNG (TUYỆT ĐỐI KHÔNG TRÙNG TIÊU ĐỀ, KHÔNG LẶP LẠI CẤU TRÚC MỞ BÀI CỦA CÁC BÀI NÀY):
{old_titles_block}

YÊU CẦU ĐẦU RA (Trả về duy nhất 1 JSON object hợp lệ, không dùng markdown, không dùng icon/emoji):
{{
  "title": "Tiêu đề báo chí sắc sảo, mới mẻ, phản ánh đúng góc khai thác và có con số thực tế",
  "summary": "Đoạn tóm tắt 2 câu ngắn gọn, khác biệt hoàn toàn với các bài cũ",
  "content": "Nội dung chi tiết chia làm 3 mục rõ ràng (1., 2., 3.), phân tích sâu sắc số liệu thực tế và đưa ra lời khuyên thiết thực"
}}"""

        ai_res = _call_gemini_news(prompt)
        if ai_res and isinstance(ai_res, dict) and ai_res.get("title") and ai_res.get("content"):
            draft = {
                "title": str(ai_res["title"]).strip(),
                "category": chosen_angle["category"],
                "summary": str(ai_res.get("summary", "")).strip(),
                "content": str(ai_res["content"]).strip(),
                "author": chosen_angle["author"],
                "source_mode": "Gemini AI + DB",
            }
        else:
            draft = _build_angle_fallback(chosen_angle, stats)
            draft["source_mode"] = "Smart Angle Engine + DB"

        max_sim = _calc_max_similarity(draft["title"], draft["summary"], existing_articles)
        uniqueness = max(0, min(100, int(round((1.0 - max_sim) * 100))))

        draft["angle_id"] = chosen_angle["id"]
        draft["angle_label"] = chosen_angle["label"]
        draft["uniqueness_score"] = uniqueness
        draft["compared_articles"] = len(existing_articles)
        return draft
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
