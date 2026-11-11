/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * https-only external links, host-allowlisted to 5min.chat.
 */

const { t } = require('./i18n');

/** Official site only (matches WeChat 业务域名). */
const ALLOWED_HTTPS =
  /^https:\/\/(?:[a-z0-9-]+\.)*5min\.chat(?::\d+)?(?:[/?#]|$)/i;

function hostOf(url) {
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (e) {
    const m = /^https:\/\/([^/:?#]+)/i.exec(url);
    return m ? m[1].toLowerCase() : '';
  }
}

function isAllowedHttps(url) {
  const u = String(url || '').trim();
  if (!ALLOWED_HTTPS.test(u)) return false;
  const host = hostOf(u);
  return host === '5min.chat' || host.endsWith('.5min.chat');
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
