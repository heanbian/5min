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

const LOCALE_STORAGE_KEY = '5min.locale';

const LOCALE_CODES = Object.freeze([
  'zh-CN',
  'zh-TW',
  'en',
  'bo',
  'ja',
  'ar',
  'fr',
  'ru',
  'es',
]);

const BUNDLES = {
  'zh-CN': require('../shared/locales/zh_CN.js'),
  'zh-TW': require('../shared/locales/zh_TW.js'),
  en: require('../shared/locales/en.js'),
  bo: require('../shared/locales/bo.js'),
  ja: require('../shared/locales/ja.js'),
  ar: require('../shared/locales/ar.js'),
  fr: require('../shared/locales/fr.js'),
  ru: require('../shared/locales/ru.js'),
  es: require('../shared/locales/es.js'),
};

let currentLocale = 'zh-CN';

function resolveLocale(code) {
  if (code && BUNDLES[code]) return code;
  return 'zh-CN';
}

function detectLocale() {
  try {
    const saved = wx.getStorageSync(LOCALE_STORAGE_KEY);
    if (saved && BUNDLES[saved]) return saved;
  } catch (e) {
    /* ignore */
  }
  try {
    const info = wx.getAppBaseInfo
      ? wx.getAppBaseInfo()
      : wx.getSystemInfoSync();
    const lang = String(
      (info && (info.language || info.lang)) || ''
    ).toLowerCase();
    if (lang.startsWith('zh')) {
      if (lang.includes('tw') || lang.includes('hk') || lang.includes('hant')) {
        return 'zh-TW';
      }
      return 'zh-CN';
    }
    const short = lang.split(/[-_]/)[0];
    const hit = LOCALE_CODES.find(
      (c) => c.toLowerCase() === lang || c.toLowerCase() === short
    );
    if (hit) return hit;
  } catch (e) {
    /* ignore */
  }
  return 'zh-CN';
}

function setLocale(code) {
  currentLocale = resolveLocale(code);
  try {
    wx.setStorageSync(LOCALE_STORAGE_KEY, currentLocale);
  } catch (e) {
    /* ignore */
  }
  return currentLocale;
}

function getLocale() {
  return currentLocale;
}

function initLocale() {
  currentLocale = detectLocale();
  return currentLocale;
}

function bundle(locale) {
  return BUNDLES[resolveLocale(locale)] || BUNDLES['zh-CN'];
}

/**
 * @param {string} key
 * @param {Record<string, string|number>} [vars]
 * @param {string} [locale]
 */
function t(key, vars, locale) {
  const pack = bundle(locale || currentLocale);
  let text = pack[key];
  if (typeof text !== 'string') {
    const fallback = BUNDLES['zh-CN'][key];
    text = typeof fallback === 'string' ? fallback : key;
  }
  if (vars) {
    Object.keys(vars).forEach((k) => {
      text = text.split(`{${k}}`).join(String(vars[k]));
    });
  }
  return text;
}

function nativeName(code) {
  return t('nativeName', null, resolveLocale(code));
}

function localeOptions() {
  return LOCALE_CODES.map((code) => ({
    code,
    label: nativeName(code),
    active: code === currentLocale,
  }));
}

function isRtl(locale) {
  return resolveLocale(locale || currentLocale) === 'ar';
}

module.exports = {
  LOCALE_CODES,
  LOCALE_STORAGE_KEY,
  initLocale,
  setLocale,
  getLocale,
  detectLocale,
  t,
  nativeName,
  localeOptions,
  isRtl,
};
