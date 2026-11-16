/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */
(() => {
  const STORES = {
    ios: {
      // 例：https://apps.apple.com/app/idXXXXXXXX
      url: '',
      label: '前往 App Store',
    },
    android: {
      // 例：https://play.google.com/store/apps/details?id=chat.fivemin.app
      url: 'https://fs-chengdu.oss-cn-chengdu.aliyuncs.com/app/5min-android-app-1.0.10.apk',
      label: '点击下载',
    },
    harmony: {
      // 例：华为应用市场详情页
      url: '',
      label: '前往应用市场',
    },
  };

  const MP_TIP =
    '在微信中打开「搜索」，输入「五分钟如厕计时器」，选择官方小程序即可使用。';

  const SUGGEST = {
    ios: '当前设备更可能适合使用 iOS 客户端，可优先查看本页 iOS 入口。',
    android: '当前设备更可能适合使用 Android 客户端，可优先查看本页 Android 入口。',
    harmony: '当前设备更可能适合使用 HarmonyOS 客户端，可优先查看本页 HarmonyOS 入口。',
    mp: '当前处于微信内，可按本页说明打开小程序，或先使用网页版。',
    web: '也可先使用网页版；商店上架后可再安装官方客户端。',
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
    el.classList.remove('is-disabled', 'btn-muted');
    el.classList.add('btn-primary');
    el.removeAttribute('aria-disabled');
    el.setAttribute('target', '_blank');
    el.setAttribute('rel', 'noopener noreferrer');
  };

  const list = document.getElementById('platform-list');
  const hint = document.getElementById('platform-hint');
  if (!list) return;

  Object.keys(STORES).forEach((key) => {
    const row = list.querySelector(`[data-platform="${key}"]`);
    const cfg = STORES[key];
    if (!row || !cfg) return;
    const btn = row.querySelector('[data-role="store"]');
    if (cfg.url) enableStoreLink(btn, cfg.url, cfg.label);
  });

  const suggested = detectPlatform();
  const suggestedRow = list.querySelector(`[data-platform="${suggested}"]`);
  if (suggestedRow) {
    suggestedRow.classList.add('is-suggested');
    if (hint && SUGGEST[suggested]) {
      hint.hidden = false;
      hint.textContent = SUGGEST[suggested];
    }
  }

  const mpBtn = list.querySelector('[data-role="mp-tip"]');
  if (mpBtn && hint) {
    mpBtn.addEventListener('click', () => {
      hint.hidden = false;
      hint.textContent = MP_TIP;
    });
  }
})();
