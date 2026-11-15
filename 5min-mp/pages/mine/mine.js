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
const p0 = require('../../utils/p0Features');
const cloudSync = require('../../utils/cloudSync');
const { DEFAULT_MIN } = require('../../utils/catalog');
const { setAmbientMode, getAmbientMode, initAmbient } = require('../../utils/ambient');
const { openHttps } = require('../../utils/openUrl');
const { readNavMetrics } = require('../../utils/navMetrics');
const {
  applyPrivacyState,
  bindPrivacyHandlers,
} = require('../../utils/privacyUi');
const { updateTabBarLabels } = require('../../utils/tabBar');

function ritualLabel(mode) {
  return mode === p0.RITUAL_BASIC ? t('standRitualBasic') : t('standRitualOff');
}

function alertProfileLabel(mode) {
  if (mode === p0.PROFILE_QUIET) return t('alertProfileQuiet');
  if (mode === p0.PROFILE_SILENT) return t('alertProfileSilent');
  return t('alertProfileNormal');
}

const SOUND_IDS = ['off', 'rain', 'waves', 'clock'];
const QUICK_MINS = [3, 5, 10, 15, 25];

function ambientKeyOf(id) {
  if (id === 'rain') return 'ambientRain';
  if (id === 'waves') return 'ambientWaves';
  if (id === 'clock') return 'ambientClock';
  return 'ambientOff';
}

function sceneRowsFromPrefs() {
  const unit = t('customUnit');
  return prefs.getCustomScenes().map((s) => ({
    id: s.id,
    name: s.name,
    min: s.min,
    minLabel: `${s.min} ${unit}`,
  }));
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
    customScenesLabel: '',
    customScenesValue: '',
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
    sceneRows: [],
    canAddScene: true,
    customScenesEmptyHint: '',
    customSceneAdd: '',
    customSceneUse: '',
    customSceneNameLabel: '',
    customSceneNamePlaceholder: '',
    customMinutesLabel: '',
    editorName: '',
    editorMinutes: '5',
    editorSceneId: '',
    editorConfirmDisabled: true,
    quickMins: QUICK_MINS,
    cancelLabel: '',
    confirmLabel: '',
    feedbackHint: '',
    feedbackEmail: '',
    copyEmailLabel: '',
    privacyAccepted: true,
    privacyChecked: false,
    privacyTitle: '',
    privacyMessage: '',
    privacyCheckLabel: '',
    privacyAgree: '',
    prefAlertsSection: '',
    prefFinishTone: '',
    prefFinishVibrate: '',
    prefFinishNotify: '',
    finishTone: true,
    finishVibrate: true,
    finishNotify: true,
    standRitualSection: '',
    standRitualLabel: '',
    standRitualName: '',
    standRitual: p0.RITUAL_BASIC,
    ritualOptions: [],
    alertProfileLabel: '',
    alertProfileName: '',
    alertProfile: p0.PROFILE_NORMAL,
    alertProfileHint: '',
    alertProfileOptions: [],
    storageSection: '',
    storageModeLabel: '',
    storageMode: 'local',
    storageModeName: '',
    storageModeHint: '',
    storageSyncStatus: '',
    storageOptions: [],
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
    const scenes = prefs.getCustomScenes();
    const customScenesValue =
      scenes.length <= 0
        ? t('customScenesEmpty')
        : t('customScenesCount', { n: scenes.length });
    this.setData({
      tabTitle: t('tabMine'),
      mineSectionPrefs: t('mineSectionPrefs'),
      mineSectionSupport: t('mineSectionSupport'),
      langLabel: t('langLabel'),
      ambientLabel: t('ambientLabel'),
      customScenesLabel: t('customScenesLabel'),
      customScenesValue,
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
      cancelLabel: t('cancelLabel'),
      confirmLabel: t('confirmLabel'),
      customScenesEmptyHint: t('customScenesEmptyHint'),
      customSceneAdd: t('customSceneAdd'),
      customSceneUse: t('customSceneUse'),
      customSceneNameLabel: t('customSceneNameLabel'),
      customSceneNamePlaceholder: t('customSceneNamePlaceholder'),
      customMinutesLabel: t('customMinutesLabel'),
      prefAlertsSection: t('prefAlertsSection'),
      prefFinishTone: t('prefFinishTone'),
      prefFinishVibrate: t('prefFinishVibrate'),
      prefFinishNotify: t('prefFinishNotify'),
      finishTone: prefs.getFinishTone(),
      finishVibrate: prefs.getFinishVibrate(),
      finishNotify: prefs.getFinishNotify(),
      standRitualSection: t('standRitualSection'),
      standRitualLabel: t('standRitualLabel'),
      standRitual: p0.getStandRitual(),
      standRitualName: ritualLabel(p0.getStandRitual()),
      alertProfileLabel: t('alertProfileLabel'),
      alertProfile: p0.getAlertProfile(),
      alertProfileName: alertProfileLabel(p0.getAlertProfile()),
      alertProfileHint: t('alertProfileHint'),
      storageSection: t('storageSection'),
      storageModeLabel: t('storageModeLabel'),
      storageMode: prefs.getStorageMode(),
      storageModeName:
        prefs.getStorageMode() === 'cloud'
          ? t('storageModeCloud')
          : t('storageModeLocal'),
      storageModeHint: t('storageModeHint'),
      storageOptions: [
        { id: 'local', label: t('storageModeLocal') },
        { id: 'cloud', label: t('storageModeCloud') },
      ],
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

  onOpenStorage() {
    this.setData({
      dialog: 'storage',
      dialogTitle: t('storageModeLabel'),
      storageOptions: [
        { id: 'local', label: t('storageModeLocal') },
        { id: 'cloud', label: t('storageModeCloud') },
      ],
    });
  },

  onPickStorage(e) {
    const id = e.currentTarget.dataset.id;
    if (id === 'cloud') {
      wx.showModal({
        title: t('storageModeCloud'),
        content: t('storageCloudConfirm'),
        confirmText: t('confirmLabel'),
        cancelText: t('cancelLabel'),
        success: (res) => {
          if (!res.confirm) return;
          this.applyStorageMode('cloud');
        },
      });
      return;
    }
    this.applyStorageMode('local');
  },

  applyStorageMode(mode) {
    this.setData({ dialog: '', storageSyncStatus: '' });
    if (mode === 'cloud') {
      this.setData({ storageSyncStatus: t('storageSyncing') });
      cloudSync
        .enableCloud()
        .then(() => {
          this.setData({ storageSyncStatus: t('storageSyncOk') });
          updateTabBarLabels();
          this.refresh();
        })
        .catch(() => {
          prefs.setStorageMode('local');
          this.setData({ storageSyncStatus: t('storageSyncFail') });
          this.refresh();
        });
      return;
    }
    cloudSync.disableCloud();
    this.refresh();
  },

  onCloseDialog() {
    if (this.data.dialog === 'sceneEditor') {
      this.onCloseSceneEditor();
      return;
    }
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

  onOpenCustomScenes() {
    const scenes = prefs.getCustomScenes();
    this.setData({
      dialog: 'scenes',
      dialogTitle: t('customScenesLabel'),
      sceneRows: sceneRowsFromPrefs(),
      canAddScene: scenes.length < prefs.MAX_COUNT,
      customScenesEmptyHint: t('customScenesEmptyHint'),
      customSceneAdd: t('customSceneAdd'),
      customSceneUse: t('customSceneUse'),
    });
  },

  onAddScene() {
    if (prefs.getCustomScenes().length >= prefs.MAX_COUNT) return;
    const customMin = prefs.getCustomMin(DEFAULT_MIN);
    this.setData({
      dialog: 'sceneEditor',
      dialogTitle: t('customSceneAdd'),
      editorSceneId: '',
      editorName: '',
      editorMinutes: String(customMin),
      editorConfirmDisabled: true,
      customSceneNameLabel: t('customSceneNameLabel'),
      customSceneNamePlaceholder: t('customSceneNamePlaceholder'),
      customMinutesLabel: t('customMinutesLabel'),
    });
  },

  onEditScene(e) {
    const id = e.currentTarget.dataset.id;
    const scene = prefs.getCustomScenes().find((s) => s.id === id);
    if (!scene) return;
    this.setData({
      dialog: 'sceneEditor',
      dialogTitle: t('customSceneEdit'),
      editorSceneId: scene.id,
      editorName: scene.name,
      editorMinutes: String(scene.min),
      editorConfirmDisabled: !prefs.normalizeName(scene.name),
      customSceneNameLabel: t('customSceneNameLabel'),
      customSceneNamePlaceholder: t('customSceneNamePlaceholder'),
      customMinutesLabel: t('customMinutesLabel'),
    });
  },

  onUseScene(e) {
    const id = e.currentTarget.dataset.id;
    if (!prefs.getCustomScenes().some((s) => s.id === id)) return;
    const app = getApp();
    if (app && app.globalData) app.globalData.pendingSceneId = id;
    this.setData({ dialog: '' });
    wx.switchTab({ url: '/pages/index/index' });
  },

  onDeleteScene(e) {
    const id = e.currentTarget.dataset.id;
    const next = prefs.getCustomScenes().filter((s) => s.id !== id);
    prefs.setCustomScenes(next);
    const app = getApp();
    if (app && app.globalData && app.globalData.pendingSceneId === id) {
      app.globalData.pendingSceneId = null;
    }
    this.setData({
      sceneRows: sceneRowsFromPrefs(),
      canAddScene: next.length < prefs.MAX_COUNT,
    });
    this.refresh();
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onEditorNameInput(e) {
    const editorName = String(e.detail.value || '').slice(0, prefs.MAX_NAME);
    this.setData({
      editorName,
      editorConfirmDisabled: !prefs.normalizeName(editorName),
    });
  },

  onEditorMinutesInput(e) {
    const digits = String(e.detail.value || '').replace(/\D/g, '').slice(0, 3);
    this.setData({ editorMinutes: digits });
  },

  onNudgeMinutes(e) {
    const delta = Number(e.currentTarget.dataset.delta) || 0;
    const cur = parseInt(this.data.editorMinutes, 10);
    const base = Number.isFinite(cur) ? cur : prefs.getCustomMin(DEFAULT_MIN);
    this.setData({
      editorMinutes: String(prefs.clampMinutes(base + delta)),
    });
  },

  onQuickMin(e) {
    const min = Number(e.currentTarget.dataset.min);
    this.setData({ editorMinutes: String(prefs.clampMinutes(min)) });
  },

  onConfirmSceneEditor() {
    const name = prefs.normalizeName(this.data.editorName);
    if (!name) return;
    const parsed = parseInt(this.data.editorMinutes, 10);
    const minutes = prefs.clampMinutes(
      Number.isFinite(parsed) ? parsed : prefs.getCustomMin(DEFAULT_MIN)
    );
    const editingId = this.data.editorSceneId;
    let list = prefs.getCustomScenes().slice();
    let saved = null;
    if (editingId) {
      const idx = list.findIndex((s) => s.id === editingId);
      if (idx < 0) return;
      list[idx] = { id: editingId, name, min: minutes };
      saved = list[idx];
    } else {
      if (list.length >= prefs.MAX_COUNT) return;
      saved = { id: prefs.makeId(), name, min: minutes };
      list.unshift(saved);
    }
    prefs.setCustomScenes(list);
    prefs.setCustomMin(minutes);
    if (!editingId) {
      const app = getApp();
      if (app && app.globalData) app.globalData.pendingSceneId = saved.id;
    }
    this.setData({
      dialog: 'scenes',
      dialogTitle: t('customScenesLabel'),
      sceneRows: sceneRowsFromPrefs(),
      canAddScene: list.length < prefs.MAX_COUNT,
      customMin: minutes,
    });
    this.refresh();
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onCloseSceneEditor() {
    this.setData({
      dialog: 'scenes',
      dialogTitle: t('customScenesLabel'),
      sceneRows: sceneRowsFromPrefs(),
      canAddScene: prefs.getCustomScenes().length < prefs.MAX_COUNT,
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
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onPickAmbient(e) {
    const id = e.currentTarget.dataset.id;
    setAmbientMode(id);
    prefs.setAmbient(id);
    this.setData({ dialog: '' });
    this.refresh();
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onToggleFinishTone(e) {
    const on = !!e.detail.value;
    prefs.setFinishTone(on);
    this.setData({ finishTone: on });
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onToggleFinishVibrate(e) {
    const on = !!e.detail.value;
    prefs.setFinishVibrate(on);
    this.setData({ finishVibrate: on });
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onToggleFinishNotify(e) {
    const on = !!e.detail.value;
    prefs.setFinishNotify(on);
    this.setData({ finishNotify: on });
    cloudSync.pushPrefsOnly().catch(() => {});
  },

  onOpenRitual() {
    this.setData({
      dialog: 'ritual',
      dialogTitle: t('standRitualLabel'),
      ritualOptions: [
        { id: p0.RITUAL_OFF, label: t('standRitualOff') },
        { id: p0.RITUAL_BASIC, label: t('standRitualBasic') },
      ],
    });
  },

  onPickRitual(e) {
    const id = e.currentTarget.dataset.id;
    p0.setStandRitual(id);
    this.setData({ dialog: '' });
    this.refresh();
  },

  onOpenAlertProfile() {
    this.setData({
      dialog: 'alertProfile',
      dialogTitle: t('alertProfileLabel'),
      alertProfileOptions: [
        { id: p0.PROFILE_NORMAL, label: t('alertProfileNormal') },
        { id: p0.PROFILE_QUIET, label: t('alertProfileQuiet') },
        { id: p0.PROFILE_SILENT, label: t('alertProfileSilent') },
      ],
    });
  },

  onPickAlertProfile(e) {
    const id = e.currentTarget.dataset.id;
    p0.setAlertProfile(id);
    this.setData({ dialog: '' });
    this.refresh();
  },

  onFeedback() {
    this.setData({
      dialog: 'feedback',
      dialogTitle: t('feedbackLabel'),
      feedbackHint: t('feedbackBody'),
      feedbackEmail: t('feedbackEmail'),
      copyEmailLabel: t('copyEmailLabel'),
    });
  },

  onCopyFeedbackEmail() {
    const email = this.data.feedbackEmail || t('feedbackEmail');
    wx.setClipboardData({
      data: email,
      success: () => {
        this.setData({ dialog: '' });
        wx.showToast({ title: t('emailCopied'), icon: 'none' });
      },
    });
  },

  onOpenBeian() {
    wx.showModal({
      title: t('beianTitle'),
      content: t('beianIcp'),
      showCancel: false,
      confirmText: t('confirmLabel'),
    });
  },
});
