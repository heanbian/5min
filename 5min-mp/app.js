/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { initLocale } = require('./utils/i18n');
const { initAmbient } = require('./utils/ambient');
const prefs = require('./utils/prefs');

App({
  globalData: {
    /** Apply on next home show after Mine custom-scene Use / add. */
    pendingSceneId: null,
    privacyAccepted: false,
    appVersion: '1.0.7',
  },

  onLaunch() {
    initLocale();
    initAmbient();
    this.globalData.privacyAccepted = prefs.isPrivacyAccepted();
  },
});
