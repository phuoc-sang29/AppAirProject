import psycopg2

conn = psycopg2.connect("postgresql://postgres:appair123@localhost:5432/appair")
cur = conn.cursor()

cur.execute("SELECT COUNT(*), MIN(recorded_at), MAX(recorded_at) FROM air_quality")
count, min_dt, max_dt = cur.fetchone()
print(f"Tong ban ghi: {count}")
print(f"Tu: {min_dt}")
print(f"Den: {max_dt}")

cur.execute("SELECT tablename FROM pg_tables WHERE schemaname='public'")
tables = [r[0] for r in cur.fetchall()]
print(f"Bang tren local: {tables}")

cur.close()
conn.close()
