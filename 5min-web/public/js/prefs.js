/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * App settings (localStorage). Session history lives in history.js.
 */

import { getAmbientMode } from './ambient.js';
import {
  listCustomScenes,
  setCustomScenes as writeCustomScenes,
  clampMinutes,
} from './custom-scenes.js';

const LOCALE_KEY = '5min.locale';
const CUSTOM_MIN_KEY = '5min.customMin';
const FINISH_TONE_KEY = '5min.finish_tone';
const FINISH_VIBRATE_KEY = '5min.finish_vibrate';
const FINISH_NOTIFY_KEY = '5min.finish_notify';
const STORAGE_MODE_KEY = '5min.storage_mode';
const DEVICE_ID_KEY = '5min.device_id';
const DEVICE_SECRET_KEY = '5min.device_secret';

const lsGet = (key) => {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
};

const lsSet = (key, value) => {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
};

const lsRemove = (key) => {
  try {
    localStorage.removeItem(key);
  } catch {
    /* ignore */
  }
};

export const getLocale = () => String(lsGet(LOCALE_KEY) || '');

export const setLocale = (code) => {
  lsSet(LOCALE_KEY, String(code || ''));
};

export const getAmbient = () => getAmbientMode() || 'off';

export const getCustomMin = (fallback = 5) => {
  const n = Number(lsGet(CUSTOM_MIN_KEY));
  if (!Number.isFinite(n) || n < 1) return fallback;
  return Math.min(90, Math.floor(n));
};

export const setCustomMin = (min) => {
  const n = clampMinutes(min || 5);
  lsSet(CUSTOM_MIN_KEY, String(n));
  return n;
};

export const getCustomScenes = () => listCustomScenes();

export const setCustomScenes = (scenes) => writeCustomScenes(scenes);

const migrateFinishAlertPrefsIfNeeded = () => {
  if (lsGet(FINISH_TONE_KEY) !== null) return;
  const ambient = getAmbient();
  const legacyTone = ambient !== 'off';
  lsSet(FINISH_TONE_KEY, legacyTone ? '1' : '0');
  lsSet(FINISH_VIBRATE_KEY, '1');
  lsSet(FINISH_NOTIFY_KEY, '1');
};

const readBool = (key, fallback) => {
  const v = lsGet(key);
  if (v === null || v === '') return fallback;
  return v === '1' || v === 'true';
};

export const getFinishTone = () => {
  migrateFinishAlertPrefsIfNeeded();
  return readBool(FINISH_TONE_KEY, getAmbient() !== 'off');
};

export const setFinishTone = (on) => {
  lsSet(FINISH_TONE_KEY, on ? '1' : '0');
};

export const getFinishVibrate = () => {
  migrateFinishAlertPrefsIfNeeded();
  return readBool(FINISH_VIBRATE_KEY, true);
};

export const setFinishVibrate = (on) => {
  lsSet(FINISH_VIBRATE_KEY, on ? '1' : '0');
};

export const getFinishNotify = () => {
  migrateFinishAlertPrefsIfNeeded();
  return readBool(FINISH_NOTIFY_KEY, true);
};

export const setFinishNotify = (on) => {
  lsSet(FINISH_NOTIFY_KEY, on ? '1' : '0');
};

export const getStorageMode = () => {
  const v = String(lsGet(STORAGE_MODE_KEY) || 'local');
  return v === 'cloud' ? 'cloud' : 'local';
};

export const setStorageMode = (mode) => {
  lsSet(STORAGE_MODE_KEY, mode === 'cloud' ? 'cloud' : 'local');
};

export const getDeviceId = () => String(lsGet(DEVICE_ID_KEY) || '');

export const getDeviceSecret = () => String(lsGet(DEVICE_SECRET_KEY) || '');

export const setDeviceCredentials = (deviceId, deviceSecret) => {
  lsSet(DEVICE_ID_KEY, String(deviceId || ''));
  lsSet(DEVICE_SECRET_KEY, String(deviceSecret || ''));
};

export const clearDeviceCredentials = () => {
  lsRemove(DEVICE_ID_KEY);
  lsRemove(DEVICE_SECRET_KEY);
};

/** Recovery code: deviceId:deviceSecret */
export const formatRecoveryCode = () => {
  const id = getDeviceId();
  const secret = getDeviceSecret();
  if (!id || !secret) return '';
  return `${id}:${secret}`;
};

/**
 * @param {string} raw
 * @returns {{ deviceId: string, deviceSecret: string } | null}
 */
export const parseRecoveryCode = (raw) => {
  const text = String(raw || '').trim().replace(/\s+/g, '');
  const idx = text.indexOf(':');
  if (idx <= 0) return null;
  const deviceId = text.slice(0, idx);
  const deviceSecret = text.slice(idx + 1);
  // Align with server DEVICE_ID_RE / SECRET_RE.
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      deviceId,
    )
  ) {
    return null;
  }
  if (!/^[0-9a-f]{32,128}$/i.test(deviceSecret)) return null;
  return { deviceId, deviceSecret };
};
