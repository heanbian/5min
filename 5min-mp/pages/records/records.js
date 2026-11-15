/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('../../utils/i18n');
const history = require('../../utils/history');
const { resolveSceneTitle } = require('../../utils/catalog');
const prefs = require('../../utils/prefs');
const { readNavMetrics } = require('../../utils/navMetrics');
const {
  applyPrivacyState,
  bindPrivacyHandlers,
} = require('../../utils/privacyUi');
const { updateTabBarLabels } = require('../../utils/tabBar');

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatDateTime(at) {
  const d = new Date(at);
  return (
    `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`
  );
}

Page({
  data: {
    navBarHeight: 44,
    navPadTop: 44,
    tabTitle: '',
    weekStatsLabel: '',
    weekStatsCountLabel: '',
    weekStatsMinsLabel: '',
    customUnit: '',
    historyLabel: '',
    historyEmpty: '',
    historyFilterLabel: '',
    historyFilterAll: '',
    historyDelete: '',
    historyClear: '',
    filterLabel: '',
    filterOptions: [],
    filterIndex: 0,
    filterSceneId: '',
    periodCount: 0,
    periodMins: 0,
    rows: [],
    privacyAccepted: true,
    privacyChecked: false,
    privacyTitle: '',
    privacyMessage: '',
    privacyCheckLabel: '',
    privacyLink: '',
    termsLink: '',
    privacyAgree: '',
  },

  onLoad() {
    bindPrivacyHandlers(this);
    this.setData(readNavMetrics());
  },

  onShow() {
    applyPrivacyState(this);
    updateTabBarLabels();
    this.reload();
  },

  buildFilterOptions() {
    const all = history.getHistory();
    const seen = {};
    const opts = [{ id: '', label: t('historyFilterAll') }];
    for (let i = 0; i < all.length; i += 1) {
      const sid = all[i].sceneId;
      if (!sid || seen[sid]) continue;
      seen[sid] = true;
      let label = t('historySceneDefault');
      const title = resolveSceneTitle(sid);
      if (title) label = title;
      const custom = prefs.getCustomScenes().find((s) => s.id === sid);
      if (custom) label = custom.name;
      opts.push({ id: sid, label });
    }
    return opts;
  },

  filterLabelFor(sceneId, options) {
    const opts = options || this.data.filterOptions;
    const found = opts.find((o) => o.id === sceneId);
    return found ? found.label : t('historyFilterAll');
  },

  reload() {
    const filterOptions = this.buildFilterOptions();
    const filterSceneId = this.data.filterSceneId || '';
    const list = history.getHistory(filterSceneId || undefined);
    const period = history.periodStats();
    const rows = list.map((item, i) => {
      let scene = t('historySceneDefault');
      if (item.sceneId) {
        const title = resolveSceneTitle(item.sceneId);
        if (title) scene = title;
        const custom = prefs.getCustomScenes().find((s) => s.id === item.sceneId);
        if (custom) scene = custom.name;
      }
      return {
        key: `${item.id}-${item.at}-${i}`,
        id: item.id,
        sceneLine: t('historySceneLine', { scene }),
        durationLine: t('historyDurationLine', { n: item.minutes }),
        timeLine: t('historyTimeLine', { time: formatDateTime(item.at) }),
      };
    });
    let filterIndex = filterOptions.findIndex((o) => o.id === filterSceneId);
    if (filterIndex < 0) filterIndex = 0;
    this.setData({
      tabTitle: t('tabRecords'),
      weekStatsLabel: t('weekStatsLabel'),
      weekStatsCountLabel: t('weekStatsCountLabel'),
      weekStatsMinsLabel: t('weekStatsMinsLabel'),
      customUnit: t('customUnit'),
      historyLabel: t('historyLabel'),
      historyEmpty: t('historyEmpty'),
      historyFilterLabel: t('historyFilterLabel'),
      historyFilterAll: t('historyFilterAll'),
      historyDelete: t('historyDelete'),
      historyClear: t('historyClear'),
      filterOptions,
      filterIndex,
      filterLabel: this.filterLabelFor(filterSceneId, filterOptions),
      periodCount: period.count,
      periodMins: period.minutes,
      rows,
    });
  },

  onFilterChange(e) {
    const idx = Number(e.detail.value) || 0;
    const opt = this.data.filterOptions[idx];
    if (!opt) return;
    this.setData({ filterSceneId: opt.id, filterIndex: idx });
    this.reload();
  },

  onDeleteRow(e) {
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    wx.showModal({
      title: t('historyDelete'),
      content: t('historyDeleteConfirm'),
      confirmText: t('historyDelete'),
      cancelText: t('cancelLabel'),
      confirmColor: '#d2554a',
      success: (res) => {
        if (!res.confirm) return;
        history.deleteSession(id);
        this.reload();
      },
    });
  },

  onClearHistory() {
    wx.showModal({
      title: t('historyClear'),
      content: t('historyClearConfirm'),
      confirmText: t('historyClear'),
      cancelText: t('cancelLabel'),
      confirmColor: '#d2554a',
      success: (res) => {
        if (!res.confirm) return;
        history.clearHistory();
        this.reload();
      },
    });
  },
});