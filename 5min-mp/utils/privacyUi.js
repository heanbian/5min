/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Compatibility shim. Prefer services/privacy + behaviors/privacyGuard +
 * pages/boot + components/consent-card.
 */

const privacy = require('../services/privacy');
const { t } = require('./i18n');
const { openLegal } = require('./legalDocs');
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
    if (accepted) {
      wx.showTabBar({ animation: false });
      updateTabBarLabels();
    } else {
      wx.hideTabBar({ animation: false });
    }
  } catch (e) {
    /* ignore */
  }
}

function applyPrivacyState(page) {
  const accepted = privacy.syncGlobal();
  if (!accepted) {
    privacy.ensureAcceptedOrBoot();
    return;
  }
  syncTabBar(true);
  page.setData({ privacyAccepted: true, ...privacyLabels() });
}

function privacyHandlers(options) {
  const opts = options || {};
  return {
    onPrivacyGateAccepted() {
      this.setData({ privacyAccepted: true, privacyChecked: false });
      if (typeof opts.onAccepted === 'function') {
        try {
          opts.onAccepted.call(this);
        } catch (e) {
          /* ignore */
        }
      }
    },
    onPrivacyCheckChange(e) {
      const values = (e && e.detail && e.detail.value) || [];
      this.setData({ privacyChecked: values.indexOf('agree') >= 0 });
    },
    onTogglePrivacyCheck() {
      this.setData({ privacyChecked: !this.data.privacyChecked });
    },
    onOpenPrivacy() {
      openLegal('privacy');
    },
    onOpenTerms() {
      openLegal('terms');
    },
    onAcceptPrivacy() {
      if (!this.data.privacyChecked) return;
      privacy.accept();
      syncTabBar(true);
      this.setData({ privacyAccepted: true, privacyChecked: false });
      if (typeof opts.onAccepted === 'function') {
        try {
          opts.onAccepted.call(this);
        } catch (e) {
          /* ignore */
        }
      }
    },
  };
}

function bindPrivacyHandlers(page) {
  const handlers = privacyHandlers();
  Object.keys(handlers).forEach((key) => {
    page[key] = handlers[key];
  });
}

module.exports = {
  privacyLabels,
  applyPrivacyState,
  privacyHandlers,
  bindPrivacyHandlers,
  syncTabBar,
};
