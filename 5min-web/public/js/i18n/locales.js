/**
 * 5min locale runtime — ES module.
 * SPDX-License-Identifier: Apache-2.0
 * App UI locales (UN official languages first, then additional):
 *   zh-CN / zh-TW / en / fr / ru / es / ar · de / bo / ja / ko / pt / id
 * Packs live under ./packs/; zh-CN is eager, others load via ensureLocale().
 */

import zhCN from './packs/zh-CN.js';

export const LOCALE_CODES = Object.freeze([
  'zh-CN',
  'zh-TW',
  'en',
  'fr',
  'ru',
  'es',
  'ar',
  'de',
  'bo',
  'ja',
  'ko',
  'pt',
  'id',
]);

export const STORAGE_KEY = '5min.locale';
export const DEFAULT_LOCALE = 'zh-CN';

/** Picker labels without loading full packs. */
export const LOCALE_NATIVE_NAMES = Object.freeze({
  'zh-CN': '简体中文',
  'zh-TW': '繁體中文',
  en: 'English',
  fr: 'Français',
  ru: 'Русский',
  es: 'Español',
  ar: 'العربية',
  de: 'Deutsch',
  bo: 'བོད་ཡིག',
  ja: '日本語',
  ko: '한국어',
  pt: 'Português',
  id: 'Bahasa Indonesia',
});

const packLoaders = Object.freeze({
  'zh-CN': () => Promise.resolve({ default: zhCN }),
  'zh-TW': () => import('./packs/zh-TW.js'),
  en: () => import('./packs/en.js'),
  fr: () => import('./packs/fr.js'),
  ru: () => import('./packs/ru.js'),
  es: () => import('./packs/es.js'),
  ar: () => import('./packs/ar.js'),
  de: () => import('./packs/de.js'),
  bo: () => import('./packs/bo.js'),
  ja: () => import('./packs/ja.js'),
  ko: () => import('./packs/ko.js'),
  pt: () => import('./packs/pt.js'),
  id: () => import('./packs/id.js'),
});

/** @type {Record<string, Readonly<Record<string, string>>>} */
const packs = Object.create(null);
packs[DEFAULT_LOCALE] = zhCN;

/** Cache of loaded packs (zh-CN always present). Prefer ensureLocale() before sync reads. */
export const LOCALES = packs;

/**
 * Load a locale pack into LOCALES. Safe to call repeatedly.
 * @param {string} code
 * @returns {Promise<Readonly<Record<string, string>>>}
 */
export async function ensureLocale(code) {
  const resolved = resolveLocale(code) || DEFAULT_LOCALE;
  if (packs[resolved]) return packs[resolved];
  const loader = packLoaders[resolved];
  if (!loader) return packs[DEFAULT_LOCALE];
  const mod = await loader();
  packs[resolved] = mod.default;
  return packs[resolved];
}

/** Map BCP 47 / browser tags onto a supported locale code. */
export function resolveLocale(tag) {
  if (!tag || typeof tag !== 'string') return null;
  const lower = tag.trim().replace(/_/g, '-');
  if (packLoaders[lower]) return lower;
  const base = lower.split('-')[0]?.toLowerCase();
  const region = lower.split('-')[1]?.toUpperCase();
  if (base === 'zh') {
    if (region === 'TW' || region === 'HK' || region === 'MO' || lower.includes('hant')) {
      return 'zh-TW';
    }
    return 'zh-CN';
  }
  if (base === 'en') return 'en';
  if (base === 'fr') return 'fr';
  if (base === 'ru') return 'ru';
  if (base === 'es') return 'es';
  if (base === 'ar') return 'ar';
  if (base === 'de') return 'de';
  if (base === 'bo') return 'bo';
  if (base === 'ja') return 'ja';
  if (base === 'ko') return 'ko';
  if (base === 'pt') return 'pt';
  if (base === 'id') return 'id';
  return null;
}

export function detectLocale() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    const fromSaved = resolveLocale(saved);
    if (fromSaved) return fromSaved;
  } catch {
    /* private mode */
  }

  const candidates = [...(navigator.languages ?? []), navigator.language].filter(Boolean);

  for (const tag of candidates) {
    const hit = resolveLocale(tag);
    if (hit) return hit;
  }
  return DEFAULT_LOCALE;
}

export function t(locale, key, vars = {}) {
  const pack = packs[locale] ?? packs[DEFAULT_LOCALE];
  let text = pack[key] ?? packs[DEFAULT_LOCALE][key] ?? key;
  for (const [k, v] of Object.entries(vars)) {
    text = text.replaceAll('{' + k + '}', String(v));
  }
  return text;
}
