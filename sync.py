import os
import psycopg2
import psycopg2.extras
import schedule
import time
from datetime import datetime
from dotenv import load_dotenv, find_dotenv

load_dotenv(find_dotenv())


SUPABASE_URL = os.getenv("DATABASE_URL")
LOCAL_URL = os.getenv("LOCAL_DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")

def sync_to_supabase():
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Bat dau dong bo Local -> Supabase...")
    try:
        local = psycopg2.connect(LOCAL_URL)
        cloud = psycopg2.connect(SUPABASE_URL)

        lcur = local.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        ccur = cloud.cursor()

        lcur.execute("""
            SELECT * FROM air_quality
            WHERE recorded_at > NOW() - INTERVAL '2 hours'
            ORDER BY recorded_at
        """)
        rows = lcur.fetchall()

        if rows:
            cols = list(rows[0].keys())
            col_str = ", ".join(f'"{c}"' for c in cols)
            val_str = ", ".join(["%s"] * len(cols))
            sql = (
                f'INSERT INTO air_quality ({col_str}) VALUES ({val_str}) '
                f'ON CONFLICT (recorded_at) DO UPDATE SET '
                f'pm10=EXCLUDED.pm10, pm2_5=EXCLUDED.pm2_5, '
                f'carbon_monoxide=EXCLUDED.carbon_monoxide, '
                f'nitrogen_dioxide=EXCLUDED.nitrogen_dioxide, '
                f'sulphur_dioxide=EXCLUDED.sulphur_dioxide, '
                f'ozone=EXCLUDED.ozone'
            )
            data = [tuple(r[c] for c in cols) for r in rows]
            psycopg2.extras.execute_batch(ccur, sql, data, page_size=200)
            cloud.commit()
            print(f"  -> Da dong bo {len(rows)} ban ghi len Supabase.")
        else:
            print("  -> Khong co ban ghi moi de dong bo.")

        lcur.close()
        ccur.close()
        local.close()
        cloud.close()

    except Exception as e:
        print(f"  [LOI] Dong bo that bai: {e}")

if __name__ == "__main__":
    print("Sync Local -> Supabase: chay ngay lan dau, sau do moi gio 1 lan.")
    sync_to_supabase()
    schedule.every(1).hours.do(sync_to_supabase)
    while True:
        schedule.run_pending()
        time.sleep(60)
