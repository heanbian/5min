/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Device-bound cloud sync for prefs + 14-day history.
 */

const prefs = require('./prefs');
const history = require('./history');
const p0 = require('./p0Features');

const API_BASE = 'https://5min.chat/api/v1/storage';

/** UUID that appears when version/variant bits are stamped onto an all-zero buffer. */
const WEAK_UUID_RE = /^0{8}-0{4}-4000-8000-0{12}$/i;

function isAllZero(bytes) {
  if (!bytes || !bytes.length) return true;
  for (let i = 0; i < bytes.length; i += 1) {
    if (bytes[i] !== 0) return false;
  }
  return true;
}

/**
 * Sync entropy. Do NOT call wx.getRandomValues(typedArray) — WeChat's API is
 * async Object form `{ length }` and the TypedArray call leaves buffers as zeros
 * (producing 00000000-0000-4000-8000-000000000000 data codes).
 */
function randomBytesSync(len) {
  const out = new Uint8Array(len);
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    try {
      crypto.getRandomValues(out);
      if (!isAllZero(out)) return out;
    } catch (_) {
      /* fall through */
    }
  }
  let seed =
    (Date.now() >>> 0) ^
    ((Math.random() * 0xffffffff) >>> 0);
  try {
    if (typeof performance !== 'undefined' && typeof performance.now === 'function') {
      seed ^= (performance.now() * 1000) >>> 0;
    }
  } catch (_) {
    /* ignore */
  }
  for (let i = 0; i < len; i += 1) {
    seed = (Math.imul(seed ^ (i * 2654435761), 1597334677) >>> 0);
    out[i] = ((seed >>> 16) ^ ((Math.random() * 256) | 0)) & 0xff;
  }
  if (isAllZero(out)) {
    for (let i = 0; i < len; i += 1) out[i] = ((Math.random() * 255) | 0) + 1;
  }
  return out;
}

/** Prefer WeChat CSPRNG when available (基础库 ≥ 2.17.3). */
function randomBytesAsync(len) {
  return new Promise((resolve) => {
    const done = (buf) => {
      try {
        const view = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
        if (view.length >= len && !isAllZero(view.subarray(0, len))) {
          resolve(view.length === len ? view : view.subarray(0, len));
          return;
        }
      } catch (_) {
        /* fall through */
      }
      resolve(randomBytesSync(len));
    };

    if (typeof wx !== 'undefined' && typeof wx.getRandomValues === 'function') {
      try {
        wx.getRandomValues({
          length: len,
          success(res) {
            done(res && res.randomValues);
          },
          fail() {
            done(null);
          },
        });
        return;
      } catch (_) {
        /* fall through */
      }
    }
    done(null);
  });
}

function bytesToUuid(bytes) {
  const b = bytes instanceof Uint8Array ? Uint8Array.from(bytes) : new Uint8Array(bytes);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  const hex = Array.from(b, (x) => x.toString(16).padStart(2, '0')).join('');
  return (
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`
  );
}

function bytesToHex(bytes) {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function isWeakDeviceCredentials(deviceId, deviceSecret) {
  if (!deviceId || !deviceSecret) return true;
  if (/^0+$/i.test(deviceSecret)) return true;
  if (WEAK_UUID_RE.test(deviceId)) return true;
  return false;
}

async function ensureDeviceCredentials() {
  let deviceId = prefs.getDeviceId();
  let deviceSecret = prefs.getDeviceSecret();
  if (isWeakDeviceCredentials(deviceId, deviceSecret)) {
    deviceId = bytesToUuid(await randomBytesAsync(16));
    deviceSecret = bytesToHex(await randomBytesAsync(32));
    if (isWeakDeviceCredentials(deviceId, deviceSecret)) {
      deviceId = bytesToUuid(randomBytesSync(16));
      deviceSecret = bytesToHex(randomBytesSync(32));
    }
    prefs.setDeviceCredentials(deviceId, deviceSecret);
  }
  return { deviceId, deviceSecret };
}

async function request(method, path, body) {
  const { deviceId, deviceSecret } = await ensureDeviceCredentials();
  const opts = {
    url: API_BASE + path,
    method,
    timeout: 15000,
    header: {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId,
      'X-Device-Secret': deviceSecret,
    },
    success(res) {
      const data = res.data || {};
      if (res.statusCode >= 200 && res.statusCode < 300 && data.success) {
        opts.__resolve(data.data);
        return;
      }
      const err = new Error((data && data.message) || `HTTP ${res.statusCode}`);
      err.status = res.statusCode;
      opts.__reject(err);
    },
    fail(err) {
      opts.__reject(err || new Error('network'));
    },
  };
  if (body != null && method !== 'GET' && method !== 'DELETE') {
    opts.data = body;
  }
  return new Promise((resolve, reject) => {
    opts.__resolve = resolve;
    opts.__reject = reject;
    wx.request(opts);
  });
}

function prefsPayload() {
  return {
    locale: prefs.getLocale() || '',
    ambient: prefs.getAmbient() || 'off',
    storageMode: prefs.getStorageMode(),
    finishTone: prefs.getFinishTone(),
    finishVibrate: prefs.getFinishVibrate(),
    finishNotify: prefs.getFinishNotify(),
    standRitual: p0.getStandRitual(),
    alertProfile: p0.getAlertProfile(),
    overtimeInsight: p0.getShowOvertimeInsight(),
    customMin: prefs.getCustomMin(5),
    customScenes: prefs.getCustomScenes(),
  };
}

function sessionsPayload() {
  return history.getHistory().map((row) => ({
    clientId: row.id,
    at: row.at,
    minutes: row.minutes,
    sceneId: row.sceneId || '',
    elapsedMs: row.elapsedMs || 0,
  }));
}

function applyRemotePrefs(remote) {
  if (!remote || typeof remote !== 'object') return;
  if (remote.locale) prefs.setLocale(String(remote.locale));
  if (remote.ambient) prefs.setAmbient(String(remote.ambient));
  if (typeof remote.finishTone === 'boolean') prefs.setFinishTone(remote.finishTone);
  if (typeof remote.finishVibrate === 'boolean') prefs.setFinishVibrate(remote.finishVibrate);
  if (typeof remote.finishNotify === 'boolean') prefs.setFinishNotify(remote.finishNotify);
  if (remote.standRitual === 'off' || remote.standRitual === 'basic') {
    p0.setStandRitual(remote.standRitual);
  }
  if (
    remote.alertProfile === 'normal' ||
    remote.alertProfile === 'quiet' ||
    remote.alertProfile === 'silent'
  ) {
    p0.setAlertProfile(remote.alertProfile);
  }
  if (typeof remote.overtimeInsight === 'boolean') {
    p0.setShowOvertimeInsight(remote.overtimeInsight);
  }
  if (remote.customMin != null) prefs.setCustomMin(remote.customMin);
  if (Array.isArray(remote.customScenes)) prefs.setCustomScenes(remote.customScenes);
  // Keep local storageMode as source of truth for this device setting.
}

/** Cap remote session merge to avoid storage blow-up. */
const MAX_REMOTE_SESSIONS = 500;
const MAX_CLIENT_ID_LEN = 64;
const MAX_SCENE_ID_LEN = 64;

function mergeRemoteSessions(remoteSessions) {
  if (!Array.isArray(remoteSessions) || remoteSessions.length === 0) return;
  const local = history.getHistory();
  const byId = new Map(local.map((r) => [r.id, r]));
  const limit = Math.min(remoteSessions.length, MAX_REMOTE_SESSIONS);
  for (let i = 0; i < limit; i += 1) {
    const s = remoteSessions[i];
    if (!s) continue;
    let id = String(s.clientId || s.id || '');
    if (!id) continue;
    if (id.length > MAX_CLIENT_ID_LEN) id = id.slice(0, MAX_CLIENT_ID_LEN);
    const at = Math.floor(Number(s.at) || 0);
    const minutes = Math.floor(Number(s.minutes) || 0);
    if (at <= 0 || minutes <= 0) continue;
    let sceneId = String(s.sceneId || '');
    if (sceneId.length > MAX_SCENE_ID_LEN) sceneId = sceneId.slice(0, MAX_SCENE_ID_LEN);
    const next = {
      id,
      at,
      minutes,
      sceneId,
      elapsedMs: Math.max(0, Math.floor(Number(s.elapsedMs) || 0)),
    };
    const prev = byId.get(id);
    if (!prev || next.at >= prev.at) byId.set(id, next);
  }
  const merged = Array.from(byId.values()).sort((a, b) => b.at - a.at);
  history.replaceAll(merged);
}

async function register() {
  // Credentials only in X-Device-* headers — body must not include them (server 400).
  await ensureDeviceCredentials();
  await request('POST', '/register', {});
}

async function pushSnapshot() {
  await register();
  return request('PUT', '/snapshot', {
    prefs: prefsPayload(),
    sessions: sessionsPayload(),
  });
}

async function pullAndMerge() {
  await register();
  const snap = await request('GET', '/snapshot');
  if (snap && snap.prefs) applyRemotePrefs(snap.prefs);
  if (snap && Array.isArray(snap.sessions)) mergeRemoteSessions(snap.sessions);
  return snap;
}

async function syncNow() {
  if (prefs.getStorageMode() !== 'cloud') return { skipped: true };
  await pushSnapshot();
  await pullAndMerge();
  return { ok: true };
}

async function pushPrefsOnly() {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('PUT', '/prefs', { prefs: prefsPayload() });
}

async function pushSessionsOnly() {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('PUT', '/sessions', { sessions: sessionsPayload() });
}

async function deleteRemoteSession(clientId) {
  if (prefs.getStorageMode() !== 'cloud' || !clientId) return;
  await register();
  await request('DELETE', `/sessions/${encodeURIComponent(clientId)}`);
}

async function clearRemoteSessions() {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('POST', '/sessions/clear', {});
}

async function enableCloud() {
  prefs.setStorageMode('cloud');
  try {
    await syncNow();
  } catch (e) {
    prefs.setStorageMode('local');
    prefs.clearDeviceCredentials();
    throw e;
  }
}

function disableCloud() {
  prefs.setStorageMode('local');
  prefs.clearDeviceCredentials();
}

/** Restore from user-held recovery code, then sync. */
async function restoreWithCode(code) {
  const parsed = prefs.parseRecoveryCode(code);
  if (!parsed) {
    const err = new Error('invalid');
    err.code = 'invalid';
    throw err;
  }
  prefs.setDeviceCredentials(parsed.deviceId, parsed.deviceSecret);
  prefs.setStorageMode('cloud');
  try {
    await syncNow();
  } catch (e) {
    prefs.setStorageMode('local');
    prefs.clearDeviceCredentials();
    throw e;
  }
}

module.exports = {
  API_BASE,
  ensureDeviceCredentials,
  isWeakDeviceCredentials,
  syncNow,
  pushSnapshot,
  pullAndMerge,
  pushPrefsOnly,
  pushSessionsOnly,
  deleteRemoteSession,
  clearRemoteSessions,
  enableCloud,
  disableCloud,
  restoreWithCode,
};
