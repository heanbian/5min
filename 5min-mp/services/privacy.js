/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Privacy session — single source of truth for consent + routing.
 * Consent lives on a non-tabBar boot page so taps are never under native tabBar.
 */

const prefs = require('../utils/prefs');

const BOOT_URL = '/pages/boot/boot';
const HOME_TAB = '/pages/index/index';

function isAccepted() {
  return prefs.isPrivacyAccepted();
}

function accept() {
  prefs.setPrivacyAccepted(true);
  const app = getApp();
  if (app && app.globalData) app.globalData.privacyAccepted = true;
}

function syncGlobal() {
  const app = getApp();
  if (app && app.globalData) {
    app.globalData.privacyAccepted = isAccepted();
  }
  return isAccepted();
}

/** After consent: enter main tab. */
function enterApp() {
  syncGlobal();
  wx.switchTab({ url: HOME_TAB });
}

/** Tab pages call this; redirects to boot when not consented. */
function ensureAcceptedOrBoot() {
  if (isAccepted()) return true;
  wx.reLaunch({ url: BOOT_URL });
  return false;
}

/** Boot page: skip consent UI when already accepted. */
function bootOrEnter() {
  syncGlobal();
  if (isAccepted()) {
    wx.switchTab({ url: HOME_TAB });
    return true;
  }
  return false;
}

module.exports = {
  BOOT_URL,
  HOME_TAB,
  isAccepted,
  accept,
  syncGlobal,
  enterApp,
  ensureAcceptedOrBoot,
  bootOrEnter,
};
