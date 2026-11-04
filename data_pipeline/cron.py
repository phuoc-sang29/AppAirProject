# pyrefly: ignore [missing-import]
import schedule
import time
from collect import collect
from db import create_table

create_table()
collect()

schedule.every(1).hours.do(collect)

while True:
    schedule.run_pending()
    time.sleep(60)
