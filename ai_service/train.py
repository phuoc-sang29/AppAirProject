import pandas as pd
import numpy as np
import psycopg2
import os
from dotenv import load_dotenv
from sklearn.preprocessing import MinMaxScaler
from sklearn.metrics import mean_squared_error, mean_absolute_error
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Conv1D, MaxPooling1D, LSTM, Dense, Dropout
from tensorflow.keras.callbacks import EarlyStopping
import joblib
import math

load_dotenv(os.path.join(os.path.dirname(__file__), ".env"))

FEATURES = ["pm10", "pm2_5", "carbon_monoxide", "nitrogen_dioxide", "sulphur_dioxide", "ozone"]
TARGET = "pm2_5"
LOOK_BACK = 24
FORECAST_STEPS = 24
MODEL_PATH = os.path.join(os.path.dirname(__file__), "model.keras")
SCALER_PATH = os.path.join(os.path.dirname(__file__), "scaler.pkl")

def load_data():
    conn = psycopg2.connect(os.getenv("DATABASE_URL"))
    cur = conn.cursor()
    cur.execute(
        f"SELECT {', '.join(FEATURES)} FROM air_quality ORDER BY recorded_at ASC"
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()
    df = pd.DataFrame(rows, columns=FEATURES)
    df = df.ffill().bfill()
    print(f"Tai {len(df)} ban ghi tu Supabase.")
    return df

def build_sequences(data_scaled, look_back, forecast_steps):
    X, y = [], []
    target_idx = FEATURES.index(TARGET)
    for i in range(look_back, len(data_scaled) - forecast_steps + 1):
        X.append(data_scaled[i - look_back:i])
        y.append(data_scaled[i:i + forecast_steps, target_idx])
    return np.array(X), np.array(y)

def build_model(input_shape, output_steps):
    model = Sequential([
        Conv1D(filters=64, kernel_size=3, activation="relu", input_shape=input_shape),
        MaxPooling1D(pool_size=2),
        Conv1D(filters=32, kernel_size=3, activation="relu"),
        LSTM(64, return_sequences=True),
        Dropout(0.2),
        LSTM(32),
        Dropout(0.2),
        Dense(output_steps)
    ])
    model.compile(optimizer="adam", loss="mse")
    return model

def train():
    df = load_data()
    values = df[FEATURES].values

    scaler = MinMaxScaler()
    scaled = scaler.fit_transform(values)
    joblib.dump(scaler, SCALER_PATH)

    split = int(len(scaled) * 0.8)
    train_data = scaled[:split]
    test_data = scaled[split - LOOK_BACK:]

    X_train, y_train = build_sequences(train_data, LOOK_BACK, FORECAST_STEPS)
    X_test, y_test = build_sequences(test_data, LOOK_BACK, FORECAST_STEPS)

    model = build_model((LOOK_BACK, len(FEATURES)), FORECAST_STEPS)

    early_stop = EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True)
    model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=32,
        validation_split=0.1,
        callbacks=[early_stop],
        verbose=1
    )

    model.save(MODEL_PATH)

    y_pred = model.predict(X_test)

    target_idx = FEATURES.index(TARGET)
    dummy = np.zeros((len(y_test.flatten()), len(FEATURES)))
    dummy[:, target_idx] = y_test.flatten()
    y_test_inv = scaler.inverse_transform(dummy)[:, target_idx]

    dummy2 = np.zeros((len(y_pred.flatten()), len(FEATURES)))
    dummy2[:, target_idx] = y_pred.flatten()
    y_pred_inv = scaler.inverse_transform(dummy2)[:, target_idx]

    rmse = math.sqrt(mean_squared_error(y_test_inv, y_pred_inv))
    mae = mean_absolute_error(y_test_inv, y_pred_inv)

    print(f"RMSE: {rmse:.4f}")
    print(f"MAE:  {mae:.4f}")

    with open(os.path.join(os.path.dirname(__file__), "metrics.txt"), "w") as f:
        f.write(f"RMSE={rmse:.4f}\n")
        f.write(f"MAE={mae:.4f}\n")

    return rmse, mae

if __name__ == "__main__":
    train()
