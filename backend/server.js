require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

const express = require("express");
const cors = require("cors");
const cron = require("node-cron");
const axios = require("axios");
const { Pool } = require("pg");

const authRoutes = require("./routes/auth");
const airRoutes = require("./routes/air");
const notifyRoutes = require("./routes/notify");

const app = express();
const PORT = process.env.PORT || 3000;

const pool = new Pool({ connectionString: process.env.DATABASE_URL });

app.use(cors());
app.use(express.json());
app.use("/api/auth", authRoutes(pool));
app.use("/api/air", airRoutes(pool));
app.use("/api/notify", notifyRoutes(pool));

cron.schedule("0 * * * *", async () => {
    try {
        const forecastRes = await axios.get(`${process.env.AI_SERVICE_URL}/predict`);
        const forecast = forecastRes.data;
        const maxPm25 = Math.max(...forecast.forecast_pm2_5);

        const usersRes = await pool.query("SELECT id, health_group FROM users WHERE COALESCE(is_blocked, false) = false");
        for (const user of usersRes.rows) {
            const countRes = await pool.query(
                "SELECT COUNT(*) AS c FROM notifications WHERE user_id = $1 AND created_at > NOW() - INTERVAL '24 hours'",
                [user.id]
            );
            const sentToday = parseInt(countRes.rows[0].c || "0", 10);
            if (sentToday >= 3) {
                continue;
            }
            const notifyRes = await axios.post(`${process.env.AI_SERVICE_URL}/notify/check`, {
                pm2_5: maxPm25,
                health_group: user.health_group || "binh_thuong",
            });
            if (notifyRes.data.should_warn) {
                await pool.query(
                    "INSERT INTO notifications (user_id, message, level, created_at) VALUES ($1, $2, $3, NOW())",
                    [user.id, notifyRes.data.message, notifyRes.data.level]
                );
            }
        }
    } catch (err) {
        console.error("Lỗi cron kiểm tra cảnh báo:", err.message);
    }
});

app.listen(PORT, () => {
    console.log(`Backend đang chạy tại cổng ${PORT}`);
});
