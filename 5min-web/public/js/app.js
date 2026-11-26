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

/**
 * 5min · Toilet Timer
 * HTML5 + modern native JavaScript (ES modules)
 */
import {
  LOCALES,
  LOCALE_CODES,
  LOCALE_NATIVE_NAMES,
  STORAGE_KEY,
  detectLocale,
  ensureLocale,
  resolveLocale,
  t,
} from './i18n/locales.js';
import {
  alertFinish,
  alertOnVisible,
  clearAlerts,
  getVibratePattern,
  realertFromGesture,
  startAudioKeepAlive,
  stopAudioKeepAlive,
  unlockAlertAudio,
} from './alert.js';
import {
  getTodayStats,
  getSceneSessions,
  recordCompletedSession,
  statsMinutes,
} from './stats.js';
import {
  getHistory,
  getStreak,
  shareSummaryValues,
  deleteSession,
  clearHistory,
  updateSessionElapsed,
  exportHistoryCsv,
} from './history.js';
import {
  listCustomScenes,
  getCustomScene,
  addCustomScene,
  updateCustomScene,
  deleteCustomScene,
  GROUP_ID as CUSTOM_GROUP_ID,
  MAX_COUNT as CUSTOM_MAX_COUNT,
  MAX_NAME as CUSTOM_MAX_NAME,
  sanitizeName,
  clampMinutes,
} from './custom-scenes.js';
import { shareSummary } from './share.js';
import {
  getAmbientMode,
  setAmbientMode,
  stopAmbient,
  suspendAmbient,
  resumeAmbient,
} from './ambient.js';
import {
  resolveSceneProfile,
  orderSceneGroups,
  isSceneHidden,
  mergePinnedSuggested,
} from './scene-profiles.js';
import { SCENE_GROUPS, SCENES } from './scenes-data.js';
import { rank as rankScenes, TOP_N as SUGGESTED_TOP_N, LABEL_KEY as SUGGESTED_LABEL_KEY } from './scene-ranker.js';
import * as p0 from './p0Features.js';
import * as prefs from './prefs.js';
import * as cloudSync from './cloudSync.js';

const CIRC = 2 * Math.PI * 54;

const AMBIENT_LABEL_KEYS = Object.freeze({
  off: 'ambientOff',
  rain: 'ambientRain',
  waves: 'ambientWaves',
  clock: 'ambientClock',
});

const progress = document.querySelector('#progress');
const timeText = document.querySelector('#timeText');
const timeLabel = document.querySelector('#timeLabel');
const noticeEl = document.querySelector('#notice');
const statusEl = document.querySelector('#status');
const dailyStatsEl = document.querySelector('#dailyStats');
const startBtn = document.querySelector('#startBtn');
const resetBtn = document.querySelector('#resetBtn');
const sceneSelect = document.querySelector('#sceneSelect');
const sceneTrigger = document.querySelector('#sceneTrigger');
const sceneTriggerLabel = document.querySelector('#sceneTriggerLabel');
const sceneList = document.querySelector('#sceneList');
const brandTitle = document.querySelector('#brandTitle');
const footnote = document.querySelector('#footnote');
const stageSection = document.querySelector('#stageSection');
const actionsSection = document.querySelector('#actionsSection');
const ambientBtn = document.querySelector('#ambientBtn');
const ambientPanel = document.querySelector('#ambientPanel');
const ambientWrap = document.querySelector('#ambientWrap');
const metaDescription = document.querySelector('meta[name="description"]');
const recordsBtn = document.querySelector('#recordsBtn');
const recordsSheet = document.querySelector('#recordsSheet');
const recordsClose = document.querySelector('#recordsClose');
const recordsTitle = document.querySelector('#recordsTitle');
const recordsPeriod = document.querySelector('#recordsPeriod');
const recordsStreak = document.querySelector('#recordsStreak');
const historyFilter = document.querySelector('#historyFilter');
const historyFilterLabel = document.querySelector('#historyFilterLabel');
const historyList = document.querySelector('#historyList');
const historyEmptyHint = document.querySelector('#historyEmptyHint');
const historyClearBtn = document.querySelector('#historyClearBtn');
const shareBtn = document.querySelector('#shareBtn');
const exportBtn = document.querySelector('#exportBtn');
const shareToast = document.querySelector('#shareToast');
const overtimeInsightEl = document.querySelector('#overtimeInsight');
const overtimeInsightTitle = document.querySelector('#overtimeInsightTitle');
const overtimeInsightLine = document.querySelector('#overtimeInsightLine');
const overtimeInsightHint = document.querySelector('#overtimeInsightHint');
const customScenesBtn = document.querySelector('#customScenesBtn');
const customScenesSheet = document.querySelector('#customScenesSheet');
const customScenesClose = document.querySelector('#customScenesClose');
const customScenesTitle = document.querySelector('#customScenesTitle');
const customScenesHint = document.querySelector('#customScenesHint');
const customSceneList = document.querySelector('#customSceneList');
const customSceneForm = document.querySelector('#customSceneForm');
const customSceneEditId = document.querySelector('#customSceneEditId');
const customSceneName = document.querySelector('#customSceneName');
const customSceneMin = document.querySelector('#customSceneMin');
const customSceneNameLabel = document.querySelector('#customSceneNameLabel');
const customSceneMinLabel = document.querySelector('#customSceneMinLabel');
const customSceneSaveBtn = document.querySelector('#customSceneSaveBtn');
const customSceneCancelBtn = document.querySelector('#customSceneCancelBtn');
const settingsLangLabel = document.querySelector('#settingsLangLabel');
const settingsLocaleSelect = document.querySelector('#settingsLocaleSelect');
const settingsBtn = document.querySelector('#settingsBtn');
const settingsSheet = document.querySelector('#settingsSheet');
const settingsClose = document.querySelector('#settingsClose');
const settingsTitle = document.querySelector('#settingsTitle');
const alertProfileLabel = document.querySelector('#alertProfileLabel');
const alertProfileSelect = document.querySelector('#alertProfileSelect');
const alertProfileHint = document.querySelector('#alertProfileHint');
const standRitualLabel = document.querySelector('#standRitualLabel');
const standRitualSelect = document.querySelector('#standRitualSelect');
const overtimeInsightPrefLabel = document.querySelector('#overtimeInsightPrefLabel');
const overtimeInsightToggle = document.querySelector('#overtimeInsightToggle');
const storageModeLabel = document.querySelector('#storageModeLabel');
const storageModeSelect = document.querySelector('#storageModeSelect');
const storageModeHint = document.querySelector('#storageModeHint');
const storageSyncStatus = document.querySelector('#storageSyncStatus');
const storageBackupBlock = document.querySelector('#storageBackupBlock');
const storageBackupShowBtn = document.querySelector('#storageBackupShowBtn');
const storageBackupShowLabel = document.querySelector('#storageBackupShowLabel');
const storageBackupBody = document.querySelector('#storageBackupBody');
const storageBackupCode = document.querySelector('#storageBackupCode');
const storageBackupHint = document.querySelector('#storageBackupHint');
const storageBackupCopyBtn = document.querySelector('#storageBackupCopyBtn');
const storageBackupStatus = document.querySelector('#storageBackupStatus');
const storageRestoreToggle = document.querySelector('#storageRestoreToggle');
const storageRestoreLabel = document.querySelector('#storageRestoreLabel');
const storageRestoreBody = document.querySelector('#storageRestoreBody');
const storageRestoreInput = document.querySelector('#storageRestoreInput');
const storageRestoreHint = document.querySelector('#storageRestoreHint');
const storageRestoreBtn = document.querySelector('#storageRestoreBtn');
const ritualMask = document.querySelector('#ritualMask');
const ritualTitle = document.querySelector('#ritualTitle');
const ritualStep0 = document.querySelector('#ritualStep0');
const ritualStep1 = document.querySelector('#ritualStep1');
const ritualStep2 = document.querySelector('#ritualStep2');
const ritualSkip = document.querySelector('#ritualSkip');
const ritualDone = document.querySelector('#ritualDone');
const confirmMask = document.querySelector('#confirmMask');
const confirmMessage = document.querySelector('#confirmMessage');
const confirmCancel = document.querySelector('#confirmCancel');
const confirmOk = document.querySelector('#confirmOk');

/** @type {((ok: boolean) => void) | null} */
let confirmResolver = null;

/**
 * In-app confirm (replaces window.confirm).
 * @param {string} message
 * @returns {Promise<boolean>}
 */
const showConfirm = (message) => {
  if (!confirmMask || !confirmMessage || !confirmCancel || !confirmOk) {
    return Promise.resolve(globalThis.confirm(message));
  }
  if (confirmResolver) {
    confirmResolver(false);
    confirmResolver = null;
  }
  confirmMessage.textContent = message;
  confirmCancel.textContent = tr('cancelLabel');
  confirmOk.textContent = tr('confirmLabel');
  confirmMask.hidden = false;
  window.setTimeout(() => confirmOk.focus(), 0);
  return new Promise((resolve) => {
    confirmResolver = resolve;
  });
};

const closeConfirm = (ok) => {
  if (confirmMask) confirmMask.hidden = true;
  const resolve = confirmResolver;
  confirmResolver = null;
  if (resolve) resolve(!!ok);
};

/** @type {string} */
let historyFilterSceneId = '';
/** @type {number} */
let shareToastTimer = 0;
/** @type {number} */
let prefsPushTimer = 0;
let inOvertime = false;
let overtimeAt = 0;
let overtimeMs = 0;
/** @type {string} */
let lastRecordedSessionId = '';
/** @type {boolean[]} */
let ritualChecks = [false, false, false];

/** Debounce cloud prefs writes to avoid burst traffic while tuning settings. */
const schedulePrefsPush = () => {
  if (prefsPushTimer) clearTimeout(prefsPushTimer);
  prefsPushTimer = window.setTimeout(() => {
    prefsPushTimer = 0;
    void cloudSync.pushPrefsOnly().catch(() => {});
  }, 400);
};

const qs = new URLSearchParams(location.search);
const secRaw = Number.parseInt(qs.get('sec') ?? '', 10);
const bootSec = Number.isFinite(secRaw) ? Math.min(3600, Math.max(1, secRaw)) : 0;
const defaultMin = bootSec > 0 ? bootSec / 60 : 5;
const TIMER_SESSION_KEY = '5min.web.timer.v1';

let locale = resolveLocale(qs.get('lang')) ?? detectLocale();
let totalMs = defaultMin * 60 * 1000;
let remainMs = totalMs;
let endAt = 0;
let running = false;
let finished = false;
let tickId = 0;
/** Last dial clock string written to the SVG — skip identical rebuilds each tick. */
let lastDialClock = '';
let titleBlinkId = 0;
/** @type {string | null} */
let activeScene = null;
/** @type {WakeLockSentinel | null} */
let wakeLock = null;
let notifyAsked = false;
let needAlertOnVisible = false;

const persistTimerSession = () => {
  try {
    const liveRemain = running ? Math.max(0, endAt - Date.now()) : remainMs;
    sessionStorage.setItem(TIMER_SESSION_KEY, JSON.stringify({
      totalMs,
      remainMs: liveRemain,
      endAt: running ? endAt : 0,
      running,
      finished,
      activeScene,
      savedAt: Date.now(),
    }));
  } catch {
    /* private mode / quota */
  }
};

const clearTimerSession = () => {
  try { sessionStorage.removeItem(TIMER_SESSION_KEY); } catch { /* ignore */ }
};

/** @returns {boolean} whether a session was restored */
const restoreTimerSession = () => {
  try {
    const raw = sessionStorage.getItem(TIMER_SESSION_KEY);
    if (!raw) return false;
    const data = JSON.parse(raw);
    if (!data || typeof data !== 'object') return false;
    const nextTotal = Number(data.totalMs);
    if (!Number.isFinite(nextTotal) || nextTotal < 1000 || nextTotal > 3_600_000) return false;
    const sceneId = data.activeScene == null ? null : String(data.activeScene);
    if (sceneId && !findBuiltInScene(sceneId) && !getCustomScene(sceneId)) return false;

    totalMs = Math.floor(nextTotal);
    activeScene = sceneId;
    finished = !!data.finished;
    const wasRunning = !!data.running;
    const savedEnd = Number(data.endAt);
    if (wasRunning && Number.isFinite(savedEnd) && savedEnd > 0) {
      remainMs = savedEnd - Date.now();
      if (remainMs <= 0) {
        remainMs = 0;
        endAt = 0;
        running = false;
        finished = true;
      } else {
        endAt = savedEnd;
        running = true;
        finished = false;
      }
    } else {
      const savedRemain = Number(data.remainMs);
      remainMs = Number.isFinite(savedRemain)
        ? Math.min(totalMs, Math.max(0, Math.floor(savedRemain)))
        : totalMs;
      endAt = 0;
      running = false;
      if (remainMs <= 0) finished = true;
      else if (remainMs >= totalMs) finished = false;
    }
    return true;
  } catch {
    return false;
  }
};

progress.style.strokeDasharray = String(CIRC);
progress.style.strokeDashoffset = '0';
progress.classList.add('is-safe');

const tr = (key, vars) => t(locale, key, vars);

const fmt = (ms) => {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
};

/** 七段电子表：现代细段 + 鼠尾草绿底盘（a 顶 / b 右上 / c 右下 / d 底 / e 左下 / f 左上 / g 中） */
const DIGIT_SEGS = Object.freeze([
  'abcdef', 'bc', 'abged', 'abgcd', 'fgbc',
  'afgcd', 'afgcde', 'abc', 'abcdefg', 'abfgcd',
]);
const ALL_SEGS = 'abcdefg';
/** 熄灭段底盘：固定鼠尾草灰绿，不随亮段染色 */
const WATCH_CHASSIS = '#e4ece8';

const svgN = (v) => Math.round(Number(v) * 10) / 10;

const hBar = (x, y, w, t) => {
  const tip = t * 0.55;
  return (
    `M${svgN(x)} ${svgN(y + t / 2)} L${svgN(x + tip)} ${svgN(y)} H${svgN(x + w - tip)} ` +
    `L${svgN(x + w)} ${svgN(y + t / 2)} L${svgN(x + w - tip)} ${svgN(y + t)} H${svgN(x + tip)} Z`
  );
};

const vBar = (x, y, h, t) => {
  const tip = t * 0.55;
  return (
    `M${svgN(x + t / 2)} ${svgN(y)} L${svgN(x + t)} ${svgN(y + tip)} V${svgN(y + h - tip)} ` +
    `L${svgN(x + t / 2)} ${svgN(y + h)} L${svgN(x)} ${svgN(y + h - tip)} V${svgN(y + tip)} Z`
  );
};

const digitSegMap = (ox, oy) => {
  const dw = 24;
  const dh = 38;
  const t = 3;
  const gap = 1.25;
  const mid = dh / 2;
  const inset = 2.2;
  return {
    a: hBar(ox + inset, oy, dw - inset * 2, t),
    g: hBar(ox + inset, oy + mid - t / 2, dw - inset * 2, t),
    d: hBar(ox + inset, oy + dh - t, dw - inset * 2, t),
    f: vBar(ox, oy + t + gap, mid - t - gap * 2, t),
    b: vBar(ox + dw - t, oy + t + gap, mid - t - gap * 2, t),
    e: vBar(ox, oy + mid + gap, mid - t - gap * 2, t),
    c: vBar(ox + dw - t, oy + mid + gap, mid - t - gap * 2, t),
  };
};

const digitPaths = (d, ox, oy) => {
  const segs = digitSegMap(ox, oy);
  const on = DIGIT_SEGS[d] || '';
  let out = '';
  for (const k of ALL_SEGS) {
    if (on.includes(k)) out += `<path fill="currentColor" d="${segs[k]}"/>`;
    else out += `<path fill="${WATCH_CHASSIS}" d="${segs[k]}"/>`;
  }
  return out;
};

const colonPaths = (ox, oy) => {
  const cx = svgN(ox + 6);
  return (
    `<g class="watch-colon">` +
    `<circle fill="currentColor" cx="${cx}" cy="${svgN(oy + 11)}" r="2.15"/>` +
    `<circle fill="currentColor" cx="${cx}" cy="${svgN(oy + 27)}" r="2.15"/>` +
    `</g>`
  );
};

/** 固定 MM:SS 五槽布局，切换 3/5/10 分钟时尺寸不变 */
const WATCH_W = 144;
const WATCH_H = 48;
const WATCH_SLOTS = Object.freeze([
  { kind: 'digit', x: 2 },
  { kind: 'digit', x: 34 },
  { kind: 'colon', x: 64 },
  { kind: 'digit', x: 78 },
  { kind: 'digit', x: 110 },
]);

/** 计时数字：现代七段风格（恒定画布） */
const digitalWatchSvg = (text) => {
  const raw = String(text).replace(/\D/g, '').padStart(4, '0').slice(-4);
  const digits = [raw[0], raw[1], raw[2], raw[3]].map(Number);
  const oy = 5;
  let di = 0;
  let glyphs = '';
  for (const slot of WATCH_SLOTS) {
    if (slot.kind === 'colon') {
      glyphs += colonPaths(slot.x, oy);
      continue;
    }
    glyphs += digitPaths(digits[di++], slot.x, oy);
  }
  return (
    `<svg xmlns="http://www.w3.org/2000/svg" width="${WATCH_W}" height="${WATCH_H}" viewBox="0 0 ${WATCH_W} ${WATCH_H}" aria-hidden="true">` +
    glyphs +
    `</svg>`
  );
};

const syncStartLabel = () => {
  if (finished && !running) startBtn.textContent = tr('again');
  else if (running) startBtn.textContent = tr('pause');
  else if (remainMs < totalMs && remainMs > 0) startBtn.textContent = tr('resume');
  else startBtn.textContent = tr('start');
};

const renderDailyStats = () => {
  if (!dailyStatsEl) return;
  const { count, totalMs: dayMs } = getTodayStats();
  if (count <= 0 || dayMs <= 0) {
    dailyStatsEl.classList.add('is-empty');
    dailyStatsEl.textContent = `${tr('dailyStatsLabel')} · ${tr('dailyStatsEmpty')}`;
    return;
  }

  dailyStatsEl.classList.remove('is-empty');
  dailyStatsEl.replaceChildren();
  const label = document.createElement('span');
  label.className = 'cue-meta-label';
  label.textContent = tr('dailyStatsLabel');
  const vals = document.createElement('span');
  vals.className = 'cue-meta-vals';
  vals.append(
    Object.assign(document.createElement('strong'), { textContent: String(count) }),
    document.createTextNode(` ${tr('dailyStatsCountUnit')}`),
    Object.assign(document.createElement('span'), {
      className: 'cue-meta-sep',
      textContent: ' · ',
    }),
    Object.assign(document.createElement('strong'), {
      textContent: String(statsMinutes(dayMs)),
    }),
    document.createTextNode(` ${tr('dailyStatsMinutesUnit')}`),
  );
  dailyStatsEl.append(label, vals);
};

const syncAmbientI18n = () => {
  if (!ambientBtn || !ambientPanel) return;
  ambientBtn.setAttribute('aria-label', tr('ambientLabel'));
  ambientPanel.setAttribute('aria-label', tr('ambientLabel'));
  for (const btn of ambientPanel.querySelectorAll('button[data-ambient]')) {
    const key = AMBIENT_LABEL_KEYS[btn.dataset.ambient];
    if (key) btn.textContent = tr(key);
  }
};

const setSceneListOpen = (open) => {
  if (!sceneTrigger || !sceneList) return;
  sceneList.hidden = !open;
  sceneTrigger.setAttribute('aria-expanded', open ? 'true' : 'false');
};

const findBuiltInScene = (id) => SCENES.find((s) => s.id === id) || null;

/** Display title for a scene id (built-in or custom). Plain text only. */
const resolveSceneTitle = (sceneId) => {
  if (!sceneId) return tr('historySceneDefault');
  const builtIn = findBuiltInScene(sceneId);
  if (builtIn) return tr(builtIn.titleKey || builtIn.labelKey);
  const custom = getCustomScene(sceneId);
  if (custom) return custom.name;
  return tr('historySceneDefault');
};

const scenePickerLabel = (sceneId) => {
  if (!sceneId) return tr('scenePlaceholder');
  const builtIn = findBuiltInScene(sceneId);
  if (builtIn) return tr(builtIn.labelKey);
  const custom = getCustomScene(sceneId);
  if (custom) {
    const unit = tr('customUnit');
    return `${custom.name} · ${custom.min} ${unit}`;
  }
  return tr('scenePlaceholder');
};

const pad2 = (n) => String(n).padStart(2, '0');

const formatDateTime = (at) => {
  const d = new Date(at);
  return (
    `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ` +
    `${pad2(d.getHours())}:${pad2(d.getMinutes())}`
  );
};

const appendSceneGroup = (groupId, labelText, items, { custom = false } = {}) => {
  if (!items.length || !sceneList) return;
  const groupLi = document.createElement('li');
  groupLi.className = 'scene-group';
  groupLi.setAttribute('role', 'presentation');

  const label = document.createElement('div');
  label.className = 'scene-group-label';
  label.setAttribute('aria-hidden', 'true');
  label.textContent = labelText;
  groupLi.append(label);

  const sub = document.createElement('ul');
  sub.className = 'scene-group-list';
  sub.setAttribute('role', 'group');
  sub.setAttribute('aria-label', labelText);

  for (const scene of items) {
    const li = document.createElement('li');
    li.setAttribute('role', 'presentation');
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.scene = scene.id;
    if (custom) btn.dataset.custom = '1';
    btn.setAttribute('role', 'option');
    btn.setAttribute('aria-selected', scene.id === activeScene ? 'true' : 'false');
    btn.classList.toggle('active', scene.id === activeScene);
    btn.textContent = custom
      ? `${scene.name} · ${scene.min} ${tr('customUnit')}`
      : tr(scene.labelKey);
    li.append(btn);
    sub.append(li);
  }

  groupLi.append(sub);
  sceneList.append(groupLi);
};

const syncSceneSelect = () => {
  if (!sceneSelect || !sceneTrigger || !sceneList || !sceneTriggerLabel) return;
  sceneSelect.setAttribute('aria-label', tr('scenesLabel'));
  sceneTrigger.setAttribute('aria-label', tr('scenesLabel'));
  sceneList.setAttribute('aria-label', tr('scenesLabel'));

  const profile = resolveSceneProfile(locale);
  const customs = listCustomScenes();
  if (activeScene && isSceneHidden(activeScene, profile) && !getCustomScene(activeScene)) {
    activeScene = null;
    persistTimerSession();
  }

  if (activeScene && (findBuiltInScene(activeScene) || getCustomScene(activeScene))) {
    sceneTriggerLabel.textContent = scenePickerLabel(activeScene);
    sceneTrigger.classList.remove('is-placeholder');
  } else {
    sceneTriggerLabel.textContent = tr('scenePlaceholder');
    sceneTrigger.classList.add('is-placeholder');
  }

  sceneList.replaceChildren();
  const known = new Set([
    ...SCENES.map((s) => s.id),
    ...customs.map((s) => s.id),
  ]);
  const ranked = rankScenes(getSceneSessions(), known);
  const suggested = mergePinnedSuggested(
    ranked,
    profile.pin,
    known,
    SUGGESTED_TOP_N,
    profile.hideScenes
  )
    .map((id) => {
      const builtIn = findBuiltInScene(id);
      if (builtIn) return { ...builtIn, _custom: false };
      const custom = getCustomScene(id);
      if (custom) return { id: custom.id, name: custom.name, min: custom.min, _custom: true };
      return null;
    })
    .filter(Boolean);

  if (suggested.length) {
    const groupLi = document.createElement('li');
    groupLi.className = 'scene-group';
    groupLi.setAttribute('role', 'presentation');
    const label = document.createElement('div');
    label.className = 'scene-group-label';
    label.setAttribute('aria-hidden', 'true');
    label.textContent = tr(SUGGESTED_LABEL_KEY);
    groupLi.append(label);
    const sub = document.createElement('ul');
    sub.className = 'scene-group-list';
    sub.setAttribute('role', 'group');
    sub.setAttribute('aria-label', tr(SUGGESTED_LABEL_KEY));
    for (const scene of suggested) {
      const li = document.createElement('li');
      li.setAttribute('role', 'presentation');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.dataset.scene = scene.id;
      if (scene._custom) btn.dataset.custom = '1';
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-selected', scene.id === activeScene ? 'true' : 'false');
      btn.classList.toggle('active', scene.id === activeScene);
      btn.textContent = scene._custom
        ? `${scene.name} · ${scene.min} ${tr('customUnit')}`
        : tr(scene.labelKey);
      li.append(btn);
      sub.append(li);
    }
    groupLi.append(sub);
    sceneList.append(groupLi);
  }

  appendSceneGroup(CUSTOM_GROUP_ID, tr('sceneGroupCustom'), customs, { custom: true });

  for (const group of orderSceneGroups(SCENE_GROUPS, profile)) {
    const items = SCENES.filter(
      (s) => s.group === group.id && !isSceneHidden(s.id, profile)
    );
    appendSceneGroup(group.id, tr(group.labelKey), items);
  }
};

const syncBrandTitle = () => {
  if (activeScene) {
    const builtIn = findBuiltInScene(activeScene);
    if (builtIn) {
      brandTitle.textContent = tr(builtIn.titleKey);
      return;
    }
    const custom = getCustomScene(activeScene);
    if (custom) {
      brandTitle.textContent = custom.name;
      return;
    }
  }
  brandTitle.textContent = (LOCALES[locale] || LOCALES['zh-CN']).brandTitle;
};

const applyStaticI18n = () => {
  const pack = LOCALES[locale] || LOCALES['zh-CN'];
  document.documentElement.lang = pack.htmlLang;
  // Keep document LTR so chrome matches other locales; Arabic text uses CSS islands.
  document.documentElement.dir = 'ltr';
  document.documentElement.dataset.script = pack.dir === 'rtl' ? 'rtl' : 'ltr';
  syncBrandTitle();
  syncLangSelect();
  stageSection.setAttribute('aria-label', pack.stageLabel);
  actionsSection.setAttribute('aria-label', pack.actionsLabel);
  resetBtn.textContent = pack.reset;
  if (footnote) {
    const links = [
      { href: 'knowledge.html', label: pack.footerKnowledge || '如厕小知识' },
      { href: 'download.html', label: pack.downloadLabel || '下载 App' },
      { href: 'privacy.html', label: pack.footerPrivacy },
      { href: 'terms.html', label: pack.footerTerms },
      { href: 'faq.html', label: pack.footerFaq },
      { href: 'about.html', label: pack.aboutLabel },
    ];
    const frag = document.createDocumentFragment();
    links.forEach((item) => {
      frag.appendChild(
        Object.assign(document.createElement('a'), {
          href: item.href,
          textContent: item.label,
        }),
      );
    });
    footnote.replaceChildren(frag);
  }
  metaDescription?.setAttribute('content', pack.metaDescription);

  syncSceneSelect();
  syncAmbientI18n();
  syncPanelI18n();
  renderDailyStats();
  if (!recordsSheet?.hidden) renderRecordsPanel();
  if (!customScenesSheet?.hidden) renderCustomScenesPanel();
  syncStartLabel();
  if (!titleBlinkId) {
    const suffix = pack.titleSuffix || '';
    document.title = (running || remainMs < totalMs)
      ? (suffix ? `${fmt(remainMs)} · ${suffix}` : fmt(remainMs))
      : pack.titleIdle;
  }
};

const anySheetOpen = () =>
  !(recordsSheet?.hidden ?? true)
  || !(customScenesSheet?.hidden ?? true)
  || !(settingsSheet?.hidden ?? true);

const syncPanelI18n = () => {
  if (recordsBtn) recordsBtn.setAttribute('aria-label', tr('tabRecords'));
  if (settingsBtn) settingsBtn.setAttribute('aria-label', tr('settingsLabel'));
  if (customScenesBtn) customScenesBtn.setAttribute('aria-label', tr('customScenesLabel'));
  if (recordsTitle) recordsTitle.textContent = tr('tabRecords');
  if (settingsTitle) settingsTitle.textContent = tr('settingsTitle') || tr('settingsLabel');
  if (customScenesTitle) customScenesTitle.textContent = tr('customScenesLabel');
  if (settingsLangLabel) settingsLangLabel.textContent = tr('langLabel');
  if (historyFilterLabel) historyFilterLabel.textContent = tr('historyFilterLabel');
  if (historyClearBtn) historyClearBtn.textContent = tr('historyClear');
  if (shareBtn) shareBtn.textContent = tr('shareLabel');
  if (exportBtn) exportBtn.textContent = tr('exportLabel');
  if (customScenesHint) customScenesHint.textContent = tr('customScenesEmptyHint');
  if (customSceneNameLabel) customSceneNameLabel.textContent = tr('customSceneNameLabel');
  if (customSceneMinLabel) customSceneMinLabel.textContent = tr('customSceneMinLabel');
  if (customSceneName) customSceneName.placeholder = tr('customSceneNamePlaceholder');
  if (customSceneSaveBtn) {
    const editing = !!(customSceneEditId && customSceneEditId.value);
    customSceneSaveBtn.textContent = editing ? tr('customSceneEdit') : tr('customSceneAdd');
  }
  if (customSceneCancelBtn) customSceneCancelBtn.textContent = tr('cancelLabel');
  if (recordsClose) recordsClose.setAttribute('aria-label', tr('closeLabel'));
  if (customScenesClose) customScenesClose.setAttribute('aria-label', tr('closeLabel'));
  if (settingsClose) settingsClose.setAttribute('aria-label', tr('closeLabel'));
  syncSettingsI18n();
  if (ritualMask && !ritualMask.hidden) refreshRitualLabels();
};

const fillSelect = (select, options, current) => {
  if (!select) return;
  select.replaceChildren();
  for (const opt of options) {
    const el = document.createElement('option');
    el.value = opt.value;
    el.textContent = opt.label;
    if (opt.value === current) el.selected = true;
    select.appendChild(el);
  }
};

const syncSettingsI18n = () => {
  if (alertProfileLabel) alertProfileLabel.textContent = tr('alertProfileLabel');
  if (alertProfileHint) alertProfileHint.textContent = tr('alertProfileHint');
  fillSelect(alertProfileSelect, [
    { value: p0.PROFILE_NORMAL, label: tr('alertProfileNormal') },
    { value: p0.PROFILE_QUIET, label: tr('alertProfileQuiet') },
    { value: p0.PROFILE_SILENT, label: tr('alertProfileSilent') },
  ], p0.getAlertProfile());

  if (standRitualLabel) standRitualLabel.textContent = tr('standRitualLabel');
  fillSelect(standRitualSelect, [
    { value: p0.RITUAL_OFF, label: tr('standRitualOff') },
    { value: p0.RITUAL_BASIC, label: tr('standRitualBasic') },
  ], p0.getStandRitual());

  if (overtimeInsightPrefLabel) overtimeInsightPrefLabel.textContent = tr('prefOvertimeInsight');
  if (overtimeInsightToggle instanceof HTMLInputElement) {
    overtimeInsightToggle.checked = p0.getShowOvertimeInsight();
  }

  // Web: single row label「数据存储」, skip separate「存储方式」.
  if (storageModeLabel) storageModeLabel.textContent = tr('storageSection');
  if (storageModeHint) storageModeHint.textContent = tr('storageModeHint');
  fillSelect(storageModeSelect, [
    { value: 'local', label: tr('storageModeLocal') },
    { value: 'cloud', label: tr('storageModeCloud') },
  ], prefs.getStorageMode());

  if (storageBackupShowLabel) storageBackupShowLabel.textContent = tr('storageBackupShow');
  else if (storageBackupShowBtn) storageBackupShowBtn.textContent = tr('storageBackupShow');
  if (storageBackupHint) storageBackupHint.textContent = tr('storageBackupHint');
  if (storageBackupCopyBtn) storageBackupCopyBtn.textContent = tr('storageBackupCopy');
  if (storageRestoreLabel) storageRestoreLabel.textContent = tr('storageRestoreLabel');
  if (storageRestoreHint) storageRestoreHint.textContent = tr('storageRestoreHint');
  if (storageRestoreInput) {
    storageRestoreInput.placeholder = tr('storageRestorePlaceholder');
  }
  if (storageRestoreBtn) storageRestoreBtn.textContent = tr('storageRestoreAction');
  syncStorageBackupUi();
};

const setDrawerOpen = (toggleEl, bodyEl, open) => {
  if (toggleEl) toggleEl.setAttribute('aria-expanded', open ? 'true' : 'false');
  if (bodyEl) bodyEl.hidden = !open;
};

const syncStorageBackupUi = () => {
  const cloud = prefs.getStorageMode() === 'cloud';
  // Cloud mode always offers backup UI; credentials are created on first show/enable.
  if (storageBackupBlock) storageBackupBlock.hidden = !cloud;
  if (!cloud) {
    setDrawerOpen(storageBackupShowBtn, storageBackupBody, false);
    if (storageBackupCode) storageBackupCode.textContent = '';
    setBackupStatus('', false);
  }
};

const setRecordsOpen = (open) => {
  if (!recordsSheet || !recordsBtn) return;
  recordsSheet.hidden = !open;
  recordsBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  if (open) {
    setCustomScenesOpen(false);
    setSettingsOpen(false);
    setSceneListOpen(false);
    setAmbientPanelOpen(false);
    renderRecordsPanel();
  }
  document.body.classList.toggle('sheet-open', anySheetOpen());
};

const setCustomScenesOpen = (open) => {
  if (!customScenesSheet) return;
  customScenesSheet.hidden = !open;
  if (customScenesBtn) {
    customScenesBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  }
  if (open) {
    setRecordsOpen(false);
    setSettingsOpen(false);
    setSceneListOpen(false);
    setAmbientPanelOpen(false);
    resetCustomSceneForm();
    renderCustomScenesPanel();
  }
  document.body.classList.toggle('sheet-open', anySheetOpen());
};

const setSettingsOpen = (open) => {
  if (!settingsSheet || !settingsBtn) return;
  settingsSheet.hidden = !open;
  settingsBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
  if (open) {
    setRecordsOpen(false);
    setCustomScenesOpen(false);
    setSceneListOpen(false);
    setAmbientPanelOpen(false);
    syncSettingsI18n();
  }
  document.body.classList.toggle('sheet-open', anySheetOpen());
};

const setStorageStatus = (msg, visible = true) => {
  if (!storageSyncStatus) return;
  storageSyncStatus.hidden = !visible || !msg;
  storageSyncStatus.textContent = msg || '';
};

const setBackupStatus = (msg, visible = true) => {
  if (!storageBackupStatus) return;
  storageBackupStatus.hidden = !visible || !msg;
  storageBackupStatus.textContent = msg || '';
};

const sceneLabelForExport = (row) => {
  const sid = row.sceneId || '';
  if (!sid) return '';
  const builtIn = findBuiltInScene(sid);
  if (builtIn) return tr(builtIn.titleKey);
  const custom = getCustomScene(sid);
  if (custom) return custom.name;
  return sid;
};

const downloadCsv = (text) => {
  const blob = new Blob([text], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `5min-history-${new Date().toISOString().slice(0, 10)}.csv`;
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 1500);
};

const fmtOvertime = (ms) => {
  const total = Math.max(0, Math.floor(ms / 1000));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
};

const commitOvertimeToHistoryIfNeeded = () => {
  if (!inOvertime || overtimeMs <= 0 || !lastRecordedSessionId) return;
  const ot = overtimeMs;
  updateSessionElapsed(lastRecordedSessionId, totalMs + overtimeMs);
  p0.recordOvertime(ot);
  renderDailyStats();
};

const clearOvertimeState = () => {
  inOvertime = false;
  overtimeAt = 0;
  overtimeMs = 0;
};

const refreshRitualLabels = () => {
  const scene = findBuiltInScene(activeScene || '');
  const group = scene?.group || (getCustomScene(activeScene || '') ? CUSTOM_GROUP_ID : '');
  const pack = p0.resolveRitualPack(activeScene || '', group);
  const steps = pack.stepKeys || [];
  if (ritualTitle) ritualTitle.textContent = tr(pack.titleKey || 'standRitualTitle');
  if (ritualStep0) ritualStep0.textContent = tr(steps[0] || 'standRitualStepUp');
  if (ritualStep1) ritualStep1.textContent = tr(steps[1] || 'standRitualStepStretch');
  if (ritualStep2) ritualStep2.textContent = tr(steps[2] || 'standRitualStepLeave');
  if (ritualSkip) ritualSkip.textContent = tr('standRitualSkip');
  if (ritualDone) ritualDone.textContent = tr('standRitualDone');
};

const maybeShowRitual = () => {
  if (p0.getStandRitual() !== p0.RITUAL_BASIC || !ritualMask) return;
  ritualChecks = [false, false, false];
  refreshRitualLabels();
  for (const btn of ritualMask.querySelectorAll('.ritual-step')) {
    btn.classList.remove('is-on');
  }
  ritualMask.hidden = false;
};

const dismissRitual = () => {
  if (ritualMask) ritualMask.hidden = true;
};

const showShareToast = (msg) => {
  if (!shareToast) return;
  shareToast.hidden = false;
  shareToast.textContent = msg;
  if (shareToastTimer) clearTimeout(shareToastTimer);
  shareToastTimer = window.setTimeout(() => {
    shareToast.hidden = true;
    shareToast.textContent = '';
  }, 2200);
};

const renderOvertimeInsight = () => {
  if (!overtimeInsightEl) return;
  if (!p0.getShowOvertimeInsight()) {
    overtimeInsightEl.hidden = true;
    return;
  }
  const stats = p0.readOvertimeStats();
  overtimeInsightEl.hidden = false;
  if (overtimeInsightTitle) overtimeInsightTitle.textContent = tr('overtimeInsightTitle');
  if (overtimeInsightHint) {
    overtimeInsightHint.textContent = stats.count > 0
      ? tr('overtimeInsightTip')
      : tr('overtimeInsightHint');
  }
  if (overtimeInsightLine) {
    overtimeInsightLine.textContent = stats.count > 0
      ? tr('overtimeInsightLine', {
        count: String(stats.count),
        mins: String(p0.insightMinutes(stats.ms)),
      })
      : tr('overtimeInsightEmpty');
  }
};

const renderRecordsPanel = () => {
  if (!recordsPeriod || !recordsStreak || !historyList) return;
  const all = getHistory();
  let periodMins = 0;
  for (let i = 0; i < all.length; i += 1) periodMins += all[i].minutes;
  const streak = getStreak(all);

  renderOvertimeInsight();

  recordsPeriod.replaceChildren();
  const periodLabel = document.createElement('span');
  periodLabel.textContent = tr('weekStatsLabel');
  const periodVals = document.createElement('strong');
  if (all.length <= 0) {
    periodVals.textContent = tr('weekStatsEmpty');
  } else {
    periodVals.textContent = tr('weekStatsText', {
      count: String(all.length),
      mins: String(periodMins),
    });
  }
  recordsPeriod.append(periodLabel, periodVals);

  recordsStreak.replaceChildren();
  const streakLabel = document.createElement('span');
  streakLabel.textContent = tr('streakLabel');
  const streakVals = document.createElement('strong');
  streakVals.textContent = streak > 0
    ? tr('streakDays', { n: String(streak) })
    : tr('streakNone');
  recordsStreak.append(streakLabel, streakVals);

  if (historyFilter) {
    const seen = new Set();
    historyFilter.replaceChildren();
    const optAll = document.createElement('option');
    optAll.value = '';
    optAll.textContent = tr('historyFilterAll');
    historyFilter.append(optAll);
    for (const row of all) {
      const sid = row.sceneId;
      if (!sid || seen.has(sid)) continue;
      seen.add(sid);
      const opt = document.createElement('option');
      opt.value = sid;
      opt.textContent = resolveSceneTitle(sid);
      historyFilter.append(opt);
    }
    historyFilter.value = historyFilterSceneId;
    if (historyFilter.value !== historyFilterSceneId) {
      historyFilterSceneId = '';
      historyFilter.value = '';
    }
  }

  const rows = historyFilterSceneId
    ? all.filter((row) => row.sceneId === historyFilterSceneId)
    : all;
  historyList.replaceChildren();
  if (historyEmptyHint) {
    historyEmptyHint.hidden = rows.length > 0;
    historyEmptyHint.textContent = tr('historyEmpty');
  }
  for (const row of rows) {
    const li = document.createElement('li');
    li.className = 'history-item';
    const body = document.createElement('div');
    body.className = 'history-item-body';
    const sceneEl = document.createElement('div');
    sceneEl.className = 'history-item-scene';
    sceneEl.textContent = resolveSceneTitle(row.sceneId);
    const meta = document.createElement('div');
    meta.className = 'history-item-meta';
    meta.textContent = `${tr('historyDurationLine', { n: String(row.minutes) })} · ${tr('historyTimeLine', { time: formatDateTime(row.at) })}`;
    body.append(sceneEl, meta);
    const actions = document.createElement('div');
    actions.className = 'history-item-actions';
    const del = document.createElement('button');
    del.type = 'button';
    del.dataset.historyDelete = row.id;
    del.textContent = tr('historyDelete');
    actions.append(del);
    li.append(body, actions);
    historyList.append(li);
  }
};

const resetCustomSceneForm = () => {
  if (customSceneEditId) customSceneEditId.value = '';
  if (customSceneName) customSceneName.value = '';
  if (customSceneMin) customSceneMin.value = '5';
  if (customSceneCancelBtn) customSceneCancelBtn.hidden = true;
  if (customSceneSaveBtn) customSceneSaveBtn.textContent = tr('customSceneAdd');
};

const renderCustomScenesPanel = () => {
  if (!customSceneList) return;
  const scenes = listCustomScenes();
  customSceneList.replaceChildren();
  if (customScenesHint) {
    customScenesHint.textContent = scenes.length
      ? tr('customScenesCount', { n: String(scenes.length) })
      : tr('customScenesEmptyHint');
  }
  for (const scene of scenes) {
    const li = document.createElement('li');
    li.className = 'custom-scene-item';
    const body = document.createElement('div');
    body.className = 'custom-scene-item-body';
    const nameEl = document.createElement('div');
    nameEl.className = 'custom-scene-item-name';
    nameEl.textContent = scene.name;
    const meta = document.createElement('div');
    meta.className = 'custom-scene-item-meta';
    meta.textContent = `${scene.min} ${tr('customUnit')}`;
    body.append(nameEl, meta);
    const actions = document.createElement('div');
    actions.className = 'custom-scene-item-actions';
    const useBtn = document.createElement('button');
    useBtn.type = 'button';
    useBtn.dataset.customUse = scene.id;
    useBtn.textContent = tr('customSceneUse');
    const editBtn = document.createElement('button');
    editBtn.type = 'button';
    editBtn.dataset.customEdit = scene.id;
    editBtn.textContent = tr('customSceneEdit');
    const delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.dataset.customDelete = scene.id;
    delBtn.textContent = tr('historyDelete');
    actions.append(useBtn, editBtn, delBtn);
    li.append(body, actions);
    customSceneList.append(li);
  }
  if (customSceneSaveBtn && listCustomScenes().length >= CUSTOM_MAX_COUNT && !(customSceneEditId?.value)) {
    customSceneSaveBtn.disabled = true;
  } else if (customSceneSaveBtn) {
    customSceneSaveBtn.disabled = false;
  }
};

const syncLangSelect = () => {
  if (!settingsLocaleSelect) return;
  fillSelect(
    settingsLocaleSelect,
    LOCALE_CODES.map((code) => ({
      value: code,
      label: LOCALE_NATIVE_NAMES[code] ?? code,
    })),
    locale,
  );
};

const setLocale = async (next) => {
  const resolved = resolveLocale(next) ?? locale;
  await ensureLocale(resolved);
  locale = resolved;
  try { localStorage.setItem(STORAGE_KEY, locale); } catch { /* ignore */ }
  prefs.setLocale(locale);
  applyStaticI18n();
  render();
  schedulePrefsPush();
};

const stopTitleBlink = () => {
  if (!titleBlinkId) return;
  clearInterval(titleBlinkId);
  titleBlinkId = 0;
};

/** Scene/group finish tip key; null when no scene (generic copy). */
const resolveDoneTipKey = (sceneId = activeScene) => {
  if (!sceneId) return null;
  const scene = SCENES.find((s) => s.id === sceneId);
  if (scene?.doneKey) return scene.doneKey;
  if (scene?.group) {
    const group = SCENE_GROUPS.find((g) => g.id === scene.group);
    if (group?.doneKey) return group.doneKey;
  }
  return null;
};

const statusDoneText = () => {
  const tipKey = resolveDoneTipKey();
  return tipKey ? tr('statusDoneTip', { tip: tr(tipKey) }) : tr('statusDone');
};

const titleDoneBlinkText = () => {
  const tipKey = resolveDoneTipKey();
  return tipKey ? tr('titleDoneBlinkTip', { tip: tr(tipKey) }) : tr('titleDoneBlink');
};

const notifyBodyText = (vars) => {
  const tipKey = resolveDoneTipKey();
  return tipKey
    ? tr('notifyBodyTip', { ...vars, tip: tr(tipKey) })
    : tr('notifyBody', vars);
};

const startTitleBlink = () => {
  stopTitleBlink();
  let flip = false;
  titleBlinkId = window.setInterval(() => {
    document.title = flip
      ? titleDoneBlinkText()
      : tr('titleDoneZero', { n: String(sessionMinutes()) });
    flip = !flip;
  }, 800);
};

const sessionMinutes = () => Math.max(1, Math.round(totalMs / 60_000));

/** Scene title for finish notify; generic brand when no scene selected. */
const notifySceneName = () => {
  if (activeScene) {
    const builtIn = findBuiltInScene(activeScene);
    if (builtIn) return tr(builtIn.titleKey);
    const custom = getCustomScene(activeScene);
    if (custom) return custom.name;
  }
  return tr('brandTitle');
};

const maybeNotify = () => {
  if (!('Notification' in globalThis)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const vars = { n: String(sessionMinutes()), scene: notifySceneName() };
    const n = new Notification(tr('notifyTitle', vars), {
      body: notifyBodyText(vars),
      icon: 'img/logo.png',
      tag: '5min-timer',
      renotify: true,
      silent: false,
      vibrate: getVibratePattern(),
    });
    n.addEventListener('click', () => {
      globalThis.focus();
      void realertFromGesture();
      n.close();
    });
    window.setTimeout(() => n.close(), 10_000);
  } catch {
    /* ignore */
  }
};

const requestNotifyOnce = async () => {
  if (notifyAsked || !('Notification' in globalThis)) return;
  if (Notification.permission !== 'default') return;
  notifyAsked = true;
  try { await Notification.requestPermission(); } catch { /* ignore */ }
};

/** Fire sound + vibration (+ notification). Honors alert profile + finish prefs. */
const fireFinishAlert = () => {
  needAlertOnVisible = document.visibilityState !== 'visible';
  const alerts = p0.resolveFinishAlerts(prefs);
  alertFinish({
    notify: maybeNotify,
    withTone: alerts.withTone,
    withVibrate: alerts.withVibrate,
    withNotify: alerts.withNotify,
  });
};

const acquireWakeLock = async () => {
  if (!('wakeLock' in navigator)) return;
  try {
    wakeLock = await navigator.wakeLock.request('screen');
    wakeLock.addEventListener('release', () => { wakeLock = null; }, { once: true });
  } catch {
    wakeLock = null;
  }
};

const releaseWakeLock = async () => {
  if (!wakeLock) return;
  try { await wakeLock.release(); } catch { /* ignore */ }
  wakeLock = null;
};

const setSetupEnabled = (enabled) => {
  if (sceneTrigger) sceneTrigger.disabled = !enabled;
  if (!enabled) setSceneListOpen(false);
};

const syncSceneUi = () => {
  syncSceneSelect();
  syncBrandTitle();
};

const setTone = (tone) => {
  document.body.classList.toggle('warn', tone === 'warn');
  document.body.classList.toggle('danger', tone === 'danger');
  progress.classList.toggle('is-safe', tone === 'safe');
  progress.classList.toggle('is-warn', tone === 'warn');
  progress.classList.toggle('is-danger', tone === 'danger');
  if (noticeEl) noticeEl.dataset.tone = tone;
};

const render = () => {
  // Overtime keeps ticking in status / session stats; dial stays at 00:00 (no "+").
  const clock = inOvertime ? fmt(0) : fmt(remainMs);
  if (clock !== lastDialClock) {
    lastDialClock = clock;
    timeLabel.textContent = clock;
    timeText.innerHTML = digitalWatchSvg(clock);
  }
  timeText.classList.toggle('is-running', !!running);
  const ratio = inOvertime
    ? 0
    : (totalMs > 0 ? Math.min(1, Math.max(0, remainMs / totalMs)) : 0);
  progress.style.strokeDashoffset = String(CIRC * (1 - ratio));

  if (!titleBlinkId) {
    const suffix = tr('titleSuffix') || '';
    document.title = (running || remainMs < totalMs || inOvertime)
      ? (suffix ? `${clock} · ${suffix}` : clock)
      : tr('titleIdle');
  }

  if (inOvertime) {
    setTone('danger');
    statusEl.textContent = tr('statusOvertime', { n: fmtOvertime(overtimeMs) });
  } else if (finished) {
    setTone('danger');
    statusEl.textContent = statusDoneText();
  } else if (remainMs <= 60_000 && (running || remainMs < totalMs)) {
    setTone('warn');
    statusEl.textContent = tr('statusWarn');
  } else {
    setTone('safe');
    if (running) statusEl.textContent = tr('statusRunning');
    else if (remainMs < totalMs) statusEl.textContent = tr('statusPaused');
    else statusEl.textContent = tr('statusIdle');
  }

  syncStartLabel();
};

const clearTick = () => {
  if (!tickId) return;
  clearTimeout(tickId);
  tickId = 0;
};

const scheduleTick = () => {
  clearTick();
  if (inOvertime) {
    tickId = window.setTimeout(tick, 200);
    return;
  }
  if (!running) return;
  const delay = Math.max(16, remainMs % 1000 || 1000);
  tickId = window.setTimeout(tick, delay);
};

const tick = () => {
  if (inOvertime) {
    overtimeMs = Math.max(0, Date.now() - overtimeAt);
    render();
    scheduleTick();
    return;
  }
  if (!running) return;
  remainMs = endAt - Date.now();
  if (remainMs <= 0) {
    remainMs = 0;
    finish();
    return;
  }
  render();
  scheduleTick();
};

const finish = () => {
  running = false;
  finished = true;
  clearTick();
  const rec = recordCompletedSession(totalMs, activeScene || '');
  lastRecordedSessionId = rec.sessionId || '';
  renderDailyStats();
  inOvertime = true;
  overtimeAt = Date.now();
  overtimeMs = 0;
  render();
  startBtn.disabled = false;
  resetBtn.disabled = false;
  setSetupEnabled(true);
  // Sound/haptic first — releasing wake lock can briefly alter visibility on some devices.
  fireFinishAlert();
  stopAudioKeepAlive();
  releaseWakeLock();
  startTitleBlink();
  maybeShowRitual();
  scheduleTick();
  persistTimerSession();
  if (prefs.getStorageMode() === 'cloud') {
    void cloudSync.pushSessionsOnly().catch(() => {});
  }
};

const start = () => {
  if (running) {
    running = false;
    clearTick();
    stopAudioKeepAlive();
    clearAlerts();
    remainMs = Math.max(0, endAt - Date.now());
    endAt = 0;
    releaseWakeLock();
    setSetupEnabled(true);
    render();
    persistTimerSession();
    return;
  }

  stopTitleBlink();
  clearAlerts();
  needAlertOnVisible = false;
  dismissRitual();
  if (finished || inOvertime) {
    commitOvertimeToHistoryIfNeeded();
    clearOvertimeState();
    lastRecordedSessionId = '';
  }
  requestNotifyOnce();
  // Must unlock inside this click gesture (iOS / Android / HarmonyOS autoplay).
  void unlockAlertAudio();
  startAudioKeepAlive();

  if (remainMs <= 0 || finished) {
    remainMs = totalMs;
    finished = false;
  }

  endAt = Date.now() + remainMs;
  running = true;
  finished = false;
  resetBtn.disabled = false;
  setSetupEnabled(false);
  render();
  scheduleTick();
  acquireWakeLock();
  persistTimerSession();
};

const reset = () => {
  commitOvertimeToHistoryIfNeeded();
  clearOvertimeState();
  lastRecordedSessionId = '';
  dismissRitual();
  running = false;
  finished = false;
  endAt = 0;
  clearTick();
  clearAlerts();
  needAlertOnVisible = false;
  stopTitleBlink();
  releaseWakeLock();
  remainMs = totalMs;
  startBtn.disabled = false;
  resetBtn.disabled = true;
  setSetupEnabled(true);
  render();
  clearTimerSession();
};

const setPreset = (min, sceneId = null) => {
  if (!Number.isFinite(min) || min <= 0 || running) return;
  totalMs = min * 60 * 1000;
  activeScene = sceneId;
  syncSceneUi();
  reset();
  // Idle preset after reset: keep a lightweight session so scene survives same-tab return.
  persistTimerSession();
};

const setAmbientPanelOpen = (open) => {
  if (!ambientBtn || !ambientPanel) return;
  ambientPanel.hidden = !open;
  ambientBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
};

const syncAmbientUi = () => {
  if (!ambientBtn || !ambientPanel) return;
  const current = getAmbientMode();
  const on = current !== 'off';
  ambientBtn.classList.toggle('is-on', on);
  ambientBtn.classList.toggle('is-muted', !on);
  for (const btn of ambientPanel.querySelectorAll('button[data-ambient]')) {
    btn.classList.toggle('active', btn.dataset.ambient === current);
  }
};

void (async () => {
  await ensureLocale(locale);
  prefs.setLocale(locale);
  applyStaticI18n();
  // URL ?sec= wins over a previous same-tab session.
  const restored = bootSec <= 0 && restoreTimerSession();
  if (restored) {
    syncSceneUi();
    resetBtn.disabled = !(running || finished || remainMs < totalMs || inOvertime);
    setSetupEnabled(!running);
    if (running) {
      scheduleTick();
      acquireWakeLock();
      startAudioKeepAlive();
    } else if (finished) {
      startTitleBlink();
    }
  } else if (bootSec <= 0) {
    // 默认场景：如厕 · 5 分钟（URL ?sec= 自定义秒数时不覆盖）
    setPreset(5, 'toilet');
  } else {
    syncSceneUi();
  }
  syncAmbientUi();
  renderDailyStats();
  render();
  if (prefs.getStorageMode() === 'cloud') {
    void cloudSync.syncNow({
      onLocale: (code) => {
        if (code && code !== locale) void setLocale(code);
      },
    }).then(() => {
      renderDailyStats();
      if (!recordsSheet?.hidden) renderRecordsPanel();
    }).catch(() => {});
  }
})();

/* pointerdown：尽早占用用户手势，提升 iOS / 部分 WebView 音频解锁成功率 */
startBtn.addEventListener('pointerdown', () => {
  void unlockAlertAudio();
});
startBtn.addEventListener('click', start);
resetBtn.addEventListener('click', reset);

sceneTrigger?.addEventListener('click', (event) => {
  event.stopPropagation();
  if (sceneTrigger.disabled) return;
  const open = sceneList?.hidden !== false;
  setAmbientPanelOpen(false);
  setSceneListOpen(open);
});

sceneList?.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-scene]');
  if (!(btn instanceof HTMLButtonElement) || btn.disabled) return;
  const id = btn.dataset.scene || '';
  const builtIn = findBuiltInScene(id);
  if (builtIn) {
    setPreset(builtIn.min, builtIn.id);
    setSceneListOpen(false);
    return;
  }
  const custom = getCustomScene(id);
  if (!custom) return;
  setPreset(custom.min, custom.id);
  setSceneListOpen(false);
});

recordsBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  setRecordsOpen(!!recordsSheet?.hidden);
});

recordsClose?.addEventListener('click', () => setRecordsOpen(false));

settingsLocaleSelect?.addEventListener('change', () => {
  void setLocale(settingsLocaleSelect.value);
});

customScenesBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  setCustomScenesOpen(!!customScenesSheet?.hidden);
});

customScenesClose?.addEventListener('click', () => setCustomScenesOpen(false));

historyFilter?.addEventListener('change', () => {
  historyFilterSceneId = historyFilter.value || '';
  renderRecordsPanel();
});

historyClearBtn?.addEventListener('click', () => {
  void (async () => {
    if (!(await showConfirm(tr('historyClearConfirm')))) return;
    clearHistory();
    renderRecordsPanel();
    renderDailyStats();
    if (prefs.getStorageMode() === 'cloud') {
      void cloudSync.clearRemoteSessions().catch(() => {});
    }
  })();
});

historyList?.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-history-delete]');
  if (!(btn instanceof HTMLButtonElement)) return;
  const id = btn.dataset.historyDelete || '';
  void (async () => {
    if (!(await showConfirm(tr('historyDeleteConfirm')))) return;
    deleteSession(id);
    renderRecordsPanel();
    renderDailyStats();
    if (prefs.getStorageMode() === 'cloud' && id) {
      void cloudSync.deleteRemoteSession(id).catch(() => {});
    }
  })();
});

shareBtn?.addEventListener('click', () => {
  void (async () => {
    const summary = shareSummaryValues();
    const title = tr('shareLabel');
    const text = tr('shareText', {
      count: String(summary.count),
      mins: String(summary.minutes),
      streak: String(summary.streak),
    });
    const result = await shareSummary({ title, text, brand: '5min.chat' });
    if (result === 'copied') showShareToast(tr('shareCopied'));
    else if (result === 'failed') showShareToast(tr('shareFailed'));
  })();
});

exportBtn?.addEventListener('click', () => {
  try {
    const csv = exportHistoryCsv(sceneLabelForExport, tr('exportCsvHeader'));
    downloadCsv(csv);
    showShareToast(tr('exportDone'));
  } catch {
    showShareToast(tr('exportFailed'));
  }
});

settingsBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  setSettingsOpen(!!settingsSheet?.hidden);
});
settingsClose?.addEventListener('click', () => setSettingsOpen(false));

alertProfileSelect?.addEventListener('change', () => {
  p0.setAlertProfile(alertProfileSelect.value);
  schedulePrefsPush();
});

standRitualSelect?.addEventListener('change', () => {
  p0.setStandRitual(standRitualSelect.value);
  schedulePrefsPush();
});

overtimeInsightToggle?.addEventListener('change', () => {
  if (!(overtimeInsightToggle instanceof HTMLInputElement)) return;
  p0.setShowOvertimeInsight(overtimeInsightToggle.checked);
  schedulePrefsPush();
  if (!recordsSheet?.hidden) renderOvertimeInsight();
});

storageModeSelect?.addEventListener('change', () => {
  void (async () => {
    const next = storageModeSelect.value === 'cloud' ? 'cloud' : 'local';
    if (next === prefs.getStorageMode()) return;
    if (next === 'cloud') {
      if (!(await showConfirm(tr('storageCloudConfirm')))) {
        storageModeSelect.value = 'local';
        return;
      }
      setStorageStatus(tr('storageSyncing'));
      try {
        await cloudSync.enableCloud({
          onLocale: (code) => {
            if (code && code !== locale) void setLocale(code);
          },
        });
        setStorageStatus(tr('storageSyncOk'));
        syncStorageBackupUi();
        cloudSync.ensureDeviceCredentials();
        const code = prefs.formatRecoveryCode();
        if (storageBackupCode && code) {
          storageBackupCode.textContent = code;
          setDrawerOpen(storageBackupShowBtn, storageBackupBody, true);
        }
        renderDailyStats();
      } catch (err) {
        storageModeSelect.value = 'local';
        const msg = err && err.message ? String(err.message) : '';
        setStorageStatus(msg && msg !== 'network' ? msg : tr('storageSyncFail'));
        syncStorageBackupUi();
      }
      return;
    }
    cloudSync.disableCloud();
    setStorageStatus('', false);
    syncStorageBackupUi();
  })();
});

storageBackupShowBtn?.addEventListener('click', () => {
  if (prefs.getStorageMode() !== 'cloud') {
    setStorageStatus(tr('storageModeHint'));
    return;
  }
  const open = storageBackupShowBtn.getAttribute('aria-expanded') === 'true';
  if (open) {
    setDrawerOpen(storageBackupShowBtn, storageBackupBody, false);
    setBackupStatus('', false);
    return;
  }
  cloudSync.ensureDeviceCredentials();
  const code = prefs.formatRecoveryCode();
  if (!code || !storageBackupCode) {
    setStorageStatus(tr('storageRestoreFail'));
    return;
  }
  storageBackupCode.textContent = code;
  setBackupStatus('', false);
  setDrawerOpen(storageBackupShowBtn, storageBackupBody, true);
});

storageBackupCopyBtn?.addEventListener('click', () => {
  void (async () => {
    const code = prefs.formatRecoveryCode();
    if (!code) return;
    try {
      await navigator.clipboard.writeText(code);
      setBackupStatus(tr('storageBackupCopied'));
    } catch {
      setBackupStatus(tr('exportFailed'));
    }
  })();
});

storageRestoreToggle?.addEventListener('click', () => {
  const open = storageRestoreToggle.getAttribute('aria-expanded') === 'true';
  setDrawerOpen(storageRestoreToggle, storageRestoreBody, !open);
});

storageRestoreBtn?.addEventListener('click', () => {
  void (async () => {
    const raw = storageRestoreInput?.value || '';
    if (!prefs.parseRecoveryCode(raw)) {
      setStorageStatus(tr('storageRestoreInvalid'));
      return;
    }
    setStorageStatus(tr('storageSyncing'));
    try {
      await cloudSync.restoreWithCode(raw, {
        onLocale: (code) => {
          if (code && code !== locale) void setLocale(code);
        },
      });
      if (storageModeSelect) storageModeSelect.value = 'cloud';
      setStorageStatus(tr('storageRestoreOk'));
      if (storageRestoreInput) storageRestoreInput.value = '';
      setDrawerOpen(storageRestoreToggle, storageRestoreBody, false);
      syncStorageBackupUi();
      renderDailyStats();
      if (!recordsSheet?.hidden) renderRecordsPanel();
    } catch (e) {
      if (e && e.code === 'invalid') setStorageStatus(tr('storageRestoreInvalid'));
      else setStorageStatus(tr('storageRestoreFail'));
      if (storageModeSelect) storageModeSelect.value = prefs.getStorageMode();
      syncStorageBackupUi();
    }
  })();
});

ritualMask?.addEventListener('click', (event) => {
  const stepBtn = event.target.closest('[data-ritual-step]');
  if (stepBtn instanceof HTMLElement) {
    const idx = Number(stepBtn.dataset.ritualStep);
    if (idx >= 0 && idx <= 2) {
      ritualChecks[idx] = !ritualChecks[idx];
      stepBtn.classList.toggle('is-on', ritualChecks[idx]);
    }
    return;
  }
});

ritualSkip?.addEventListener('click', () => dismissRitual());
ritualDone?.addEventListener('click', () => dismissRitual());

confirmCancel?.addEventListener('click', () => closeConfirm(false));
confirmOk?.addEventListener('click', () => closeConfirm(true));

customSceneList?.addEventListener('click', (event) => {
  const useBtn = event.target.closest('button[data-custom-use]');
  if (useBtn instanceof HTMLButtonElement) {
    const scene = getCustomScene(useBtn.dataset.customUse || '');
    if (!scene || running) return;
    setPreset(scene.min, scene.id);
    setCustomScenesOpen(false);
    return;
  }
  const editBtn = event.target.closest('button[data-custom-edit]');
  if (editBtn instanceof HTMLButtonElement) {
    const scene = getCustomScene(editBtn.dataset.customEdit || '');
    if (!scene) return;
    if (customSceneEditId) customSceneEditId.value = scene.id;
    if (customSceneName) customSceneName.value = scene.name;
    if (customSceneMin) customSceneMin.value = String(scene.min);
    if (customSceneCancelBtn) customSceneCancelBtn.hidden = false;
    if (customSceneSaveBtn) {
      customSceneSaveBtn.textContent = tr('customSceneEdit');
      customSceneSaveBtn.disabled = false;
    }
    customSceneName?.focus();
    return;
  }
  const delBtn = event.target.closest('button[data-custom-delete]');
  if (!(delBtn instanceof HTMLButtonElement)) return;
  const id = delBtn.dataset.customDelete || '';
  void (async () => {
    if (!(await showConfirm(tr('customSceneDeleteConfirm')))) return;
    deleteCustomScene(id);
    if (activeScene === id) {
      activeScene = null;
      persistTimerSession();
      syncSceneUi();
    }
    if (customSceneEditId?.value === id) resetCustomSceneForm();
    renderCustomScenesPanel();
    syncSceneSelect();
  })();
});

customSceneForm?.addEventListener('submit', (event) => {
  event.preventDefault();
  const name = sanitizeName(customSceneName?.value || '');
  const min = clampMinutes(customSceneMin?.value || 5);
  if (!name) {
    customSceneName?.focus();
    return;
  }
  const editId = customSceneEditId?.value || '';
  if (editId) {
    updateCustomScene(editId, name, min);
  } else {
    if (listCustomScenes().length >= CUSTOM_MAX_COUNT) return;
    addCustomScene(name, min);
  }
  resetCustomSceneForm();
  renderCustomScenesPanel();
  syncSceneSelect();
});

customSceneCancelBtn?.addEventListener('click', () => {
  resetCustomSceneForm();
});

customSceneName?.addEventListener('input', () => {
  if (!(customSceneName instanceof HTMLInputElement)) return;
  const cleaned = sanitizeName(customSceneName.value);
  if (cleaned !== customSceneName.value && customSceneName.value.length > CUSTOM_MAX_NAME) {
    customSceneName.value = cleaned;
  }
});

ambientBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  const open = ambientPanel?.hidden !== false;
  setSceneListOpen(false);
  setAmbientPanelOpen(open);
});

ambientPanel?.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-ambient]');
  if (!(btn instanceof HTMLButtonElement)) return;
  const next = btn.dataset.ambient;
  void (async () => {
    if (next === 'off') stopAmbient();
    else await setAmbientMode(/** @type {'rain'|'waves'|'clock'} */ (next));
    syncAmbientUi();
    setAmbientPanelOpen(false);
  })();
});

document.addEventListener('pointerdown', (event) => {
  const target = event.target;
  if (!(target instanceof Node)) return;
  if (ambientWrap && ambientPanel && !ambientPanel.hidden && !ambientWrap.contains(target)) {
    setAmbientPanelOpen(false);
  }
  if (sceneSelect && sceneList && !sceneList.hidden && !sceneSelect.contains(target)) {
    setSceneListOpen(false);
  }
});

/* 结束后轻触表盘可再次触发振动与提示音（用户手势；iOS 无 Vibration API 时依赖声音） */
stageSection.addEventListener('pointerup', () => {
  if (!finished && !inOvertime) return;
  needAlertOnVisible = false;
  const alerts = p0.resolveFinishAlerts(prefs);
  if (!alerts.withTone && !alerts.withVibrate) return;
  void realertFromGesture();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    if (confirmMask && !confirmMask.hidden) {
      closeConfirm(false);
      return;
    }
    setSceneListOpen(false);
    setAmbientPanelOpen(false);
    setRecordsOpen(false);
    setCustomScenesOpen(false);
    setSettingsOpen(false);
    dismissRitual();
    return;
  }
  if (event.code !== 'Space' && event.key !== ' ') return;
  const tag = event.target instanceof Element ? event.target.tagName : '';
  if (['INPUT', 'TEXTAREA', 'BUTTON', 'SELECT'].includes(tag)) return;
  if (event.target instanceof HTMLElement && event.target.isContentEditable) return;
  event.preventDefault();
  start();
});

document.addEventListener('visibilitychange', () => {
  if (document.visibilityState !== 'visible') {
    persistTimerSession();
    suspendAmbient();
    return;
  }
  void resumeAmbient();
  if (running) {
    remainMs = endAt - Date.now();
    if (remainMs <= 0) {
      remainMs = 0;
      finish();
    } else {
      render();
      scheduleTick();
      acquireWakeLock();
      // Re-arm audio while still timing (lock screen often suspends AudioContext).
      void unlockAlertAudio();
      startAudioKeepAlive();
      persistTimerSession();
    }
    return;
  }
  if (inOvertime) {
    overtimeMs = Math.max(0, Date.now() - overtimeAt);
    render();
    scheduleTick();
  }
  if (!finished) return;
  if (needAlertOnVisible) {
    needAlertOnVisible = false;
    const alerts = p0.resolveFinishAlerts(prefs);
    if (alerts.withTone || alerts.withVibrate) alertOnVisible();
  }
  startTitleBlink();
});

window.addEventListener('pagehide', () => {
  persistTimerSession();
});

window.addEventListener('beforeunload', (event) => {
  persistTimerSession();
  // Warn when leaving mid-session (running or paused progress), same-tab footer nav included.
  if (!running && !(remainMs < totalMs && remainMs > 0 && !finished)) return;
  event.preventDefault();
  event.returnValue = '';
});

render();
