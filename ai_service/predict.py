import numpy as np
import joblib
import math
import os
from tensorflow.keras.models import load_model
from sklearn.metrics import mean_squared_error, mean_absolute_error

FEATURES = ["pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"]
TARGET = "pm2_5"
LOOK_BACK = 24
FORECAST_STEPS = 24
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "model.keras")
SCALER_PATH = os.path.join(BASE_DIR, "scaler.pkl")
METRICS_PATH = os.path.join(BASE_DIR, "metrics.txt")

model = None
scaler = None

def load_artifacts():
    global model, scaler
    if model is None:
        model = load_model(MODEL_PATH)
    if scaler is None:
        scaler = joblib.load(SCALER_PATH)

def get_metrics():
    rmse, mae = 0.0, 0.0
    if os.path.exists(METRICS_PATH):
        with open(METRICS_PATH, "r") as f:
            for line in f:
                if line.startswith("RMSE="):
                    rmse = float(line.split("=")[1])
                elif line.startswith("MAE="):
                    mae = float(line.split("=")[1])
    return rmse, mae

def predict(recent_data: list) -> dict:
    load_artifacts()

    input_array = np.array(recent_data)
    if input_array.shape != (LOOK_BACK, len(FEATURES)):
        raise ValueError(f"Dữ liệu đầu vào phải có shape ({LOOK_BACK}, {len(FEATURES)})")

    scaled = scaler.transform(input_array)
    X = scaled.reshape(1, LOOK_BACK, len(FEATURES))

    pred_scaled = model.predict(X, verbose=0)[0]

    target_idx = FEATURES.index(TARGET)
    dummy = np.zeros((FORECAST_STEPS, len(FEATURES)))
    dummy[:, target_idx] = pred_scaled
    pred_inv = scaler.inverse_transform(dummy)[:, target_idx]

    rmse, mae = get_metrics()

    return {
        "forecast_pm2_5": pred_inv.tolist(),
        "hours_ahead": FORECAST_STEPS,
        "rmse": rmse,
        "mae": mae
    }
