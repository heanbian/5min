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
      // 例：https://play.google.com/store/apps/details?id=chat.fivemin.app
      url: 'https://fs-chengdu.oss-cn-chengdu.aliyuncs.com/app/5min-android-app-latest.apk',
      label: '下载',
    },
    harmony: {
      // 同款 C 号形态例：https://appgallery.huawei.com/app/C10220136；有本应用 C 号后可替换
      url: 'https://appgallery.huawei.com/app/detail?id=chat.5min.app',
      label: '应用市场',
    },
  };

  const SUGGEST = {
    ios: '当前设备更适合使用 iOS 客户端，可优先前往 App Store 安装。',
    android: '当前设备更适合使用 Android 客户端，可优先下载官方安装包。',
    harmony: '当前设备更适合使用 HarmonyOS 客户端，可优先前往华为应用市场安装。',
    mp: '当前处于微信内，可展开小程序码后长按识别打开。',
    web: '也可先使用网页版；商店上架后再安装官方客户端。',
  };

  const detectPlatform = () => {
    const ua = navigator.userAgent || '';
    if (/MicroMessenger/i.test(ua)) return 'mp';
    if (/HarmonyOS|OpenHarmony/i.test(ua)) return 'harmony';
    if (/Android/i.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/i.test(ua)) return 'ios';
    return 'web';
  };

  const enableStoreLink = (el, url, label) => {
    if (!el || !url) return;
    el.href = url;
    el.textContent = label;
    el.classList.remove('is-disabled');
    el.classList.add('action-primary');
    el.removeAttribute('aria-disabled');
    el.setAttribute('target', '_blank');
    el.setAttribute('rel', 'noopener noreferrer');
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
    if (cfg.url) enableStoreLink(btn, cfg.url, cfg.label);
  });

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
  const suggestedEl = root.querySelector(`[data-platform="${suggested}"]`);
  if (suggestedEl) {
    suggestedEl.classList.add('is-suggested');
    if (hint && SUGGEST[suggested]) {
      hint.hidden = false;
      hint.textContent = SUGGEST[suggested];
    }
    if (suggested === 'mp' && mpRow && mpToggle && mpDrawer) {
      setMpOpen(mpRow, mpToggle, mpDrawer, true);
    }
  }
})();
