const express = require("express");

module.exports = function (pool) {
    const router = express.Router();

    router.get("/user/:user_id", async (req, res) => {
        try {
            const result = await pool.query(
                "SELECT id, message, level, created_at FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20",
                [req.params.user_id]
            );
            res.json(result.rows);
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    router.put("/read/:id", async (req, res) => {
        try {
            await pool.query("UPDATE notifications SET is_read = true WHERE id = $1", [req.params.id]);
            res.json({ success: true });
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    return router;
};
