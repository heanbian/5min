/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * App bootstrap. Privacy consent is owned by pages/boot (non-tabBar entry).
 */

const { initLocale } = require('./utils/i18n');
const { initAmbient } = require('./utils/ambient');
const privacy = require('./services/privacy');
const { realertFinishIfPending } = require('./utils/alert');

App({
  globalData: {
    pendingSceneId: null,
    privacyAccepted: false,
    appVersion: '1.0.13',
    finishAlertPending: null,
    finishAlerting: false,
  },

  onLaunch() {
    initLocale();
    initAmbient();
    this.globalData.privacyAccepted = privacy.syncGlobal();
  },

  onShow() {
    realertFinishIfPending();
    if (!privacy.isAccepted()) return;
    try {
      const prefs = require('./utils/prefs');
      if (prefs.getStorageMode() !== 'cloud') return;
      require('./utils/cloudSync')
        .syncNow()
        .catch(() => {});
    } catch (e) {
      /* ignore */
    }
  },
});
