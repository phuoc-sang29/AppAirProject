@echo off
start "AppAir Backend" cmd /k "cd /d D:\AppAir\backend && npm start"
timeout /t 3 >nul
start "AppAir AI Service" cmd /k "cd /d D:\AppAir\ai_service && set TF_ENABLE_ONEDNN_OPTS=0 && python -m uvicorn main:app --host 0.0.0.0 --port 8000"
timeout /t 3 >nul
start "AppAir Data" cmd /k "cd /d D:\AppAir\data_pipeline && python cron.py"
echo Tat ca dich vu da khoi dong.
