/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * https-only external links (parity with Harmony OpenUrl).
 */

function openHttps(url) {
  const u = String(url || '');
  if (u.indexOf('https://') !== 0 && u.indexOf('HTTPS://') !== 0) return;
  wx.navigateTo({
    url: `/pages/webview/webview?url=${encodeURIComponent(u)}`,
    fail() {
      // Fallback: copy link if web-view page unavailable
      try {
        wx.setClipboardData({ data: u });
        wx.showToast({ title: '链接已复制', icon: 'none' });
      } catch (e) {
        /* ignore */
      }
    },
  });
}

module.exports = { openHttps };
