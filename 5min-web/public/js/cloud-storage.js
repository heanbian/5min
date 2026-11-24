/**
 * Copyright 2026 学记宝 / xuejibao.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Light cloud client against /api/v1/storage.
 * Device credentials live in localStorage; no full sync UI on web yet.
 */

const API_BASE = '/api/v1/storage';
const DEVICE_ID_KEY = '5min.device_id';
const DEVICE_SECRET_KEY = '5min.device_secret';

const makeUuid = () => {
  if (globalThis.crypto?.randomUUID) return crypto.randomUUID();
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
  return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
};

const makeSecret = () => {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
};

const readCreds = () => {
  try {
    return {
      deviceId: String(localStorage.getItem(DEVICE_ID_KEY) || ''),
      deviceSecret: String(localStorage.getItem(DEVICE_SECRET_KEY) || ''),
    };
  } catch {
    return { deviceId: '', deviceSecret: '' };
  }
};

const writeCreds = (deviceId, deviceSecret) => {
  try {
    localStorage.setItem(DEVICE_ID_KEY, deviceId);
    localStorage.setItem(DEVICE_SECRET_KEY, deviceSecret);
  } catch {
    /* ignore */
  }
};

/** Drop cloud identity when leaving cloud mode / sync fails. */
export const clearDeviceCredentials = () => {
  try {
    localStorage.removeItem(DEVICE_ID_KEY);
    localStorage.removeItem(DEVICE_SECRET_KEY);
  } catch {
    /* ignore */
  }
};

/** Ensure deviceId/deviceSecret exist in localStorage. */
export const ensureDeviceCredentials = () => {
  let { deviceId, deviceSecret } = readCreds();
  if (!deviceId || !deviceSecret) {
    deviceId = makeUuid();
    deviceSecret = makeSecret();
    writeCreds(deviceId, deviceSecret);
  }
  return { deviceId, deviceSecret };
};

/**
 * @param {string} method
 * @param {string} path
 * @param {unknown} [body]
 */
const request = async (method, path, body) => {
  const { deviceId, deviceSecret } = ensureDeviceCredentials();
  const opts = {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-Device-Id': deviceId,
      'X-Device-Secret': deviceSecret,
    },
  };
  if (body != null && method !== 'GET' && method !== 'DELETE') {
    opts.body = JSON.stringify(body);
  }
  const res = await fetch(API_BASE + path, opts);
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.success) {
    const err = new Error((data && data.message) || `HTTP ${res.status}`);
    err.status = res.status;
    throw err;
  }
  return data.data;
};

/** Register (or re-register) this device with the storage API (headers only). */
export const register = () => {
  ensureDeviceCredentials();
  return request('POST', '/register', {});
};

/** @param {Record<string, unknown>} prefs */
export const putPrefs = (prefs) => request('PUT', '/prefs', { prefs });

/**
 * @param {Array<{id:string,at:number,minutes:number,sceneId?:string,elapsedMs?:number}>} sessions
 */
export const putSessions = (sessions) =>
  request('PUT', '/sessions', { sessions: Array.isArray(sessions) ? sessions : [] });

export const getSnapshot = () => request('GET', '/snapshot');

/**
 * Best-effort: register then push prefs + sessions.
 * @param {{ prefs?: Record<string, unknown>, sessions?: unknown[] }} payload
 */
export const pushSnapshot = async (payload = {}) => {
  await register();
  return request('PUT', '/snapshot', {
    prefs: payload.prefs || {},
    sessions: Array.isArray(payload.sessions) ? payload.sessions : [],
  });
};
