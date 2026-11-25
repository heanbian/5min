/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('../../utils/i18n');
const history = require('../../utils/history');
const { getStreak } = require('../../utils/streak');
const { resolveSceneTitle } = require('../../utils/catalog');
const prefs = require('../../utils/prefs');
const p0 = require('../../utils/p0Features');
const privacyGuard = require('../../behaviors/privacyGuard');
const navChrome = require('../../behaviors/navChrome');

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
  behaviors: [privacyGuard, navChrome],
  data: {
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
    overtimeInsightTitle: '',
    overtimeInsightLine: '',
    overtimeInsightHint: '',
    showOvertimeInsight: true,
    streakLabel: '',
    streakText: '',
    shareLabel: '',
    shareCopyLabel: '',
    exportLabel: '',
    rows: [],
  },

  noop() {},

  onShow() {
    if (!this.guardPrivacy()) return;
    this.reload();
  },

  buildFilterOptions(all) {
    const list = all || history.getHistory();
    const seen = {};
    const opts = [{ id: '', label: t('historyFilterAll') }];
    for (let i = 0; i < list.length; i += 1) {
      const sid = list[i].sceneId;
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
    const all = history.getHistory();
    const filterOptions = this.buildFilterOptions(all);
    let filterSceneId = this.data.filterSceneId || '';
    if (filterSceneId && !filterOptions.some((o) => o.id === filterSceneId)) {
      filterSceneId = '';
    }
    const list = filterSceneId
      ? all.filter((row) => row.sceneId === filterSceneId)
      : all;
    let periodMins = 0;
    for (let i = 0; i < all.length; i += 1) periodMins += all[i].minutes;
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
    const ot = p0.readOvertimeStats();
    const showInsight = p0.getShowOvertimeInsight();
    let overtimeInsightLine = t('overtimeInsightEmpty');
    if (ot.count > 0) {
      overtimeInsightLine = t('overtimeInsightLine', {
        count: ot.count,
        mins: p0.insightMinutes(ot.ms),
      });
    }
    const streak = getStreak(all);
    const streakText =
      streak > 0 ? t('streakDays', { n: streak }) : t('streakNone');
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
      filterSceneId,
      filterLabel: this.filterLabelFor(filterSceneId, filterOptions),
      periodCount: all.length,
      periodMins,
      overtimeInsightTitle: t('overtimeInsightTitle'),
      overtimeInsightLine,
      overtimeInsightHint:
        ot.count > 0 ? t('overtimeInsightTip') : t('overtimeInsightHint'),
      showOvertimeInsight: showInsight,
      streakLabel: t('streakLabel'),
      streakText,
      shareLabel: t('shareLabel'),
      shareCopyLabel: t('shareCopyAction'),
      exportLabel: t('exportLabel'),
      rows,
    });
  },

  sceneLabelForRow(row) {
    let scene = t('historySceneDefault');
    if (row && row.sceneId) {
      const title = resolveSceneTitle(row.sceneId);
      if (title) scene = title;
      const custom = prefs.getCustomScenes().find((s) => s.id === row.sceneId);
      if (custom) scene = custom.name;
    }
    return scene;
  },

  buildExportCsv() {
    return history.exportHistoryCsv(
      (row) => this.sceneLabelForRow(row),
      t('exportCsvHeader'),
    );
  },

  copyCsvFallback(csv) {
    wx.setClipboardData({
      data: csv,
      success: () => {
        wx.showToast({ title: t('exportDone'), icon: 'none' });
      },
      fail: () => {
        wx.showToast({ title: t('exportFailed'), icon: 'none' });
      },
    });
  },

  onExportCsv() {
    const csv = this.buildExportCsv();
    const fs = wx.getFileSystemManager();
    const path = `${wx.env.USER_DATA_PATH}/5min-history.csv`;
    try {
      fs.writeFileSync(path, csv, 'utf8');
    } catch (e) {
      this.copyCsvFallback(csv);
      return;
    }
    if (typeof wx.shareFileMessage === 'function') {
      wx.shareFileMessage({
        filePath: path,
        fileName: '5min-history.csv',
        success: () => {
          wx.showToast({ title: t('exportDone'), icon: 'none' });
        },
        fail: () => {
          if (typeof wx.openDocument === 'function') {
            wx.openDocument({
              filePath: path,
              fileType: 'csv',
              showMenu: true,
              success: () => {
                wx.showToast({ title: t('exportDone'), icon: 'none' });
              },
              fail: () => this.copyCsvFallback(csv),
            });
            return;
          }
          this.copyCsvFallback(csv);
        },
      });
      return;
    }
    if (typeof wx.openDocument === 'function') {
      wx.openDocument({
        filePath: path,
        fileType: 'csv',
        showMenu: true,
        success: () => {
          wx.showToast({ title: t('exportDone'), icon: 'none' });
        },
        fail: () => this.copyCsvFallback(csv),
      });
      return;
    }
    this.copyCsvFallback(csv);
  },

  buildShareText() {
    const summary = history.shareSummaryValues();
    return t('shareText', {
      count: summary.count,
      mins: summary.minutes,
      streak: summary.streak,
    });
  },

  onShareAppMessage() {
    const summary = history.shareSummaryValues();
    const title =
      summary.streak > 0
        ? `${t('brandTitle')} · ${t('streakDays', { n: summary.streak })}`
        : t('brandTitle');
    return {
      title,
      path: '/pages/index/index',
    };
  },

  onCopyShare() {
    const text = this.buildShareText();
    wx.setClipboardData({
      data: text,
      success: () => {
        wx.showToast({
          title: t('shareCopied'),
          icon: 'none',
        });
      },
      fail: () => {
        wx.showToast({
          title: t('shareFailed'),
          icon: 'none',
        });
      },
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
