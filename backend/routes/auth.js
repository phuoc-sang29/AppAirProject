const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

module.exports = function (pool) {
    const router = express.Router();

    router.post("/register", async (req, res) => {
        const { email, password, name, health_group } = req.body;
        if (!email || !password || !name || !health_group) {
            return res.status(400).json({ error: "Thiếu thông tin đăng ký." });
        }
        try {
            const existing = await pool.query("SELECT id FROM users WHERE email = $1", [email]);
            if (existing.rows.length > 0) {
                return res.status(409).json({ error: "Email đã được đăng ký." });
            }
            const hashed = await bcrypt.hash(password, 10);
            const result = await pool.query(
                "INSERT INTO users (email, password, name, health_group, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id",
                [email, hashed, name, health_group]
            );
            const token = jwt.sign({ id: result.rows[0].id }, process.env.JWT_SECRET, { expiresIn: "30d" });
            res.json({ token, user: { id: result.rows[0].id, email, name, health_group } });
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    router.post("/login", async (req, res) => {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: "Thiếu email hoặc mật khẩu." });
        }
        try {
            const result = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
            if (result.rows.length === 0) {
                return res.status(401).json({ error: "Email hoặc mật khẩu không đúng." });
            }
            const user = result.rows[0];
            const match = await bcrypt.compare(password, user.password);
            if (!match) {
                return res.status(401).json({ error: "Email hoặc mật khẩu không đúng." });
            }
            const token = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: "30d" });
            res.json({ token, user: { id: user.id, email: user.email, name: user.name, health_group: user.health_group } });
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    router.put("/fcm-token", async (req, res) => {
        const { user_id, fcm_token } = req.body;
        try {
            await pool.query("UPDATE users SET fcm_token = $1 WHERE id = $2", [fcm_token, user_id]);
            res.json({ success: true });
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    return router;
};
