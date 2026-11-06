/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const zhCN = require('../shared/locales/zh_CN.js');
const zhTW = require('../shared/locales/zh_TW.js');
const en = require('../shared/locales/en.js');
const { normalize, SUPPORTED, filter } = require('./appLocales');
const prefs = require('./prefs');

const PACKS = Object.freeze({
  'zh-CN': zhCN,
  'zh-TW': zhTW,
  en,
});

let currentLocale = 'zh-CN';

function packOf(code) {
  return PACKS[code] || PACKS['zh-CN'];
}

function resolveSystemLocale() {
  try {
    const info = wx.getAppBaseInfo
      ? wx.getAppBaseInfo()
      : wx.getSystemInfoSync();
    const tag =
      (info && (info.language || info.locale)) ||
      (typeof wx.getSystemInfoSync === 'function'
        ? wx.getSystemInfoSync().language
        : '') ||
      '';
    return normalize(tag, 'zh-CN');
  } catch (e) {
    return 'zh-CN';
  }
}

function resolveInitial() {
  const saved = prefs.getLocale();
  if (saved) return normalize(saved, 'zh-CN');
  return resolveSystemLocale();
}

function getLocale() {
  return currentLocale;
}

function setLocale(code) {
  const next = normalize(code, 'zh-CN');
  currentLocale = next;
  prefs.setLocale(next);
  return next;
}

function initLocale() {
  currentLocale = resolveInitial();
  prefs.setLocale(currentLocale);
  return currentLocale;
}

/**
 * @param {string} key
 * @param {Record<string, string|number>} [vars]
 * @param {string} [locale]
 */
function t(key, vars, locale) {
  const code = locale ? normalize(locale, currentLocale) : currentLocale;
  const pack = packOf(code);
  let text = pack[key];
  if (typeof text !== 'string') {
    text = packOf('zh-CN')[key];
  }
  if (typeof text !== 'string') return key;
  if (vars) {
    Object.keys(vars).forEach((k) => {
      text = text.split(`{${k}}`).join(String(vars[k]));
    });
  }
  return text;
}

function appLocaleCodes() {
  return filter(SUPPORTED);
}

function nativeName(code) {
  return t('nativeName', null, normalize(code));
}

module.exports = {
  t,
  getLocale,
  setLocale,
  initLocale,
  resolveInitial,
  appLocaleCodes,
  nativeName,
  SUPPORTED,
};
