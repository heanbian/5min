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

function randomBytes(len) {
  const out = new Uint8Array(len);
  // Prefer CSPRNG when the runtime exposes it (基础库 ≥ 2.23).
  if (typeof wx !== 'undefined' && typeof wx.getRandomValues === 'function') {
    try {
      wx.getRandomValues(out);
      return out;
    } catch (_) {
      /* fall through */
    }
  }
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    crypto.getRandomValues(out);
    return out;
  }
  // Last resort — still better than a pure Math.random loop for UUID shape.
  for (let i = 0; i < len; i += 1) {
    out[i] = (Math.random() * 256) | 0;
  }
  return out;
}

function makeUuid() {
  const bytes = randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return (
    hex.slice(0, 8) +
    '-' +
    hex.slice(8, 12) +
    '-' +
    hex.slice(12, 16) +
    '-' +
    hex.slice(16, 20) +
    '-' +
    hex.slice(20)
  );
}

function makeSecret() {
  const bytes = randomBytes(32);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

function ensureDeviceCredentials() {
  let deviceId = prefs.getDeviceId();
  let deviceSecret = prefs.getDeviceSecret();
  if (!deviceId || !deviceSecret) {
    deviceId = makeUuid();
    deviceSecret = makeSecret();
    prefs.setDeviceCredentials(deviceId, deviceSecret);
  }
  return { deviceId, deviceSecret };
}

function request(method, path, body) {
  const { deviceId, deviceSecret } = ensureDeviceCredentials();
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
  const { deviceId, deviceSecret } = ensureDeviceCredentials();
  await request('POST', '/register', { deviceId, deviceSecret });
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

module.exports = {
  API_BASE,
  syncNow,
  pushSnapshot,
  pullAndMerge,
  pushPrefsOnly,
  pushSessionsOnly,
  deleteRemoteSession,
  clearRemoteSessions,
  enableCloud,
  disableCloud,
};
