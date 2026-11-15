/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Device-bound cloud sync for prefs + 14-day history.
 */

const prefs = require('./prefs');
const history = require('./history');

const API_BASE = 'https://5min.chat/api/v1/storage';

function makeUuid() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

function makeSecret() {
  let out = '';
  for (let i = 0; i < 64; i += 1) {
    out += ((Math.random() * 16) | 0).toString(16);
  }
  return out;
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
  if (remote.customMin != null) prefs.setCustomMin(remote.customMin);
  if (Array.isArray(remote.customScenes)) prefs.setCustomScenes(remote.customScenes);
  // Keep local storageMode as source of truth for this device setting.
}

function mergeRemoteSessions(remoteSessions) {
  if (!Array.isArray(remoteSessions) || remoteSessions.length === 0) return;
  const local = history.getHistory();
  const byId = new Map(local.map((r) => [r.id, r]));
  for (let i = 0; i < remoteSessions.length; i += 1) {
    const s = remoteSessions[i];
    if (!s || !s.clientId) continue;
    const id = String(s.clientId);
    const at = Math.floor(Number(s.at) || 0);
    const minutes = Math.floor(Number(s.minutes) || 0);
    if (at <= 0 || minutes <= 0) continue;
    const next = {
      id,
      at,
      minutes,
      sceneId: String(s.sceneId || ''),
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
  await syncNow();
}

function disableCloud() {
  prefs.setStorageMode('local');
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
