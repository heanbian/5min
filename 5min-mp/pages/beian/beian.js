/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('../../utils/i18n');

Page({
  data: {
    icp: '',
  },

  onShow() {
    this.setData({
      icp: t('beianIcp'),
    });
    wx.setNavigationBarTitle({ title: t('beianTitle') });
  },
});
