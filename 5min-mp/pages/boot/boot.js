/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Launch + privacy consent. All controls are plain views bound on this Page.
 */

const privacy = require('../../services/privacy');
const { t } = require('../../utils/i18n');
const { openLegal } = require('../../utils/legalDocs');

Page({
  data: {
    ready: false,
    agreed: false,
    brandTitle: '5min',
    privacyTitle: '',
    privacyMessage: '',
    privacyCheckLabel: '',
    privacyLink: '',
    termsLink: '',
    privacyAgree: '',
    privacyFooter: '',
  },

  onLoad() {
    if (privacy.bootOrEnter()) return;
    this.setData({
      ready: true,
      agreed: false,
      brandTitle: t('brandTitle') || '5min',
      privacyTitle: t('privacyTitle'),
      privacyMessage: t('privacyMessage'),
      privacyCheckLabel: t('privacyCheckLabel'),
      privacyLink: t('privacyLink'),
      termsLink: t('termsLink'),
      privacyAgree: t('privacyAgree'),
      privacyFooter: t('privacyFooter'),
    });
  },

  onShow() {
    if (this.data.ready) return;
    if (privacy.isAccepted()) privacy.enterApp();
  },

  onToggleAgree() {
    this.setData({ agreed: !this.data.agreed });
  },

  onOpenPrivacy() {
    openLegal('privacy');
  },

  onOpenTerms() {
    openLegal('terms');
  },

  onAccept() {
    if (!this.data.agreed) {
      wx.showToast({ title: t('privacyCheckLabel'), icon: 'none' });
      return;
    }
    privacy.accept();
    privacy.enterApp();
  },
});
