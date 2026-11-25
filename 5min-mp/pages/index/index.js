/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

const { t, getLocale } = require('../../utils/i18n');
const {
  DEFAULT_MIN,
  sceneById,
  buildScenePicker,
  resolveSceneTitle,
  statusDoneText,
  notifyBodyText,
  CHIP_N,
} = require('../../utils/catalog');
const {
  getTodayStats,
  recordCompletedSession,
  statsMinutes,
} = require('../../utils/stats');
const history = require('../../utils/history');
const {
  alertFinishStrong,
  clearAlerts,
  unlockAlertAudio,
  setFinishAlertPending,
  clearFinishAlertPending,
  realertFinishIfPending,
} = require('../../utils/alert');
const { drawDigitalWatch } = require('../../utils/digitalWatch');
const {
  initAmbient,
  getAmbientMode,
  setAmbientMode,
  pauseAmbient,
} = require('../../utils/ambient');
const prefs = require('../../utils/prefs');
const p0 = require('../../utils/p0Features');
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

function formatOvertime(ms) {
  const totalSec = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(totalSec / 60);
  const s = totalSec % 60;
  if (m > 0) return `${m}:${pad2(s)}`;
  return `0:${pad2(s)}`;
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
  // 计时数字默认最黑，不使用品牌色
  return '#000000';
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
    statsEmpty: true,
    statsLabel: '',
    statsCountText: '',
    statsMinutesText: '',
    statsCountUnit: '',
    statsMinutesUnit: '',
    primaryLabel: '',
    resetLabel: '',
    canReset: false,
    running: false,
    phase: 'idle',
    sceneTriggerLabel: '',
    scenePlaceholder: false,
    sceneRange: [[], []],
    sceneIndex: [0, 1],
    suggestedChips: [],
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
    showIgnore: false,
    finishIgnoreLabel: '',
    showRitual: false,
    ritualTitle: '',
    ritualStepUp: '',
    ritualStepStretch: '',
    ritualStepLeave: '',
    ritualDone: '',
    ritualSkip: '',
    ritualUp: false,
    ritualStretch: false,
    ritualLeave: false,
  },

  totalMs: DEFAULT_MIN * 60 * 1000,
  remainMs: DEFAULT_MIN * 60 * 1000,
  running: false,
  finished: false,
  finishedHandled: false,
  endAt: 0,
  tickTimer: null,
  activeSceneId: null,
  lastRecordedSessionId: '',
  inOvertime: false,
  overtimeAt: 0,
  overtimeMs: 0,
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
    this.migrateLegacyCustomMinIfNeeded();
    const custom = prefs.getCustomMin(DEFAULT_MIN);
    const toilet = sceneById('toilet');
    const customScenes = prefs.getCustomScenes();
    // 默认场景：如厕 · 5 分钟；否则匹配自定义场景，再退回纯时长
    if (toilet && custom === toilet.min) {
      this.setPreset(toilet.min, toilet.id);
    } else {
      const match = customScenes.find((s) => s.min === custom);
      if (match) {
        this.setPreset(match.min, match.id);
      } else {
        this.totalMs = custom * 60 * 1000;
        this.remainMs = this.totalMs;
        this.activeSceneId = null;
      }
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
    this.consumePendingScene();
    this.syncActiveCustomScene();
    this.refreshStats();
    if (this.running && this.endAt) {
      this.tick();
    } else if (this.finished && !this.running) {
      realertFinishIfPending();
    }
  },

  onUnload() {
    this.stopTicker();
    clearAlerts();
    pauseAmbient();
    this.setKeepScreenOn(false);
  },

  migrateLegacyCustomMinIfNeeded() {
    if (prefs.isCustomScenesMigrated()) return;
    try {
      const scenes = prefs.getCustomScenes();
      if (scenes.length === 0) {
        const legacy = prefs.getCustomMin(DEFAULT_MIN);
        if (legacy !== DEFAULT_MIN) {
          prefs.setCustomScenes([
            {
              id: prefs.makeId(),
              name: t('customSceneMigratedName'),
              min: legacy,
            },
          ]);
          return;
        }
      }
    } finally {
      prefs.markCustomScenesMigrated();
    }
  },

  consumePendingScene() {
    const app = getApp();
    const pending =
      app && app.globalData ? app.globalData.pendingSceneId : null;
    if (!pending) return;
    if (this.running) return;
    app.globalData.pendingSceneId = null;
    this.selectScene(pending);
  },

  syncActiveCustomScene() {
    if (
      !this.running &&
      this.activeSceneId &&
      String(this.activeSceneId).indexOf('custom_') === 0
    ) {
      const found = prefs
        .getCustomScenes()
        .find((s) => s.id === this.activeSceneId);
      if (!found) {
        this.activeSceneId = null;
        this.rebuildScenePicker(false);
        this.refreshUi();
        return;
      }
      if (this.totalMs !== found.min * 60 * 1000) {
        this.setPreset(found.min, found.id);
      }
    }
    this.rebuildScenePicker(!!this.activeSceneId);
    this.refreshUi();
  },

  selectScene(id) {
    if (this.running) return;
    const custom = prefs.getCustomScenes().find((s) => s.id === id);
    if (custom) {
      prefs.setCustomMin(custom.min);
      this.setPreset(custom.min, custom.id);
      this.rebuildScenePicker(true);
      return;
    }
    const scene = sceneById(id);
    if (!scene) return;
    prefs.setCustomMin(scene.min);
    this.setPreset(scene.min, scene.id);
    this.rebuildScenePicker(true);
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
    const suggested = this.scenePicker.suggested || [];
    const suggestedChips = suggested
      .slice(0, CHIP_N)
      .map((id) => {
        const title = resolveSceneTitle(id);
        if (!title) return null;
        return {
          id,
          title,
          active: id === this.activeSceneId,
        };
      })
      .filter(Boolean);
    this.setData({
      sceneRange: [range0, range1],
      sceneIndex: [gi, si],
      sceneTriggerLabel: selected
        ? selected.label
        : t('scenePlaceholder'),
      scenePlaceholder: !hasScene,
      suggestedChips,
    });
  },

  onSuggestedChip(e) {
    if (this.running) return;
    const id = e.currentTarget.dataset.id;
    if (!id) return;
    this.selectScene(id);
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
        const win =
          typeof wx.getWindowInfo === 'function' ? wx.getWindowInfo() : null;
        const dpr = (win && win.pixelRatio) || 1;
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

    drawDigitalWatch(ctx, size, timeText, timeColor, { blinking: this.running });
  },

  refreshStats() {
    const stats = getTodayStats();
    if (stats.count <= 0) {
      this.setData({
        statsEmpty: true,
        statsText: `${t('dailyStatsLabel')} · ${t('dailyStatsEmpty')}`,
        statsLabel: t('dailyStatsLabel'),
        statsCountText: '',
        statsMinutesText: '',
        statsCountUnit: t('dailyStatsCountUnit'),
        statsMinutesUnit: t('dailyStatsMinutesUnit'),
      });
      return;
    }
    const minutes = statsMinutes(stats.totalMs);
    this.setData({
      statsEmpty: false,
      statsText: '',
      statsLabel: t('dailyStatsLabel'),
      statsCountText: String(stats.count),
      statsMinutesText: String(minutes),
      statsCountUnit: t('dailyStatsCountUnit'),
      statsMinutesUnit: t('dailyStatsMinutesUnit'),
    });
  },

  commitOvertimeToHistoryIfNeeded() {
    if (!this.inOvertime || this.overtimeMs <= 0 || !this.lastRecordedSessionId) return;
    const ot = this.overtimeMs;
    history.updateSessionElapsed(
      this.lastRecordedSessionId,
      this.totalMs + this.overtimeMs
    );
    p0.recordOvertime(ot);
    this.refreshStats();
  },

  clearOvertimeState() {
    this.inOvertime = false;
    this.overtimeAt = 0;
    this.overtimeMs = 0;
  },

  resetToIdleAfterFinish() {
    this.stopTicker();
    clearAlerts();
    clearFinishAlertPending();
    this.finishedHandled = false;
    this.clearOvertimeState();
    this.lastRecordedSessionId = '';
    this.remainMs = this.totalMs;
    this.running = false;
    this.finished = false;
    this.endAt = 0;
    this.setKeepScreenOn(false);
    if (this.data.showRitual) {
      this.setData({ showRitual: false });
      this.reopenCanvasSoon();
    }
    this.refreshUi();
  },

  onIgnoreFinish() {
    if (!this.lastRecordedSessionId) return;
    history.deleteSession(this.lastRecordedSessionId);
    this.lastRecordedSessionId = '';
    this.refreshStats();
    this.resetToIdleAfterFinish();
  },

  /** Lightweight tick path — dial / status / phase only (avoids full setData churn). */
  refreshTickUi() {
    const remain = this.remainMs;
    const running = this.running;
    const finished = this.finished;
    let phase = visualPhase(remain, running, finished);
    let timeText = formatTime(remain);

    if (this.inOvertime) {
      timeText = `+${formatOvertime(this.overtimeMs)}`;
      phase = 'done';
    }

    let primaryLabel = t('start');
    if (finished && !running) primaryLabel = t('again');
    else if (running) primaryLabel = t('pause');
    else if (remain < this.totalMs && remain > 0) primaryLabel = t('resume');

    let statusText = t('statusIdle');
    if (this.inOvertime) {
      statusText = t('statusOvertime', { n: formatOvertime(this.overtimeMs) });
    } else if (finished || remain <= 0) statusText = statusDoneText(this.activeSceneId);
    else if (running && remain <= WARN_MS) statusText = t('statusWarn');
    else if (running) statusText = t('statusRunning');
    else if (remain < this.totalMs) statusText = t('statusPaused');

    const dialProgress = this.inOvertime ? 0 : (this.totalMs > 0 ? remain / this.totalMs : 0);

    this.setData({
      timeText,
      statusText,
      primaryLabel,
      canReset: running || remain < this.totalMs || finished,
      running,
      phase,
      showIgnore: finished && !!this.lastRecordedSessionId,
    });

    this.drawDial(dialProgress, timeText, phase);
  },

  refreshUi() {
    const remain = this.remainMs;
    const running = this.running;
    const finished = this.finished;
    let phase = visualPhase(remain, running, finished);
    let timeText = formatTime(remain);

    if (this.inOvertime) {
      timeText = `+${formatOvertime(this.overtimeMs)}`;
      phase = 'done';
    }

    let primaryLabel = t('start');
    if (finished && !running) primaryLabel = t('again');
    else if (running) primaryLabel = t('pause');
    else if (remain < this.totalMs && remain > 0) primaryLabel = t('resume');

    let statusText = t('statusIdle');
    if (this.inOvertime) {
      statusText = t('statusOvertime', { n: formatOvertime(this.overtimeMs) });
    } else if (finished || remain <= 0) statusText = statusDoneText(this.activeSceneId);
    else if (running && remain <= WARN_MS) statusText = t('statusWarn');
    else if (running) statusText = t('statusRunning');
    else if (remain < this.totalMs) statusText = t('statusPaused');

    let brandTitle = t('brandTitle');
    if (this.activeSceneId) {
      const title = resolveSceneTitle(this.activeSceneId);
      if (title) brandTitle = title;
    }

    const dialProgress = this.inOvertime ? 0 : (this.totalMs > 0 ? remain / this.totalMs : 0);

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
      showIgnore: finished && !!this.lastRecordedSessionId,
      finishIgnoreLabel: t('finishIgnore'),
    });

    this.drawDial(dialProgress, timeText, phase);
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
    const alerts = p0.resolveFinishAlerts(prefs);
    alertFinishStrong({
      title: t('notifyTitle', vars),
      body: notifyBodyText(this.activeSceneId, vars),
      withNotify: alerts.withNotify,
      withVibrate: alerts.withVibrate,
      withTone: alerts.withTone,
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
    this.lastTickDial = '';
    this.tickTimer = setInterval(() => this.tick(), 200);
  },

  tick() {
    if (this.inOvertime) {
      this.overtimeMs = Math.max(0, Date.now() - this.overtimeAt);
      const dial = `+${formatOvertime(this.overtimeMs)}`;
      if (dial !== this.lastTickDial) {
        this.lastTickDial = dial;
        this.refreshTickUi();
      }
      return;
    }
    if (!this.running || !this.endAt) return;
    const remain = Math.max(0, this.endAt - Date.now());
    this.remainMs = remain;
    if (remain <= 0) {
      this.onFinished();
      return;
    }
    const dial = formatTime(remain);
    // Throttle setData to ~1Hz when only the dial second changes.
    if (dial !== this.lastTickDial) {
      this.lastTickDial = dial;
      this.refreshTickUi();
    }
  },

  onFinished() {
    if (this.finishedHandled) return;
    this.finishedHandled = true;
    this.running = false;
    this.finished = true;
    this.remainMs = 0;
    this.endAt = 0;
    this.setKeepScreenOn(false);
    const rec = recordCompletedSession(this.totalMs, this.activeSceneId || '');
    this.lastRecordedSessionId = rec.id || '';
    if (rec.stats) {
      this.refreshStats();
    }
    this.inOvertime = true;
    this.overtimeAt = Date.now();
    this.overtimeMs = 0;
    this.startTicker();
    this.refreshUi();
    const vars = {
      n: Math.max(1, Math.round(this.totalMs / 60000)),
      scene: this.notifySceneName(),
    };
    const alerts = p0.resolveFinishAlerts(prefs);
    const finishOpts = {
      title: t('notifyTitle', vars),
      body: notifyBodyText(this.activeSceneId, vars),
      withNotify: alerts.withNotify,
      withVibrate: alerts.withVibrate,
      withTone: alerts.withTone,
    };
    // Keep for App/page onShow re-alert (local only — no server push).
    setFinishAlertPending(finishOpts);
    alertFinishStrong(finishOpts);
    this.maybeShowRitual();
  },

  maybeShowRitual() {
    if (p0.getStandRitual() !== p0.RITUAL_BASIC) return;
    // 卸载 canvas，避免原生层盖住仪式遮罩
    this.canvas = null;
    this.ctx = null;
    const scene = sceneById(this.activeSceneId);
    const pack = p0.resolveRitualPack(this.activeSceneId, scene && scene.group);
    const steps = pack.stepKeys || [];
    this.setData({
      showRitual: true,
      ritualTitle: t(pack.titleKey || 'standRitualTitle'),
      ritualStepUp: t(steps[0] || 'standRitualStepUp'),
      ritualStepStretch: t(steps[1] || 'standRitualStepStretch'),
      ritualStepLeave: t(steps[2] || 'standRitualStepLeave'),
      ritualDone: t('standRitualDone'),
      ritualSkip: t('standRitualSkip'),
      ritualUp: false,
      ritualStretch: false,
      ritualLeave: false,
    });
  },

  dismissRitual() {
    this.setData({ showRitual: false });
    this.reopenCanvasSoon();
  },

  onToggleRitualUp() {
    this.setData({ ritualUp: !this.data.ritualUp });
  },
  onToggleRitualStretch() {
    this.setData({ ritualStretch: !this.data.ritualStretch });
  },
  onToggleRitualLeave() {
    this.setData({ ritualLeave: !this.data.ritualLeave });
  },
  onRitualSkip() {
    this.dismissRitual();
  },
  onRitualDone() {
    this.dismissRitual();
  },

  notifySceneName() {
    if (this.activeSceneId) {
      const title = resolveSceneTitle(this.activeSceneId);
      if (title) return title;
    }
    return t('sceneToiletTitle');
  },

  setPreset(minutes, sceneId) {
    if (this.running) return;
    this.commitOvertimeToHistoryIfNeeded();
    this.clearOvertimeState();
    this.lastRecordedSessionId = '';
    clearAlerts();
    clearFinishAlertPending();
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
    this.selectScene(scene.id);
  },

  onToggle() {
    if (this.finished && !this.running) {
      this.commitOvertimeToHistoryIfNeeded();
      this.clearOvertimeState();
      this.lastRecordedSessionId = '';
      clearAlerts();
      clearFinishAlertPending();
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
    clearFinishAlertPending();
    unlockAlertAudio();
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
    this.commitOvertimeToHistoryIfNeeded();
    this.stopTicker();
    clearAlerts();
    clearFinishAlertPending();
    this.finishedHandled = false;
    this.clearOvertimeState();
    this.lastRecordedSessionId = '';
    this.running = false;
    this.finished = false;
    this.endAt = 0;
    this.remainMs = this.totalMs;
    this.setKeepScreenOn(false);
    this.refreshUi();
  },

});
