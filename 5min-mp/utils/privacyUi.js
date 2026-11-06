/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('./i18n');
const prefs = require('./prefs');
const { openHttps } = require('./openUrl');
const { updateTabBarLabels } = require('./tabBar');

function privacyLabels() {
  return {
    privacyTitle: t('privacyTitle'),
    privacyMessage: t('privacyMessage'),
    privacyCheckLabel: t('privacyCheckLabel'),
    privacyLink: t('privacyLink'),
    termsLink: t('termsLink'),
    privacyAgree: t('privacyAgree'),
  };
}

function syncTabBar(accepted) {
  try {
    if (accepted) wx.showTabBar({ animation: false });
    else wx.hideTabBar({ animation: false });
  } catch (e) {
    /* ignore */
  }
}

function applyPrivacyState(page) {
  const accepted = prefs.isPrivacyAccepted();
  const app = getApp();
  if (app && app.globalData) app.globalData.privacyAccepted = accepted;
  syncTabBar(accepted);
  if (accepted) updateTabBarLabels();
  page.setData({
    privacyAccepted: accepted,
    privacyChecked: false,
    ...privacyLabels(),
  });
}

function bindPrivacyHandlers(page) {
  page.onTogglePrivacyCheck = function onTogglePrivacyCheck() {
    this.setData({ privacyChecked: !this.data.privacyChecked });
  };
  page.onOpenPrivacy = function onOpenPrivacy() {
    openHttps('https://5min.chat/privacy.html');
  };
  page.onOpenTerms = function onOpenTerms() {
    openHttps('https://5min.chat/terms.html');
  };
  page.onAcceptPrivacy = function onAcceptPrivacy() {
    if (!this.data.privacyChecked) return;
    prefs.setPrivacyAccepted(true);
    const app = getApp();
    if (app && app.globalData) app.globalData.privacyAccepted = true;
    syncTabBar(true);
    this.setData({ privacyAccepted: true });
  };
}

module.exports = {
  privacyLabels,
  applyPrivacyState,
  bindPrivacyHandlers,
  syncTabBar,
};
