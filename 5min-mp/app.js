/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { initLocale } = require('./utils/i18n');
const { initAmbient } = require('./utils/ambient');
const prefs = require('./utils/prefs');
const { realertFinishIfPending } = require('./utils/alert');

App({
  globalData: {
    /** Apply on next home show after Mine custom-scene Use / add. */
    pendingSceneId: null,
    privacyAccepted: false,
    appVersion: '1.0.11',
    /** Local finish still pending dismiss / reset — used for re-alert onShow. */
    finishAlertPending: null,
    finishAlerting: false,
  },

  onLaunch() {
    initLocale();
    initAmbient();
    this.globalData.privacyAccepted = prefs.isPrivacyAccepted();
    this.loadAppFonts();
  },

  /** Plus Jakarta Sans — Latin UI；中文回退系统字体 */
  loadAppFonts() {
    const faces = [
      { weight: 400, file: 'PlusJakartaSans-Regular.ttf' },
      { weight: 500, file: 'PlusJakartaSans-Medium.ttf' },
      { weight: 600, file: 'PlusJakartaSans-SemiBold.ttf' },
      { weight: 700, file: 'PlusJakartaSans-Bold.ttf' },
    ];
    faces.forEach(({ weight, file }) => {
      try {
        wx.loadFontFace({
          global: true,
          family: 'Plus Jakarta Sans',
          source: `url("/fonts/${file}")`,
          scopes: ['webview', 'native'],
          desc: { style: 'normal', weight: String(weight) },
          fail: () => {},
        });
      } catch (e) {
        /* ignore */
      }
    });
  },

  onShow() {
    // Re-cue local finish when returning from background (no OS push).
    realertFinishIfPending();
    if (prefs.getStorageMode() !== 'cloud') return;
    try {
      require('./utils/cloudSync')
        .syncNow()
        .catch(() => {});
    } catch (e) {
      /* ignore */
    }
  },
});
