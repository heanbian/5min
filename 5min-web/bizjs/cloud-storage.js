'use strict';

/**
 * 端侧云存储：按设备凭证绑定偏好与近 14 日会话。
 * 鉴权：X-Device-Id + X-Device-Secret（服务端仅存 secret 哈希）。
 */

const crypto = require('crypto');

const HISTORY_DAYS = 14;
const MAX_SESSIONS = 500;
const MAX_CUSTOM_SCENES = 30;
const DEVICE_ID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SECRET_RE = /^[0-9a-f]{32,128}$/i;

function pool() {
  return require('./db');
}

function pepper() {
  return String(process.env.STORAGE_PEPPER || '5min-dev-pepper-change-me');
}

function hashSecret(secret) {
  return crypto.createHash('sha256').update(String(secret) + '|' + pepper(), 'utf8').digest('hex');
}

function clampStr(value, max) {
  return String(value == null ? '' : value).trim().slice(0, max);
}

function cutoffMs() {
  return Date.now() - HISTORY_DAYS * 24 * 60 * 60 * 1000;
}

async function ensureCloudStorageTables() {
  const db = pool();
  await db.query(`
    CREATE TABLE IF NOT EXISTS fivemin_devices (
      device_id          TEXT PRIMARY KEY,
      device_secret_hash TEXT NOT NULL,
      created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS fivemin_cloud_prefs (
      device_id  TEXT PRIMARY KEY REFERENCES fivemin_devices(device_id) ON DELETE CASCADE,
      payload    JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
  await db.query(`
    CREATE TABLE IF NOT EXISTS fivemin_cloud_sessions (
      device_id  TEXT NOT NULL REFERENCES fivemin_devices(device_id) ON DELETE CASCADE,
      client_id  TEXT NOT NULL,
      at_ms      BIGINT NOT NULL,
      minutes    INTEGER NOT NULL,
      scene_id   TEXT NOT NULL DEFAULT '',
      elapsed_ms BIGINT NOT NULL DEFAULT 0,
      deleted    BOOLEAN NOT NULL DEFAULT FALSE,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (device_id, client_id)
    )
  `);
  await db.query(`
    CREATE INDEX IF NOT EXISTS idx_fivemin_cloud_sessions_device_at
      ON fivemin_cloud_sessions (device_id, at_ms DESC)
  `);
}

function readAuth(req) {
  const deviceId = clampStr(req.get('x-device-id') || req.body?.deviceId, 64);
  const deviceSecret = clampStr(req.get('x-device-secret') || req.body?.deviceSecret, 128);
  return { deviceId, deviceSecret };
}

function validateCredentials(deviceId, deviceSecret) {
  if (!DEVICE_ID_RE.test(deviceId)) return '无效的 deviceId';
  if (!SECRET_RE.test(deviceSecret)) return '无效的 deviceSecret';
  return null;
}

async function registerDevice(deviceId, deviceSecret) {
  const err = validateCredentials(deviceId, deviceSecret);
  if (err) return { ok: false, status: 400, message: err };
  const hash = hashSecret(deviceSecret);
  const db = pool();
  const existing = await db.query(
    'SELECT device_secret_hash FROM fivemin_devices WHERE device_id = $1',
    [deviceId]
  );
  if (existing.rowCount > 0) {
    if (existing.rows[0].device_secret_hash !== hash) {
      return { ok: false, status: 403, message: '设备凭证不匹配' };
    }
    await db.query('UPDATE fivemin_devices SET updated_at = NOW() WHERE device_id = $1', [deviceId]);
    return { ok: true, data: { deviceId, created: false } };
  }
  await db.query(
    `INSERT INTO fivemin_devices (device_id, device_secret_hash) VALUES ($1, $2)`,
    [deviceId, hash]
  );
  await db.query(
    `INSERT INTO fivemin_cloud_prefs (device_id, payload) VALUES ($1, '{}'::jsonb)
     ON CONFLICT (device_id) DO NOTHING`,
    [deviceId]
  );
  return { ok: true, data: { deviceId, created: true } };
}

async function authenticate(req) {
  const { deviceId, deviceSecret } = readAuth(req);
  const err = validateCredentials(deviceId, deviceSecret);
  if (err) return { ok: false, status: 401, message: err };
  const db = pool();
  const res = await db.query(
    'SELECT device_secret_hash FROM fivemin_devices WHERE device_id = $1',
    [deviceId]
  );
  if (res.rowCount === 0) return { ok: false, status: 401, message: '设备未注册' };
  if (res.rows[0].device_secret_hash !== hashSecret(deviceSecret)) {
    return { ok: false, status: 403, message: '设备凭证不匹配' };
  }
  return { ok: true, deviceId };
}

function sanitizePrefs(raw) {
  if (!raw || typeof raw !== 'object') return {};
  const ambient = clampStr(raw.ambient, 16);
  const storageMode = clampStr(raw.storageMode, 16);
  const locale = clampStr(raw.locale, 16);
  const out = {
    locale: locale || '',
    ambient: ['off', 'rain', 'waves', 'clock'].includes(ambient) ? ambient : 'off',
    storageMode: storageMode === 'cloud' ? 'cloud' : 'local',
    finishTone: raw.finishTone !== false,
    finishVibrate: raw.finishVibrate !== false,
    finishNotify: raw.finishNotify !== false,
    customMin: Math.max(1, Math.min(120, Math.floor(Number(raw.customMin) || 5))),
    customScenes: []
  };
  const scenes = Array.isArray(raw.customScenes) ? raw.customScenes : [];
  for (let i = 0; i < scenes.length && out.customScenes.length < MAX_CUSTOM_SCENES; i += 1) {
    const s = scenes[i];
    if (!s || typeof s !== 'object') continue;
    const id = clampStr(s.id, 64);
    const name = clampStr(s.name, 24);
    const min = Math.max(1, Math.min(120, Math.floor(Number(s.min) || 5)));
    if (!id || !name) continue;
    out.customScenes.push({ id, name, min });
  }
  return out;
}

function sanitizeSession(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const clientId = clampStr(raw.clientId || raw.id, 80);
  const at = Math.floor(Number(raw.at) || 0);
  const minutes = Math.floor(Number(raw.minutes) || 0);
  const elapsedMs = Math.max(0, Math.floor(Number(raw.elapsedMs) || 0));
  const sceneId = clampStr(raw.sceneId, 64);
  const deleted = raw.deleted === true;
  if (!clientId || at <= 0) return null;
  if (!deleted && minutes <= 0) return null;
  return { clientId, at, minutes: Math.max(1, minutes), elapsedMs, sceneId, deleted };
}

async function getSnapshot(deviceId) {
  const db = pool();
  const cut = cutoffMs();
  await db.query(
    `DELETE FROM fivemin_cloud_sessions
     WHERE device_id = $1 AND deleted = FALSE AND at_ms < $2`,
    [deviceId, cut]
  );
  const prefsRes = await db.query(
    'SELECT payload FROM fivemin_cloud_prefs WHERE device_id = $1',
    [deviceId]
  );
  const prefs = sanitizePrefs(prefsRes.rowCount ? prefsRes.rows[0].payload : {});
  const sessRes = await db.query(
    `SELECT client_id, at_ms, minutes, scene_id, elapsed_ms
     FROM fivemin_cloud_sessions
     WHERE device_id = $1 AND deleted = FALSE AND at_ms >= $2
     ORDER BY at_ms DESC
     LIMIT $3`,
    [deviceId, cut, MAX_SESSIONS]
  );
  const sessions = sessRes.rows.map((row) => ({
    clientId: row.client_id,
    at: Number(row.at_ms),
    minutes: Number(row.minutes),
    sceneId: row.scene_id || '',
    elapsedMs: Number(row.elapsed_ms) || 0
  }));
  return { prefs, sessions, historyDays: HISTORY_DAYS };
}

async function putPrefs(deviceId, rawPrefs) {
  const prefs = sanitizePrefs(rawPrefs);
  const db = pool();
  await db.query(
    `INSERT INTO fivemin_cloud_prefs (device_id, payload, updated_at)
     VALUES ($1, $2::jsonb, NOW())
     ON CONFLICT (device_id) DO UPDATE
       SET payload = EXCLUDED.payload, updated_at = NOW()`,
    [deviceId, JSON.stringify(prefs)]
  );
  return prefs;
}

async function upsertSessions(deviceId, list) {
  const db = pool();
  const rows = (Array.isArray(list) ? list : [])
    .map(sanitizeSession)
    .filter(Boolean)
    .slice(0, MAX_SESSIONS);
  const cut = cutoffMs();
  let written = 0;
  for (const row of rows) {
    if (!row.deleted && row.at < cut) continue;
    await db.query(
      `INSERT INTO fivemin_cloud_sessions
        (device_id, client_id, at_ms, minutes, scene_id, elapsed_ms, deleted, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,NOW())
       ON CONFLICT (device_id, client_id) DO UPDATE SET
         at_ms = EXCLUDED.at_ms,
         minutes = EXCLUDED.minutes,
         scene_id = EXCLUDED.scene_id,
         elapsed_ms = EXCLUDED.elapsed_ms,
         deleted = EXCLUDED.deleted,
         updated_at = NOW()`,
      [
        deviceId,
        row.clientId,
        row.at,
        row.minutes,
        row.sceneId,
        row.elapsedMs,
        row.deleted
      ]
    );
    written += 1;
  }
  await db.query(
    `DELETE FROM fivemin_cloud_sessions
     WHERE device_id = $1 AND deleted = FALSE AND at_ms < $2`,
    [deviceId, cut]
  );
  return { written };
}

async function deleteSession(deviceId, clientId) {
  const id = clampStr(clientId, 80);
  if (!id) return { ok: false, status: 400, message: '无效的会话 id' };
  const db = pool();
  await db.query(
    `INSERT INTO fivemin_cloud_sessions
      (device_id, client_id, at_ms, minutes, scene_id, elapsed_ms, deleted, updated_at)
     VALUES ($1,$2,$3,1,'',0,TRUE,NOW())
     ON CONFLICT (device_id, client_id) DO UPDATE SET
       deleted = TRUE, updated_at = NOW()`,
    [deviceId, id, Date.now()]
  );
  return { ok: true };
}

async function clearSessions(deviceId) {
  const db = pool();
  await db.query(
    `UPDATE fivemin_cloud_sessions SET deleted = TRUE, updated_at = NOW()
     WHERE device_id = $1 AND deleted = FALSE`,
    [deviceId]
  );
  return { ok: true };
}

module.exports = {
  HISTORY_DAYS,
  ensureCloudStorageTables,
  registerDevice,
  authenticate,
  getSnapshot,
  putPrefs,
  upsertSessions,
  deleteSession,
  clearSessions,
  sanitizePrefs,
  sanitizeSession
};
