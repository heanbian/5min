/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * https-only external links, host-allowlisted to 5min.chat.
 */

const { t } = require('./i18n');

/** Official site only (matches WeChat 业务域名). */
const ALLOWED_HTTPS =
  /^https:\/\/(?:[a-z0-9-]+\.)*5min\.chat(?::\d+)?(?:[/?#]|$)/i;

/** In-app web-view may only open known public pages (path allowlist). */
const ALLOWED_PATHS = new Set([
  '/privacy.html',
  '/terms.html',
  '/about.html',
  '/download.html',
  '/faq.html',
  '/',
]);

function hostOf(url) {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (e) {
    const m = /^https:\/\/([^/:?#]+)/i.exec(url);
    return m ? m[1].toLowerCase() : '';
  }
}

function pathOf(url) {
  try {
    let p = new URL(url).pathname || '/';
    if (p.length > 1 && p.endsWith('/')) p = p.slice(0, -1);
    return p || '/';
  } catch (e) {
    return '';
  }
}

function isAllowedHttps(url) {
  const u = String(url || '').trim();
  if (!ALLOWED_HTTPS.test(u)) return false;
  const host = hostOf(u);
  if (!(host === '5min.chat' || host.endsWith('.5min.chat'))) return false;
  const path = pathOf(u);
  return ALLOWED_PATHS.has(path);
}

function openHttps(url) {
  const u = String(url || '').trim();
  if (!isAllowedHttps(u)) {
    try {
      wx.showToast({ title: t('invalidLink'), icon: 'none' });
    } catch (e) {
      /* ignore */
    }
    return;
  }
  wx.navigateTo({
    url: `/pages/webview/webview?url=${encodeURIComponent(u)}`,
    fail() {
      try {
        wx.setClipboardData({
          data: u,
          success() {
            wx.showToast({ title: t('linkCopied'), icon: 'none' });
          },
        });
      } catch (e) {
        /* ignore */
      }
    },
  });
}

module.exports = { openHttps, isAllowedHttps };
