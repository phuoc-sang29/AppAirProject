const https = require('https');
const { Pool } = require('pg');
require('dotenv').config({ path: './data_pipeline/.env' });

const LAT = 10.9807;
const LON = 106.6753;

const pool = new Pool({
  host: 'aws-0-ap-northeast-1.pooler.supabase.com',
  port: 5432,
  database: 'postgres',
  user: 'postgres.veauosznuyqjvoepnopc',
  password: process.env.DATABASE_PASSWORD || '0858433409Sang.',
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 10000,
});

function addDays(date, days) {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function toDateStr(date) {
  return date.toISOString().split('T')[0];
}

function ffill(arr) {
  let last = null;
  return arr.map(v => {
    if (v !== null && v !== undefined) last = v;
    return last ?? 0;
  });
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

async function getLastDate() {
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT recorded_at FROM air_quality ORDER BY recorded_at DESC LIMIT 1'
    );
    if (res.rows.length === 0) return new Date('2026-08-21');
    return new Date(res.rows[0].recorded_at);
  } finally {
    client.release();
  }
}

async function fetchOpenMeteo(start, end) {
  const url = `https://air-quality-api.open-meteo.com/v1/air-quality`
    + `?latitude=${LAT}&longitude=${LON}`
    + `&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone`
    + `&start_date=${start}&end_date=${end}`;
  console.log(`Fetching: ${start} -> ${end}`);
  return fetchJson(url);
}

async function upsertBatch(rows) {
  const client = await pool.connect();
  try {
    for (const row of rows) {
      await client.query(
        `INSERT INTO air_quality
         (recorded_at,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone)
         VALUES ($1,$2,$3,$4,$5,$6,$7)
         ON CONFLICT (recorded_at) DO UPDATE SET
         pm10=EXCLUDED.pm10, pm2_5=EXCLUDED.pm2_5,
         carbon_monoxide=EXCLUDED.carbon_monoxide,
         nitrogen_dioxide=EXCLUDED.nitrogen_dioxide,
         sulphur_dioxide=EXCLUDED.sulphur_dioxide,
         ozone=EXCLUDED.ozone`,
        [row.recorded_at, row.pm10, row.pm2_5,
         row.carbon_monoxide, row.nitrogen_dioxide,
         row.sulphur_dioxide, row.ozone]
      );
    }
    return rows.length;
  } catch (e) {
    console.error('Upsert error:', e.message);
    return 0;
  } finally {
    client.release();
  }
}

async function main() {
  const lastDate = await getLastDate();
  const startDate = addDays(lastDate, 1);
  const endDate = addDays(new Date(), -1);

  if (startDate >= endDate) {
    console.log(`Du lieu da cap nhat den: ${toDateStr(lastDate)}. Khong can cap nhat.`);
    await pool.end();
    return;
  }

  console.log(`Cap nhat tu ${toDateStr(startDate)} den ${toDateStr(endDate)}`);
  let total = 0;
  let current = startDate;

  while (current < endDate) {
    const chunkEnd = addDays(current, 29);
    const end = chunkEnd < endDate ? chunkEnd : endDate;

    try {
      const json = await fetchOpenMeteo(toDateStr(current), toDateStr(end));
      const h = json.hourly;
      const times = h.time;
      const pm10  = ffill(h.pm10);
      const pm25  = ffill(h.pm2_5);
      const co    = ffill(h.carbon_monoxide);
      const no2   = ffill(h.nitrogen_dioxide);
      const so2   = ffill(h.sulphur_dioxide);
      const o3    = ffill(h.ozone);

      const rows = times.map((t, i) => ({
        recorded_at: t + ':00',
        pm10: pm10[i] ?? 0,
        pm2_5: pm25[i] ?? 0,
        carbon_monoxide: co[i] ?? 0,
        nitrogen_dioxide: no2[i] ?? 0,
        sulphur_dioxide: so2[i] ?? 0,
        ozone: o3[i] ?? 0,
      }));

      const BATCH = 100;
      for (let i = 0; i < rows.length; i += BATCH) {
        const saved = await upsertBatch(rows.slice(i, i + BATCH));
        total += saved;
      }

      console.log(`  Luu ${rows.length} ban ghi (${toDateStr(current)} - ${toDateStr(end)})`);
    } catch (e) {
      console.error(`  Loi chunk ${toDateStr(current)}: ${e.message}`);
    }

    current = addDays(end, 1);
  }

  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT recorded_at FROM air_quality ORDER BY recorded_at DESC LIMIT 1'
    );
    console.log(`\nHoan thanh! Da them ${total} ban ghi.`);
    if (res.rows.length > 0) console.log(`Ban ghi moi nhat: ${res.rows[0].recorded_at}`);
  } finally {
    client.release();
    await pool.end();
  }
}

main().catch(console.error);
