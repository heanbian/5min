/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('./i18n');

function updateTabBarLabels() {
  try {
    wx.setTabBarItem({ index: 0, text: t('tabRecords') });
    wx.setTabBarItem({ index: 1, text: t('tabHome') });
    wx.setTabBarItem({ index: 2, text: t('tabMine') });
  } catch (e) {
    /* ignore before tabBar ready */
  }
}

module.exports = { updateTabBarLabels };
