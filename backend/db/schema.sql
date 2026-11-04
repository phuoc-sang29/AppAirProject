CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(100) NOT NULL,
    health_group VARCHAR(50) NOT NULL DEFAULT 'binh_thuong',
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS air_quality (
    id SERIAL PRIMARY KEY,
    recorded_at TIMESTAMPTZ NOT NULL UNIQUE,
    pm10 FLOAT,
    pm2_5 FLOAT,
    carbon_monoxide FLOAT,
    nitrogen_dioxide FLOAT,
    sulphur_dioxide FLOAT,
    ozone FLOAT
);

CREATE TABLE IF NOT EXISTS notifications (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    level VARCHAR(20) NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
