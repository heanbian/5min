/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * https-only web-view for privacy / terms / feedback.
 */

Page({
  data: { url: '' },

  onLoad(query) {
    let url = '';
    try {
      url = decodeURIComponent((query && query.url) || '');
    } catch (e) {
      url = '';
    }
    if (url.indexOf('https://') !== 0) {
      wx.showToast({ title: '无效链接', icon: 'none' });
      setTimeout(() => wx.navigateBack({ fail() {} }), 400);
      return;
    }
    this.setData({ url });
  },
});
