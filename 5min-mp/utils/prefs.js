/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * App settings only; session history lives in history.js.
 */

const LOCALE_KEY = '5min.locale';
const AMBIENT_KEY = '5min.ambient';
const PRIVACY_KEY = '5min.privacyAccepted';
const CUSTOM_MIN_KEY = '5min.customMin';
const CUSTOM_SCENES_KEY = '5min.custom_scenes';
const CUSTOM_SCENES_MIGRATED_KEY = '5min.custom_scenes_migrated';
const FINISH_TONE_KEY = '5min.finish_tone';
const FINISH_VIBRATE_KEY = '5min.finish_vibrate';
const FINISH_NOTIFY_KEY = '5min.finish_notify';
const STORAGE_MODE_KEY = '5min.storage_mode';
const DEVICE_ID_KEY = '5min.device_id';
const DEVICE_SECRET_KEY = '5min.device_secret';

const MAX_COUNT = 30;
const MAX_NAME = 24;
const ID_PREFIX = 'custom_';

function getLocale() {
  try {
    return String(wx.getStorageSync(LOCALE_KEY) || '');
  } catch (e) {
    return '';
  }
}

function setLocale(code) {
  try {
    wx.setStorageSync(LOCALE_KEY, String(code || ''));
  } catch (e) {
    /* ignore */
  }
}

function getAmbient() {
  try {
    const v = wx.getStorageSync(AMBIENT_KEY);
    return v || 'off';
  } catch (e) {
    return 'off';
  }
}

function setAmbient(mode) {
  try {
    wx.setStorageSync(AMBIENT_KEY, mode || 'off');
  } catch (e) {
    /* ignore */
  }
}

function isPrivacyAccepted() {
  try {
    return !!wx.getStorageSync(PRIVACY_KEY);
  } catch (e) {
    return false;
  }
}

function setPrivacyAccepted(ok) {
  try {
    wx.setStorageSync(PRIVACY_KEY, !!ok);
  } catch (e) {
    /* ignore */
  }
}

function clampMinutes(value) {
  const n = Math.floor(Number(value) || 0);
  return Math.max(1, Math.min(90, n));
}

function normalizeName(raw) {
  const trimmed = String(raw || '').trim();
  if (trimmed.length <= MAX_NAME) return trimmed;
  return trimmed.slice(0, MAX_NAME);
}

function makeId() {
  const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
  return ID_PREFIX + uuid;
}

function getCustomMin(fallback) {
  const fb = fallback == null ? 5 : fallback;
  try {
    const n = Number(wx.getStorageSync(CUSTOM_MIN_KEY));
    if (!Number.isFinite(n) || n < 1) return fb;
    return Math.min(90, Math.floor(n));
  } catch (e) {
    return fb;
  }
}

function setCustomMin(min) {
  const n = clampMinutes(min || 5);
  try {
    wx.setStorageSync(CUSTOM_MIN_KEY, n);
  } catch (e) {
    /* ignore */
  }
  return n;
}

function sanitizeScene(raw) {
  if (!raw || typeof raw !== 'object') return null;
  const name = normalizeName(raw.name);
  if (!name) return null;
  const id = String(raw.id || '').trim() || makeId();
  return {
    id,
    name,
    min: clampMinutes(raw.min),
  };
}

function getCustomScenes() {
  try {
    const raw = wx.getStorageSync(CUSTOM_SCENES_KEY);
    if (!Array.isArray(raw)) return [];
    return raw
      .map(sanitizeScene)
      .filter(Boolean)
      .slice(0, MAX_COUNT);
  } catch (e) {
    return [];
  }
}

function setCustomScenes(scenes) {
  const cleaned = (Array.isArray(scenes) ? scenes : [])
    .map(sanitizeScene)
    .filter(Boolean)
    .slice(0, MAX_COUNT);
  try {
    wx.setStorageSync(CUSTOM_SCENES_KEY, cleaned);
  } catch (e) {
    /* ignore */
  }
  markCustomScenesMigrated();
  return cleaned;
}

function isCustomScenesMigrated() {
  try {
    return !!wx.getStorageSync(CUSTOM_SCENES_MIGRATED_KEY);
  } catch (e) {
    return false;
  }
}

function markCustomScenesMigrated() {
  try {
    wx.setStorageSync(CUSTOM_SCENES_MIGRATED_KEY, true);
  } catch (e) {
    /* ignore */
  }
}

function migrateFinishAlertPrefsIfNeeded() {
  try {
    const info = wx.getStorageInfoSync();
    if (info.keys && info.keys.indexOf(FINISH_TONE_KEY) >= 0) {
      return;
    }
  } catch (e) {
    /* fall through to migration */
  }
  const ambient = getAmbient();
  const legacyTone = ambient !== 'off';
  try {
    wx.setStorageSync(FINISH_TONE_KEY, legacyTone);
    wx.setStorageSync(FINISH_VIBRATE_KEY, true);
    wx.setStorageSync(FINISH_NOTIFY_KEY, true);
  } catch (e) {
    /* ignore */
  }
}

function getFinishTone() {
  migrateFinishAlertPrefsIfNeeded();
  try {
    const v = wx.getStorageSync(FINISH_TONE_KEY);
    if (v === '' || v == null) return getAmbient() !== 'off';
    return !!v;
  } catch (e) {
    return true;
  }
}

function setFinishTone(on) {
  try {
    wx.setStorageSync(FINISH_TONE_KEY, !!on);
  } catch (e) {
    /* ignore */
  }
}

function getFinishVibrate() {
  migrateFinishAlertPrefsIfNeeded();
  try {
    const v = wx.getStorageSync(FINISH_VIBRATE_KEY);
    if (v === '' || v == null) return true;
    return !!v;
  } catch (e) {
    return true;
  }
}

function setFinishVibrate(on) {
  try {
    wx.setStorageSync(FINISH_VIBRATE_KEY, !!on);
  } catch (e) {
    /* ignore */
  }
}

function getFinishNotify() {
  migrateFinishAlertPrefsIfNeeded();
  try {
    const v = wx.getStorageSync(FINISH_NOTIFY_KEY);
    if (v === '' || v == null) return true;
    return !!v;
  } catch (e) {
    return true;
  }
}

function setFinishNotify(on) {
  try {
    wx.setStorageSync(FINISH_NOTIFY_KEY, !!on);
  } catch (e) {
    /* ignore */
  }
}

function getStorageMode() {
  try {
    const v = String(wx.getStorageSync(STORAGE_MODE_KEY) || 'local');
    return v === 'cloud' ? 'cloud' : 'local';
  } catch (e) {
    return 'local';
  }
}

function setStorageMode(mode) {
  try {
    wx.setStorageSync(STORAGE_MODE_KEY, mode === 'cloud' ? 'cloud' : 'local');
  } catch (e) {
    /* ignore */
  }
}

function getDeviceId() {
  try {
    return String(wx.getStorageSync(DEVICE_ID_KEY) || '');
  } catch (e) {
    return '';
  }
}

function getDeviceSecret() {
  try {
    return String(wx.getStorageSync(DEVICE_SECRET_KEY) || '');
  } catch (e) {
    return '';
  }
}

function setDeviceCredentials(deviceId, deviceSecret) {
  try {
    wx.setStorageSync(DEVICE_ID_KEY, String(deviceId || ''));
    wx.setStorageSync(DEVICE_SECRET_KEY, String(deviceSecret || ''));
  } catch (e) {
    /* ignore */
  }
}

/** Drop cloud identity when leaving cloud mode. */
function clearDeviceCredentials() {
  try {
    wx.removeStorageSync(DEVICE_ID_KEY);
    wx.removeStorageSync(DEVICE_SECRET_KEY);
  } catch (e) {
    /* ignore */
  }
}

/** Recovery code: deviceId:deviceSecret */
function formatRecoveryCode() {
  const id = getDeviceId();
  const secret = getDeviceSecret();
  if (!id || !secret) return '';
  return `${id}:${secret}`;
}

/**
 * @param {string} raw
 * @returns {{ deviceId: string, deviceSecret: string } | null}
 */
function parseRecoveryCode(raw) {
  const text = String(raw || '').trim().replace(/\s+/g, '');
  const idx = text.indexOf(':');
  if (idx <= 0) return null;
  const deviceId = text.slice(0, idx);
  const deviceSecret = text.slice(idx + 1);
  // Align with server DEVICE_ID_RE / SECRET_RE and 5min-web.
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      deviceId,
    )
  ) {
    return null;
  }
  if (!/^[0-9a-f]{32,128}$/i.test(deviceSecret)) return null;
  // Reject all-zero / broken CSPRNG leftovers.
  if (/^0{8}-0{4}-4000-8000-0{12}$/i.test(deviceId)) return null;
  if (/^0+$/i.test(deviceSecret)) return null;
  return { deviceId, deviceSecret };
}

module.exports = {
  MAX_COUNT,
  MAX_NAME,
  getLocale,
  setLocale,
  getAmbient,
  setAmbient,
  isPrivacyAccepted,
  setPrivacyAccepted,
  getCustomMin,
  setCustomMin,
  clampMinutes,
  normalizeName,
  makeId,
  getCustomScenes,
  setCustomScenes,
  isCustomScenesMigrated,
  markCustomScenesMigrated,
  getFinishTone,
  setFinishTone,
  getFinishVibrate,
  setFinishVibrate,
  getFinishNotify,
  setFinishNotify,
  getStorageMode,
  setStorageMode,
  getDeviceId,
  getDeviceSecret,
  setDeviceCredentials,
  clearDeviceCredentials,
  formatRecoveryCode,
  parseRecoveryCode,
};
