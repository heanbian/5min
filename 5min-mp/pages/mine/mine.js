/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const {
  t,
  getLocale,
  setLocale,
  appLocaleCodes,
  nativeName,
} = require('../../utils/i18n');
const prefs = require('../../utils/prefs');
const { DEFAULT_MIN } = require('../../utils/catalog');
const { setAmbientMode, getAmbientMode, initAmbient } = require('../../utils/ambient');
const { openHttps } = require('../../utils/openUrl');
const { readNavMetrics } = require('../../utils/navMetrics');
const {
  applyPrivacyState,
  bindPrivacyHandlers,
} = require('../../utils/privacyUi');
const { updateTabBarLabels } = require('../../utils/tabBar');

const SOUND_IDS = ['off', 'rain', 'waves', 'clock'];
const QUICK_MINS = [3, 5, 10, 15, 25];

function ambientKeyOf(id) {
  if (id === 'rain') return 'ambientRain';
  if (id === 'waves') return 'ambientWaves';
  if (id === 'clock') return 'ambientClock';
  return 'ambientOff';
}

Page({
  data: {
    navBarHeight: 44,
    navPadTop: 44,
    tabTitle: '',
    mineSectionPrefs: '',
    mineSectionSupport: '',
    langLabel: '',
    ambientLabel: '',
    durationSettingsLabel: '',
    feedbackLabel: '',
    privacyLink: '',
    termsLink: '',
    aboutLabel: '',
    beianEntry: '',
    locale: 'zh-CN',
    localeName: '',
    ambient: 'off',
    ambientName: '',
    customMin: 5,
    customUnit: '',
    dialog: '',
    dialogTitle: '',
    localeOptions: [],
    soundOptions: [],
    quickMins: QUICK_MINS,
    customText: '5',
    customMinutesHint: '',
    cancelLabel: '',
    confirmLabel: '',
    privacyAccepted: true,
    privacyChecked: false,
    privacyTitle: '',
    privacyMessage: '',
    privacyCheckLabel: '',
    privacyAgree: '',
  },

  onLoad() {
    bindPrivacyHandlers(this);
    initAmbient();
    this.setData(readNavMetrics());
  },

  onShow() {
    applyPrivacyState(this);
    this.refresh();
  },

  noop() {},

  refresh() {
    const locale = getLocale();
    const ambient = getAmbientMode() || prefs.getAmbient() || 'off';
    const customMin = prefs.getCustomMin(DEFAULT_MIN);
    this.setData({
      tabTitle: t('tabMine'),
      mineSectionPrefs: t('mineSectionPrefs'),
      mineSectionSupport: t('mineSectionSupport'),
      langLabel: t('langLabel'),
      ambientLabel: t('ambientLabel'),
      durationSettingsLabel: t('durationSettingsLabel'),
      feedbackLabel: t('feedbackLabel'),
      privacyLink: t('privacyLink'),
      termsLink: t('termsLink'),
      aboutLabel: t('aboutLabel'),
      beianEntry: t('beianEntry'),
      locale,
      localeName: nativeName(locale),
      ambient,
      ambientName: t(ambientKeyOf(ambient)),
      customMin,
      customUnit: t('customUnit'),
      customText: String(customMin),
      customMinutesHint: t('customMinutesHint'),
      cancelLabel: t('cancelLabel'),
      confirmLabel: t('confirmLabel'),
      localeOptions: appLocaleCodes().map((code) => ({
        code,
        label: nativeName(code),
      })),
      soundOptions: SOUND_IDS.map((id) => ({
        id,
        label: t(ambientKeyOf(id)),
      })),
    });
  },

  onCloseDialog() {
    this.setData({ dialog: '' });
  },

  onOpenLang() {
    this.setData({
      dialog: 'lang',
      dialogTitle: t('langLabel'),
      localeOptions: appLocaleCodes().map((code) => ({
        code,
        label: nativeName(code),
      })),
    });
  },

  onOpenSound() {
    this.setData({
      dialog: 'sound',
      dialogTitle: t('ambientLabel'),
      soundOptions: SOUND_IDS.map((id) => ({
        id,
        label: t(ambientKeyOf(id)),
      })),
    });
  },

  onOpenDuration() {
    this.setData({
      dialog: 'duration',
      dialogTitle: t('durationSettingsLabel'),
      customText: String(this.data.customMin),
    });
  },

  onOpenAbout() {
    openHttps('https://5min.chat/about.html');
  },

  onPickLocale(e) {
    const code = e.currentTarget.dataset.code;
    setLocale(code);
    updateTabBarLabels();
    this.setData({ dialog: '' });
    this.refresh();
  },

  onPickAmbient(e) {
    const id = e.currentTarget.dataset.id;
    setAmbientMode(id);
    prefs.setAmbient(id);
    this.setData({ dialog: '' });
    this.refresh();
  },

  onCustomInput(e) {
    const digits = String(e.detail.value || '').replace(/\D/g, '').slice(0, 3);
    this.setData({ customText: digits });
  },

  onQuickMin(e) {
    const min = Number(e.currentTarget.dataset.min);
    this.applyMinutes(min);
  },

  onApplyDuration() {
    const n = parseInt(this.data.customText, 10);
    this.applyMinutes(Number.isFinite(n) ? n : this.data.customMin);
  },

  applyMinutes(raw) {
    const n = prefs.setCustomMin(raw);
    const app = getApp();
    if (app && app.globalData) app.globalData.pendingCustomMin = n;
    this.setData({ dialog: '', customMin: n, customText: String(n) });
    wx.showToast({ title: t('customApplied'), icon: 'none' });
  },

  onFeedback() {
    openHttps('https://5min.chat/about.html');
  },

  onOpenBeian() {
    wx.navigateTo({ url: '/pages/beian/beian' });
  },
});
