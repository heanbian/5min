/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Device-bound cloud sync for prefs + 14-day history.
 */

import * as prefs from './prefs.js';
import {
  getHistory,
  replaceAll as replaceHistory,
} from './history.js';
import * as p0 from './p0Features.js';
import { setAmbientMode, getAmbientMode } from './ambient.js';

const API_BASE = '/api/v1/storage';

const randomBytes = (len) => {
  const out = new Uint8Array(len);
  if (typeof crypto !== 'undefined' && typeof crypto.getRandomValues === 'function') {
    crypto.getRandomValues(out);
    return out;
  }
  for (let i = 0; i < len; i += 1) out[i] = (Math.random() * 256) | 0;
  return out;
};

const makeUuid = () => {
  const bytes = randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return (
    `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-` +
    `${hex.slice(16, 20)}-${hex.slice(20)}`
  );
};

const makeSecret = () => {
  const bytes = randomBytes(32);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
};

export const ensureDeviceCredentials = () => {
  let deviceId = prefs.getDeviceId();
  let deviceSecret = prefs.getDeviceSecret();
  if (!deviceId || !deviceSecret) {
    deviceId = makeUuid();
    deviceSecret = makeSecret();
    prefs.setDeviceCredentials(deviceId, deviceSecret);
  }
  return { deviceId, deviceSecret };
};

const request = async (method, path, body) => {
  const { deviceId, deviceSecret } = ensureDeviceCredentials();
  /** @type {Record<string, string>} */
  const headers = {
    'X-Device-Id': deviceId,
    'X-Device-Secret': deviceSecret,
  };
  /** @type {RequestInit} */
  const opts = { method, headers };
  if (body != null && method !== 'GET' && method !== 'DELETE') {
    headers['Content-Type'] = 'application/json';
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(API_BASE + path, opts);
  let data = {};
  try {
    data = await res.json();
  } catch {
    data = {};
  }
  if (res.ok && data && data.success) return data.data;
  // Never echo credentials; keep server message short.
  const msg = String((data && data.message) || `HTTP ${res.status}`).slice(0, 200);
  const err = new Error(msg);
  err.status = res.status;
  throw err;
};

export const prefsPayload = () => ({
  locale: prefs.getLocale() || '',
  ambient: getAmbientMode() || 'off',
  storageMode: prefs.getStorageMode(),
  finishTone: prefs.getFinishTone(),
  finishVibrate: prefs.getFinishVibrate(),
  finishNotify: prefs.getFinishNotify(),
  standRitual: p0.getStandRitual(),
  alertProfile: p0.getAlertProfile(),
  overtimeInsight: p0.getShowOvertimeInsight(),
  customMin: prefs.getCustomMin(5),
  customScenes: prefs.getCustomScenes(),
});

const sessionsPayload = () =>
  getHistory().map((row) => ({
    clientId: row.id,
    at: row.at,
    minutes: row.minutes,
    sceneId: row.sceneId || '',
    elapsedMs: row.elapsedMs || 0,
  }));

/**
 * @param {Record<string, unknown>} remote
 * @param {{ onLocale?: (code: string) => void }} [hooks]
 */
export const applyRemotePrefs = (remote, hooks = {}) => {
  if (!remote || typeof remote !== 'object') return;
  if (remote.locale) {
    const code = String(remote.locale);
    prefs.setLocale(code);
    hooks.onLocale?.(code);
  }
  if (remote.ambient) void setAmbientMode(String(remote.ambient));
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
};

const MAX_REMOTE_SESSIONS = 500;
const MAX_CLIENT_ID_LEN = 64;
const MAX_SCENE_ID_LEN = 64;

const mergeRemoteSessions = (remoteSessions) => {
  if (!Array.isArray(remoteSessions) || remoteSessions.length === 0) return;
  const local = getHistory();
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
  replaceHistory(merged);
};

export const register = async () => {
  // Credentials only in X-Device-* headers — body must not include them (server 400).
  ensureDeviceCredentials();
  await request('POST', '/register', {});
};

export const pushSnapshot = async () => {
  await register();
  return request('PUT', '/snapshot', {
    prefs: prefsPayload(),
    sessions: sessionsPayload(),
  });
};

export const pullAndMerge = async (hooks) => {
  await register();
  const snap = await request('GET', '/snapshot');
  if (snap && snap.prefs) applyRemotePrefs(snap.prefs, hooks);
  if (snap && Array.isArray(snap.sessions)) mergeRemoteSessions(snap.sessions);
  return snap;
};

export const syncNow = async (hooks) => {
  if (prefs.getStorageMode() !== 'cloud') return { skipped: true };
  await pushSnapshot();
  await pullAndMerge(hooks);
  return { ok: true };
};

export const pushPrefsOnly = async () => {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('PUT', '/prefs', { prefs: prefsPayload() });
};

export const pushSessionsOnly = async () => {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('PUT', '/sessions', { sessions: sessionsPayload() });
};

export const deleteRemoteSession = async (clientId) => {
  if (prefs.getStorageMode() !== 'cloud' || !clientId) return;
  await register();
  await request('DELETE', `/sessions/${encodeURIComponent(clientId)}`);
};

export const clearRemoteSessions = async () => {
  if (prefs.getStorageMode() !== 'cloud') return;
  await register();
  await request('POST', '/sessions/clear', {});
};

export const enableCloud = async (hooks) => {
  prefs.setStorageMode('cloud');
  try {
    await syncNow(hooks);
  } catch (e) {
    prefs.setStorageMode('local');
    prefs.clearDeviceCredentials();
    throw e;
  }
};

export const disableCloud = () => {
  prefs.setStorageMode('local');
  prefs.clearDeviceCredentials();
};

/**
 * Restore from user-held recovery code, then sync.
 * @param {string} code
 * @param {{ onLocale?: (code: string) => void }} [hooks]
 */
export const restoreWithCode = async (code, hooks) => {
  const parsed = prefs.parseRecoveryCode(code);
  if (!parsed) {
    const err = new Error('invalid');
    err.code = 'invalid';
    throw err;
  }
  prefs.setDeviceCredentials(parsed.deviceId, parsed.deviceSecret);
  prefs.setStorageMode('cloud');
  try {
    await syncNow(hooks);
  } catch (e) {
    prefs.setStorageMode('local');
    prefs.clearDeviceCredentials();
    throw e;
  }
};
