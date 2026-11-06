/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * App UI locales — aligned with 5min-harmony-app AppLocales.
 */

const SUPPORTED = Object.freeze(['zh-CN', 'zh-TW', 'en']);

function isSupported(code) {
  return SUPPORTED.indexOf(code) >= 0;
}

function normalize(code, fallback) {
  const fb = fallback || 'zh-CN';
  const trimmed = String(code || '')
    .trim()
    .replace(/_/g, '-');
  if (isSupported(trimmed)) return trimmed;
  if (!trimmed) return fb;
  const parts = trimmed.split('-');
  const base = (parts[0] || '').toLowerCase();
  const region = (parts[1] || '').toUpperCase();
  if (base === 'zh') {
    if (
      region === 'TW' ||
      region === 'HK' ||
      region === 'MO' ||
      trimmed.toLowerCase().indexOf('hant') >= 0
    ) {
      return 'zh-TW';
    }
    return 'zh-CN';
  }
  if (base === 'en') return 'en';
  return fb;
}

function filter(codes) {
  const list = Array.isArray(codes) ? codes : [];
  const hit = SUPPORTED.filter((c) => list.indexOf(c) >= 0);
  return hit.length ? hit : SUPPORTED.slice();
}

module.exports = {
  SUPPORTED,
  isSupported,
  normalize,
  filter,
};
