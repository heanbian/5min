/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t } = require('../../utils/i18n');
const history = require('../../utils/history');
const { sceneById } = require('../../utils/catalog');
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

  reload() {
    const list = history.getHistory();
    const period = history.periodStats();
    const rows = list.map((item, i) => {
      let scene = t('historySceneDefault');
      if (item.sceneId) {
        const found = sceneById(item.sceneId);
        if (found) scene = t(found.titleKey);
      }
      return {
        key: `${item.at}-${item.minutes}-${item.sceneId}-${i}`,
        sceneLine: t('historySceneLine', { scene }),
        durationLine: t('historyDurationLine', { n: item.minutes }),
        timeLine: t('historyTimeLine', { time: formatDateTime(item.at) }),
      };
    });
    this.setData({
      tabTitle: t('tabRecords'),
      weekStatsLabel: t('weekStatsLabel'),
      weekStatsCountLabel: t('weekStatsCountLabel'),
      weekStatsMinsLabel: t('weekStatsMinsLabel'),
      customUnit: t('customUnit'),
      historyLabel: t('historyLabel'),
      historyEmpty: t('historyEmpty'),
      periodCount: period.count,
      periodMins: period.minutes,
      rows,
    });
  },
});
