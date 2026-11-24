/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */
(() => {
  const STORES = {
    ios: {
      url: 'https://apps.apple.com/app/id6831430796',
      label: 'App Store',
    },
    android: {
      url: 'https://fs-chengdu.oss-cn-chengdu.aliyuncs.com/app/5min-android-app-1.0.15.apk',
      label: '下载',
    },
    harmony: {
      url: 'https://5min.chat/5min-harmony-app',
      label: '打开',
    },
  };

  const SUGGEST = {
    ios: '检测到 iOS 设备，建议优先前往 App Store 安装官方客户端。',
    android: '检测到 Android 设备，建议优先下载官方安装包。',
    harmony: '检测到 HarmonyOS 设备，建议优先通过应用链接打开或前往应用市场安装。',
    mp: '当前处于微信内，可展开小程序码后长按识别打开。',
  };

  const detectPlatform = () => {
    const ua = navigator.userAgent || '';
    if (/MicroMessenger/i.test(ua)) return 'mp';
    if (/HarmonyOS|OpenHarmony/i.test(ua)) return 'harmony';
    if (/Android/i.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
    return 'web';
  };

  const syncStoreLink = (el, url, label) => {
    if (!el || !url) return;
    el.href = url;
    el.textContent = label;
    el.classList.add('action-primary');
    let sameOrigin = false;
    try {
      sameOrigin = new URL(url, location.href).origin === location.origin;
    } catch {
      sameOrigin = false;
    }
    if (sameOrigin) {
      el.removeAttribute('target');
      el.removeAttribute('rel');
    } else {
      el.setAttribute('target', '_blank');
      el.setAttribute('rel', 'noopener noreferrer');
    }
  };

  const setMpOpen = (row, toggle, drawer, open) => {
    if (!row || !toggle || !drawer) return;
    row.classList.toggle('is-open', open);
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    toggle.textContent = open ? '收起' : '扫码打开';
    drawer.setAttribute('aria-hidden', open ? 'false' : 'true');
  };

  const root = document.getElementById('channels');
  const list = document.getElementById('platform-list');
  const hint = document.getElementById('platform-hint');
  if (!root || !list) return;

  Object.keys(STORES).forEach((key) => {
    const row = list.querySelector(`[data-platform="${key}"]`);
    const cfg = STORES[key];
    if (!row || !cfg) return;
    const btn = row.querySelector('[data-role="store"]');
    syncStoreLink(btn, cfg.url, cfg.label);
  });

  /** Only https URLs on 5min.chat or the known APK CDN host. */
  const trustedApkUrl = (raw) => {
    const url = String(raw || '').trim();
    if (!url.toLowerCase().startsWith('https://')) return null;
    let host = '';
    try {
      host = new URL(url).hostname.toLowerCase();
    } catch {
      return null;
    }
    const allowed = new Set([
      '5min.chat',
      'www.5min.chat',
      'fs-chengdu.oss-cn-chengdu.aliyuncs.com',
    ]);
    return allowed.has(host) ? url : null;
  };

  const applyAndroidLatest = async () => {
    try {
      const res = await fetch('app/android-latest.json', { cache: 'no-cache' });
      if (!res.ok) return;
      const data = await res.json();
      const url = trustedApkUrl(data && data.apkUrl);
      if (!url) return;
      STORES.android.url = url;
      const row = list.querySelector('[data-platform="android"]');
      const btn = row && row.querySelector('[data-role="store"]');
      syncStoreLink(btn, url, STORES.android.label);
    } catch {
      /* keep HTML / STORES fallback */
    }
  };
  void applyAndroidLatest();

  const mpRow = list.querySelector('[data-platform="mp"]');
  const mpToggle = mpRow && mpRow.querySelector('[data-role="mp-toggle"]');
  const mpDrawer = document.getElementById('mp-drawer');
  if (mpRow && mpToggle && mpDrawer) {
    mpRow.addEventListener('click', (event) => {
      const toggle = event.target.closest('[data-role="mp-toggle"]');
      if (!toggle || !mpRow.contains(toggle)) return;
      event.preventDefault();
      const open = !mpRow.classList.contains('is-open');
      setMpOpen(mpRow, mpToggle, mpDrawer, open);
    });
  }

  const suggested = detectPlatform();
  if (hint && suggested !== 'web' && SUGGEST[suggested]) {
    hint.hidden = false;
    hint.textContent = SUGGEST[suggested];
    const row = list.querySelector(`[data-platform="${suggested}"]`);
    if (row) row.classList.add('is-suggested');
  }
})();
