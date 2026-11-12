/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Native privacy / terms reader (no business-domain web-view).
 */

const { getLegalDoc } = require('../../utils/legalDocs');

Page({
  data: {
    title: '',
    meta: '',
    blocks: [],
  },

  onLoad(query) {
    let docId = '';
    try {
      docId = decodeURIComponent((query && query.doc) || '');
    } catch (e) {
      docId = '';
    }
    const doc = getLegalDoc(docId);
    if (!doc) {
      wx.showToast({ title: '文档不存在', icon: 'none' });
      setTimeout(() => wx.navigateBack({ fail() {} }), 400);
      return;
    }
    wx.setNavigationBarTitle({ title: doc.title });
    this.setData({
      title: doc.title,
      meta: doc.meta,
      blocks: doc.blocks,
    });
  },
});
