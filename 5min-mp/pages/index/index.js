/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t, getLocale } = require('../../utils/i18n');
const {
  DEFAULT_MIN,
  ALERT_DURATION_MS,
  sceneById,
  buildScenePicker,
} = require('../../utils/catalog');
const {
  getTodayStats,
  recordCompletedSession,
  statsMinutes,
} = require('../../utils/stats');
const { alertFinish, clearAlerts } = require('../../utils/alert');
const { drawDigitalWatch } = require('../../utils/digitalWatch');
const {
  initAmbient,
  getAmbientMode,
  setAmbientMode,
  pauseAmbient,
} = require('../../utils/ambient');
const prefs = require('../../utils/prefs');
const { readNavMetrics } = require('../../utils/navMetrics');
const {
  applyPrivacyState,
  bindPrivacyHandlers,
} = require('../../utils/privacyUi');
const { updateTabBarLabels } = require('../../utils/tabBar');

const WARN_MS = 60 * 1000;

function pad2(n) {
  return String(n).padStart(2, '0');
}

function formatTime(ms) {
  const totalSec = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  return `${m}:${pad2(s)}`;
}

function visualPhase(remainMs, running, finished) {
  if (finished || remainMs <= 0) return 'done';
  if (remainMs <= WARN_MS) return 'warn';
  if (running) return 'running';
  return 'idle';
}

function phaseColor(phase, kind) {
  if (phase === 'warn') return '#c9862d';
  if (phase === 'done') return '#d2554a';
  if (kind === 'ring') return '#2f9a68';
  return '#1f2a24';
}

Page({
  data: {
    navBarHeight: 44,
    navPadTop: 44,
    navPadRight: 96,
    brandTitle: '',
    stageLabel: '',
    actionsLabel: '',
    ambientLabel: '',
    timeText: formatTime(DEFAULT_MIN * 60 * 1000),
    statusText: '',
    statsText: '',
    primaryLabel: '',
    resetLabel: '',
    canReset: false,
    running: false,
    phase: 'idle',
    sceneTriggerLabel: '',
    scenePlaceholder: false,
    sceneRange: [[], []],
    sceneIndex: [0, 1],
    tabMine: '',
    canvasCss: 260,
    ambient: 'off',
    privacyAccepted: true,
    privacyChecked: false,
    privacyTitle: '',
    privacyMessage: '',
    privacyCheckLabel: '',
    privacyLink: '',
    termsLink: '',
    privacyAgree: '',
  },

  totalMs: DEFAULT_MIN * 60 * 1000,
  remainMs: DEFAULT_MIN * 60 * 1000,
  running: false,
  finished: false,
  finishedHandled: false,
  endAt: 0,
  tickTimer: null,
  activeSceneId: null,
  scenePicker: null,
  canvas: null,
  ctx: null,
  lastLocale: '',

  onLoad() {
    bindPrivacyHandlers(this);
    const acceptPrivacy = this.onAcceptPrivacy.bind(this);
    this.onAcceptPrivacy = () => {
      acceptPrivacy();
      this.reopenCanvasSoon();
    };
    const nav = readNavMetrics();
    const ambient = initAmbient();
    const custom = prefs.getCustomMin(DEFAULT_MIN);
    const toilet = sceneById('toilet');
    // 默认场景：如厕 · 5 分钟；自定义时长与之不同时仅应用时长
    if (toilet && custom === toilet.min) {
      this.setPreset(toilet.min, toilet.id);
    } else {
      this.totalMs = custom * 60 * 1000;
      this.remainMs = this.totalMs;
      this.activeSceneId = null;
    }
    this.setData({
      ...nav,
      ambient,
    });
    this.applyLabels(true);
    this.refreshStats();
    this.refreshUi();
  },

  onReady() {
    if (this.data.privacyAccepted) this.initCanvas();
  },

  reopenCanvasSoon() {
    this.canvas = null;
    this.ctx = null;
    setTimeout(() => this.initCanvas(), 32);
  },

  onShow() {
    applyPrivacyState(this);
    updateTabBarLabels();
    const locale = getLocale();
    if (locale !== this.lastLocale) {
      this.lastLocale = locale;
      this.applyLabels(true);
      this.refreshUi();
    }
    this.setData({ ambient: getAmbientMode() });
    this.consumePendingCustomMin();
    this.refreshStats();
    if (this.running && this.endAt) {
      this.tick();
    }
  },

  onUnload() {
    this.stopTicker();
    clearAlerts();
    pauseAmbient();
    this.setKeepScreenOn(false);
  },

  consumePendingCustomMin() {
    const app = getApp();
    const pending =
      app && app.globalData ? app.globalData.pendingCustomMin : null;
    if (pending == null) return;
    if (this.running) return;
    app.globalData.pendingCustomMin = null;
    this.setPreset(pending, null);
    this.rebuildScenePicker(false);
  },

  rebuildScenePicker(keepSelection) {
    this.scenePicker = buildScenePicker();
    const range0 = this.scenePicker.range.map((g) => ({
      id: g.id,
      label: g.label,
    }));
    let gi = 0;
    let si = 0;
    if (keepSelection && this.activeSceneId) {
      for (let i = 0; i < range0.length; i += 1) {
        const list = this.scenePicker.scenesByGroup[range0[i].id] || [];
        const idx = list.findIndex((s) => s.id === this.activeSceneId);
        if (idx >= 0) {
          gi = i;
          si = idx;
          break;
        }
      }
    }
    const group = range0[gi];
    const range1 = (
      (group && this.scenePicker.scenesByGroup[group.id]) ||
      []
    ).map((s) => ({
      id: s.id,
      label: s.label,
      min: s.min,
      title: s.title,
    }));
    const hasScene = !!this.activeSceneId;
    const selected = hasScene ? range1[si] : null;
    this.setData({
      sceneRange: [range0, range1],
      sceneIndex: [gi, si],
      sceneTriggerLabel: selected
        ? selected.label
        : t('scenePlaceholder'),
      scenePlaceholder: !hasScene,
    });
  },

  applyLabels(rebuildScenes) {
    this.setData({
      stageLabel: t('stageLabel'),
      actionsLabel: t('actionsLabel'),
      ambientLabel: t('ambientLabel'),
      tabMine: t('tabMine'),
    });
    if (rebuildScenes) this.rebuildScenePicker(true);
  },

  initCanvas() {
    const query = this.createSelectorQuery();
    query
      .select('#progressCanvas')
      .fields({ node: true, size: true })
      .exec((res) => {
        const info = res && res[0];
        if (!info || !info.node) return;
        const canvas = info.node;
        const ctx = canvas.getContext('2d');
        const dpr = wx.getWindowInfo
          ? wx.getWindowInfo().pixelRatio
          : wx.getSystemInfoSync().pixelRatio || 1;
        const css = Math.round(info.width || 260);
        canvas.width = css * dpr;
        canvas.height = css * dpr;
        ctx.scale(dpr, dpr);
        this.canvas = canvas;
        this.ctx = ctx;
        this.setData({ canvasCss: css });
        this.drawDial(
          this.totalMs > 0 ? this.remainMs / this.totalMs : 0,
          formatTime(this.remainMs),
          this.data.phase
        );
      });
  },

  drawDial(ratio, timeText, phase) {
    const ctx = this.ctx;
    if (!ctx || !this.canvas) return;
    const size = this.data.canvasCss;
    const progress = Math.max(0, Math.min(1, ratio));
    const stroke = size * (8.5 / 120);
    const inset = stroke / 2;
    const r = size / 2 - inset;
    const cx = size / 2;
    const cy = size / 2;
    const ringColor = phaseColor(phase, 'ring');
    const timeColor = phaseColor(phase, 'time');

    ctx.clearRect(0, 0, size, size);

    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.strokeStyle = '#cfe0d6';
    ctx.lineWidth = stroke;
    ctx.lineCap = 'round';
    ctx.stroke();

    if (progress > 0) {
      ctx.beginPath();
      ctx.arc(
        cx,
        cy,
        r,
        -Math.PI / 2,
        -Math.PI / 2 + progress * Math.PI * 2,
        false
      );
      ctx.strokeStyle = ringColor;
      ctx.lineWidth = stroke;
      ctx.lineCap = 'round';
      ctx.stroke();
    }

    drawDigitalWatch(ctx, size, timeText, timeColor);
  },

  refreshStats() {
    const stats = getTodayStats();
    let statsText = '';
    if (stats.count <= 0) {
      statsText = `${t('dailyStatsLabel')} · ${t('dailyStatsEmpty')}`;
    } else {
      const minutes = statsMinutes(stats.totalMs);
      statsText = `${t('dailyStatsLabel')} · ${stats.count} ${t(
        'dailyStatsCountUnit'
      )} · ${minutes} ${t('dailyStatsMinutesUnit')}`;
    }
    this.setData({ statsText });
  },

  refreshUi() {
    const remain = this.remainMs;
    const running = this.running;
    const finished = this.finished;
    const phase = visualPhase(remain, running, finished);
    const timeText = formatTime(remain);

    let primaryLabel = t('start');
    if (finished && !running) primaryLabel = t('again');
    else if (running) primaryLabel = t('pause');
    else if (remain < this.totalMs && remain > 0) primaryLabel = t('resume');

    let statusText = t('statusIdle');
    if (finished || remain <= 0) statusText = t('statusDone');
    else if (running && remain <= WARN_MS) statusText = t('statusWarn');
    else if (running) statusText = t('statusRunning');
    else if (remain < this.totalMs) statusText = t('statusPaused');

    let brandTitle = t('brandTitle');
    if (this.activeSceneId) {
      const scene = sceneById(this.activeSceneId);
      if (scene) brandTitle = t(scene.titleKey);
    }

    this.setData({
      timeText,
      statusText,
      primaryLabel,
      resetLabel: t('reset'),
      canReset: running || remain < this.totalMs || finished,
      running,
      phase,
      brandTitle,
      scenePlaceholder: !this.activeSceneId,
      ambient: getAmbientMode(),
    });

    this.drawDial(this.totalMs > 0 ? remain / this.totalMs : 0, timeText, phase);
  },

  onOpenMine() {
    wx.switchTab({ url: '/pages/mine/mine' });
  },

  onDialTap() {
    if (!this.finished || this.running) return;
    const vars = {
      n: Math.max(1, Math.round(this.totalMs / 60000)),
      scene: this.notifySceneName(),
    };
    alertFinish({
      title: t('notifyTitle', vars),
      body: t('notifyBody', vars),
      durationMs: ALERT_DURATION_MS,
      withSound: getAmbientMode() !== 'off',
    });
  },

  setKeepScreenOn(on) {
    try {
      wx.setKeepScreenOn({ keepScreenOn: !!on });
    } catch (e) {
      /* ignore */
    }
  },

  stopTicker() {
    if (this.tickTimer) {
      clearInterval(this.tickTimer);
      this.tickTimer = null;
    }
  },

  startTicker() {
    this.stopTicker();
    this.tickTimer = setInterval(() => this.tick(), 200);
  },

  tick() {
    if (!this.running || !this.endAt) return;
    const remain = Math.max(0, this.endAt - Date.now());
    this.remainMs = remain;
    if (remain <= 0) {
      this.onFinished();
      return;
    }
    this.refreshUi();
  },

  onFinished() {
    if (this.finishedHandled) return;
    this.finishedHandled = true;
    this.stopTicker();
    this.running = false;
    this.finished = true;
    this.remainMs = 0;
    this.endAt = 0;
    this.setKeepScreenOn(false);
    recordCompletedSession(this.totalMs, this.activeSceneId || '');
    this.refreshStats();
    this.refreshUi();
    const vars = {
      n: Math.max(1, Math.round(this.totalMs / 60000)),
      scene: this.notifySceneName(),
    };
    alertFinish({
      title: t('notifyTitle', vars),
      body: t('notifyBody', vars),
      durationMs: ALERT_DURATION_MS,
      withSound: getAmbientMode() !== 'off',
    });
  },

  notifySceneName() {
    if (this.activeSceneId) {
      const scene = sceneById(this.activeSceneId);
      if (scene) return t(scene.titleKey);
    }
    return t('sceneToiletTitle');
  },

  setPreset(minutes, sceneId) {
    if (this.running) return;
    clearAlerts();
    this.finishedHandled = false;
    this.finished = false;
    this.totalMs = Math.max(1, minutes) * 60 * 1000;
    this.remainMs = this.totalMs;
    this.activeSceneId = sceneId || null;
    this.refreshUi();
  },

  onSceneColumnChange(e) {
    const { column, value } = e.detail;
    const sceneIndex = this.data.sceneIndex.slice();
    sceneIndex[column] = value;
    if (column === 0) {
      const group = this.data.sceneRange[0][value];
      const list = (
        (group && this.scenePicker.scenesByGroup[group.id]) ||
        []
      ).map((s) => ({
        id: s.id,
        label: s.label,
        min: s.min,
        title: s.title,
      }));
      sceneIndex[1] = 0;
      this.setData({
        sceneIndex,
        sceneRange: [this.data.sceneRange[0], list],
      });
    } else {
      this.setData({ sceneIndex });
    }
  },

  onSceneChange(e) {
    if (this.running) return;
    const [gi, si] = e.detail.value;
    const group = this.data.sceneRange[0][gi];
    const list = (group && this.scenePicker.scenesByGroup[group.id]) || [];
    const scene = list[si];
    if (!scene) return;
    this.setPreset(scene.min, scene.id);
    this.setData({
      sceneIndex: [gi, si],
      sceneTriggerLabel: scene.label,
      scenePlaceholder: false,
      sceneRange: [
        this.data.sceneRange[0],
        list.map((s) => ({
          id: s.id,
          label: s.label,
          min: s.min,
          title: s.title,
        })),
      ],
    });
  },

  onToggle() {
    if (this.finished && !this.running) {
      this.remainMs = this.totalMs;
      this.finished = false;
      this.finishedHandled = false;
      this.start();
      return;
    }
    if (this.running) {
      this.pause();
    } else {
      this.start();
    }
  },

  start() {
    if (this.remainMs <= 0) return;
    clearAlerts();
    this.finishedHandled = false;
    this.finished = false;
    this.endAt = Date.now() + this.remainMs;
    this.running = true;
    this.setKeepScreenOn(true);
    const ambient = getAmbientMode();
    if (ambient && ambient !== 'off') {
      setAmbientMode(ambient);
    }
    this.startTicker();
    this.refreshUi();
  },

  pause() {
    if (!this.running) return;
    this.tick();
    this.stopTicker();
    this.running = false;
    this.endAt = 0;
    this.setKeepScreenOn(false);
    this.refreshUi();
  },

  onReset() {
    this.stopTicker();
    clearAlerts();
    this.finishedHandled = false;
    this.running = false;
    this.finished = false;
    this.endAt = 0;
    this.remainMs = this.totalMs;
    this.setKeepScreenOn(false);
    this.refreshUi();
  },

});
