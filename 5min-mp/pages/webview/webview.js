/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Host-allowlisted https web-view (e.g. about); privacy/terms use pages/legal.
 */

const { t } = require('../../utils/i18n');
const { isAllowedHttps } = require('../../utils/openUrl');

Page({
  data: { url: '' },

  onLoad(query) {
    let url = '';
    try {
      url = decodeURIComponent((query && query.url) || '');
    } catch (e) {
      url = '';
    }
    if (!isAllowedHttps(url)) {
      wx.showToast({ title: t('invalidLink'), icon: 'none' });
      setTimeout(() => wx.navigateBack({ fail() {} }), 400);
      return;
    }
    this.setData({ url });
  },
});
