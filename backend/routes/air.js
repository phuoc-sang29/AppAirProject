const express = require("express");
const axios = require("axios");

module.exports = function (pool) {
    const router = express.Router();

    router.get("/current", async (req, res) => {
        try {
            const result = await axios.get(`${process.env.AI_SERVICE_URL}/current`);
            res.json(result.data);
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    router.get("/forecast", async (req, res) => {
        try {
            const result = await axios.get(`${process.env.AI_SERVICE_URL}/predict`);
            res.json(result.data);
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    router.get("/history", async (req, res) => {
        try {
            const rows = await pool.query(
                `SELECT pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide, ozone, recorded_at
                 FROM air_quality
                 ORDER BY recorded_at DESC
                 LIMIT 24`
            );
            res.json(rows.rows.reverse());
        } catch (err) {
            res.status(500).json({ error: err.message });
        }
    });

    return router;
};
