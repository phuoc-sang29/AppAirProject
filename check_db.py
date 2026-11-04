import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dotenv import load_dotenv, find_dotenv
load_dotenv(find_dotenv())

import psycopg2

conn = psycopg2.connect(os.getenv("DATABASE_URL"))
cur = conn.cursor()

cur.execute("SELECT COUNT(*) FROM air_quality")
total = cur.fetchone()[0]

cur.execute("SELECT MIN(recorded_at), MAX(recorded_at) FROM air_quality")
row = cur.fetchone()
min_time, max_time = row[0], row[1]

cur.execute("""
    SELECT recorded_at, COUNT(*) as cnt
    FROM air_quality
    GROUP BY recorded_at
    HAVING COUNT(*) > 1
    LIMIT 5
""")
duplicates = cur.fetchall()

cur.execute("""
    SELECT recorded_at, pm2_5, pm10
    FROM air_quality
    ORDER BY recorded_at DESC
    LIMIT 5
""")
latest = cur.fetchall()

cur.close()
conn.close()

print("=== Trang thai du lieu trong Supabase ===")
print(f"Tong so ban ghi: {total}")
print(f"Tu thoi gian  : {min_time}")
print(f"Den thoi gian : {max_time}")
print(f"So ban ghi trung lap: {len(duplicates)} (kiem tra ON CONFLICT)")
print()
print("5 ban ghi moi nhat:")
for r in latest:
    print(f"  {r[0]}  |  PM2.5={r[1]}  |  PM10={r[2]}")
