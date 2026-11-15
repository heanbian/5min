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
  return Math.max(1, Math.min(120, n));
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
    return Math.min(120, Math.floor(n));
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
};
