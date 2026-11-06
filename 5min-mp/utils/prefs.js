/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * App settings only; session history lives in history.js.
 */

const LOCALE_KEY = '5min.locale';
const AMBIENT_KEY = '5min.ambient';
const PRIVACY_KEY = '5min.privacyAccepted';
const CUSTOM_MIN_KEY = '5min.customMin';

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
  const n = Math.max(1, Math.min(120, Math.floor(Number(min) || 5)));
  try {
    wx.setStorageSync(CUSTOM_MIN_KEY, n);
  } catch (e) {
    /* ignore */
  }
  return n;
}

module.exports = {
  getLocale,
  setLocale,
  getAmbient,
  setAmbient,
  isPrivacyAccepted,
  setPrivacyAccepted,
  getCustomMin,
  setCustomMin,
};
