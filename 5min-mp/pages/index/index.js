/**
 * Copyright 2026 学记宝 / xuejibao.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

const {
  t,
  initLocale,
  setLocale,
  getLocale,
  localeOptions,
  isRtl,
  nativeName,
} = require('../../utils/i18n');
const {
  PRESET_MINS,
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

const WARN_MS = 60 * 1000;
const AMBIENT_KEYS = Object.freeze([
  { id: 'off', key: 'ambientOff' },
  { id: 'rain', key: 'ambientRain' },
  { id: 'waves', key: 'ambientWaves' },
  { id: 'clock', key: 'ambientClock' },
]);

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

function readNavMetrics() {
  try {
    const win = wx.getWindowInfo ? wx.getWindowInfo() : wx.getSystemInfoSync();
    const menu = wx.getMenuButtonBoundingClientRect
      ? wx.getMenuButtonBoundingClientRect()
      : null;
    const statusBarHeight = win.statusBarHeight || 20;
    const menuHeight = (menu && menu.height) || 32;
    const menuTop = (menu && menu.top) || statusBarHeight + 6;
    const navBarHeight = menuHeight + (menuTop - statusBarHeight) * 2;
    const navPadTop = statusBarHeight;
    const navPadRight = menu
      ? Math.max(8, win.windowWidth - menu.left + 8)
      : 96;
    // 下拉面板：顶栏下方、胶囊内侧
    const panelTop = statusBarHeight + navBarHeight + 4;
    const panelRight = menu
      ? Math.max(12, win.windowWidth - menu.left + 4)
      : 16;
    return {
      navBarHeight,
      navPadTop,
      navPadRight,
      menuTop: panelTop,
      menuRight: panelRight,
    };
  } catch (e) {
    return {
      navBarHeight: 44,
      navPadTop: 44,
      navPadRight: 96,
      menuTop: 92,
      menuRight: 16,
    };
  }
}

Page({
  data: {
    navBarHeight: 44,
    navPadTop: 44,
    navPadRight: 96,
    menuTop: 92,
    menuRight: 16,
    brandTitle: '',
    stageLabel: '',
    actionsLabel: '',
    presetsLabel: '',
    footnote: '',
    ambientLabel: '',
    langLabel: '',
    presets: PRESET_MINS,
    presetItems: [],
    activePreset: DEFAULT_MIN,
    timeText: formatTime(DEFAULT_MIN * 60 * 1000),
    statusText: '',
    statsText: '',
    primaryLabel: '',
    resetLabel: '',
    canReset: false,
    running: false,
    phase: 'idle',
    sceneTriggerLabel: '',
    scenePlaceholder: true,
    sceneRange: [[], []],
    sceneIndex: [0, 0],
    canvasCss: 260,
    ambient: 'off',
    ambientOpen: false,
    ambientOptions: [],
    langOpen: false,
    localeLabel: '',
    localeOptions: [],
    rtl: false,
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

  onLoad() {
    const nav = readNavMetrics();
    initLocale();
    const ambient = initAmbient();
    this.setData({
      ...nav,
      ambient,
    });
    this.applyLocaleLabels(true);
    this.refreshStats();
    this.refreshUi();
  },

  onReady() {
    this.initCanvas();
  },

  onShow() {
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

  buildAmbientOptions() {
    const cur = getAmbientMode();
    return AMBIENT_KEYS.map((item) => ({
      id: item.id,
      label: t(item.key),
      active: item.id === cur,
    }));
  },

  buildPresetItems() {
    return PRESET_MINS.map((min) => ({
      min,
      label: t('minutes', { n: min }),
    }));
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
    const selected = range1[si];
    this.setData({
      sceneRange: [range0, range1],
      sceneIndex: [gi, si],
      sceneTriggerLabel: selected
        ? selected.label
        : t('scenePlaceholder'),
      scenePlaceholder: !this.activeSceneId,
    });
  },

  applyLocaleLabels(rebuildScenes) {
    this.setData({
      stageLabel: t('stageLabel'),
      actionsLabel: t('actionsLabel'),
      presetsLabel: t('presetsLabel'),
      footnote: t('footnote'),
      ambientLabel: t('ambientLabel'),
      langLabel: t('langLabel'),
      localeLabel: nativeName(getLocale()),
      localeOptions: localeOptions(),
      ambientOptions: this.buildAmbientOptions(),
      presetItems: this.buildPresetItems(),
      rtl: isRtl(),
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
      statsText = `${t('dailyStatsLabel')} · ${stats.count}${t(
        'dailyStatsCountUnit'
      )} · ${minutes}${t('dailyStatsMinutesUnit')}`;
    }
    this.setData({ statsText });
  },

  refreshUi() {
    const remain = this.remainMs;
    const running = this.running;
    const finished = this.finished;
    const phase = visualPhase(remain, running, finished);
    const totalMin = Math.round(this.totalMs / 60000);
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

    const activePreset =
      this.activeSceneId == null && PRESET_MINS.includes(totalMin)
        ? totalMin
        : 0;

    this.setData({
      timeText,
      statusText,
      primaryLabel,
      resetLabel: t('reset'),
      canReset: running || remain < this.totalMs || finished,
      running,
      phase,
      brandTitle,
      activePreset,
      scenePlaceholder: !this.activeSceneId,
      ambient: getAmbientMode(),
      ambientOptions: this.buildAmbientOptions(),
    });

    this.drawDial(this.totalMs > 0 ? remain / this.totalMs : 0, timeText, phase);
  },

  noop() {},

  reopenCanvasSoon() {
    // wx:if 卸载后需重建 canvas 节点
    this.canvas = null;
    this.ctx = null;
    setTimeout(() => this.initCanvas(), 32);
  },

  onCloseMenus() {
    const wasOpen = this.data.ambientOpen || this.data.langOpen;
    this.setData({ ambientOpen: false, langOpen: false });
    if (wasOpen) this.reopenCanvasSoon();
  },

  onAmbientToggle() {
    const open = !this.data.ambientOpen;
    this.setData({
      ambientOpen: open,
      langOpen: false,
      ambientOptions: this.buildAmbientOptions(),
    });
    if (!open) this.reopenCanvasSoon();
  },

  onAmbientSelect(e) {
    const id = e.currentTarget.dataset.id;
    const next = setAmbientMode(id);
    this.setData({
      ambient: next,
      ambientOpen: false,
      ambientOptions: this.buildAmbientOptions(),
    });
    this.reopenCanvasSoon();
  },

  onLangToggle() {
    const open = !this.data.langOpen;
    this.setData({
      langOpen: open,
      ambientOpen: false,
      localeOptions: localeOptions(),
    });
    if (!open) this.reopenCanvasSoon();
  },

  onLangSelect(e) {
    const code = e.currentTarget.dataset.code;
    setLocale(code);
    this.setData({ langOpen: false });
    this.applyLocaleLabels(true);
    this.refreshStats();
    this.refreshUi();
    this.reopenCanvasSoon();
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
    recordCompletedSession(this.totalMs);
    this.refreshStats();
    this.refreshUi();
    const n = Math.round(this.totalMs / 60000);
    alertFinish({
      title: t('notifyTitle', { n }),
      body: t('notifyBody', { n }),
      durationMs: ALERT_DURATION_MS,
    });
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

  onPreset(e) {
    if (this.running) return;
    const min = Number(e.currentTarget.dataset.min);
    if (!Number.isFinite(min) || min <= 0) return;
    this.setPreset(min, null);
    this.setData({
      sceneTriggerLabel: t('scenePlaceholder'),
      scenePlaceholder: true,
      sceneIndex: [0, 0],
    });
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
    // 用户手势后按偏好起播环境音
    if (this.data.ambient && this.data.ambient !== 'off') {
      setAmbientMode(this.data.ambient);
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
