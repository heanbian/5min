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
  recordCompletedSession,
  statsMinutes,
} from './stats.js';
import {
  getAmbientMode,
  setAmbientMode,
  stopAmbient,
  suspendAmbient,
  resumeAmbient,
} from './ambient.js';

const CIRC = 2 * Math.PI * 54;
const SCENE_GROUPS = Object.freeze([
  { id: 'daily', labelKey: 'sceneGroupDaily' },
  { id: 'kitchen', labelKey: 'sceneGroupKitchen', doneKey: 'doneTipKitchen' },
  { id: 'care', labelKey: 'sceneGroupCare', doneKey: 'doneTipCare' },
  { id: 'rest', labelKey: 'sceneGroupRest', doneKey: 'doneTipRest' },
  { id: 'study', labelKey: 'sceneGroupStudy', doneKey: 'doneTipStudy' },
  { id: 'work', labelKey: 'sceneGroupWork', doneKey: 'doneTipWork' },
  { id: 'labor', labelKey: 'sceneGroupLabor', doneKey: 'doneTipLabor' },
  { id: 'farm', labelKey: 'sceneGroupFarm', doneKey: 'doneTipFarm' },
  { id: 'chores', labelKey: 'sceneGroupChores', doneKey: 'doneTipChores' },
]);

const SCENES = Object.freeze([
  { id: 'brush', min: 3, group: 'daily', labelKey: 'sceneBrush', titleKey: 'sceneBrushTitle', doneKey: 'doneTipBrush' },
  { id: 'toilet', min: 5, group: 'daily', labelKey: 'sceneToilet', titleKey: 'sceneToiletTitle', doneKey: 'doneTipToilet' },
  { id: 'lazy5', min: 5, group: 'daily', labelKey: 'sceneLazy5', titleKey: 'sceneLazy5Title', doneKey: 'doneTipBreak' },
  { id: 'lazy10', min: 10, group: 'daily', labelKey: 'sceneLazy10', titleKey: 'sceneLazy10Title', doneKey: 'doneTipBreak' },
  { id: 'smoke', min: 5, group: 'daily', labelKey: 'sceneSmoke', titleKey: 'sceneSmokeTitle', doneKey: 'doneTipBreak' },
  { id: 'noodles', min: 3, group: 'kitchen', labelKey: 'sceneNoodles', titleKey: 'sceneNoodlesTitle' },
  { id: 'microwave', min: 3, group: 'kitchen', labelKey: 'sceneMicrowave', titleKey: 'sceneMicrowaveTitle' },
  { id: 'tea', min: 5, group: 'kitchen', labelKey: 'sceneTea', titleKey: 'sceneTeaTitle' },
  { id: 'coffee', min: 5, group: 'kitchen', labelKey: 'sceneCoffee', titleKey: 'sceneCoffeeTitle' },
  { id: 'water', min: 5, group: 'kitchen', labelKey: 'sceneWater', titleKey: 'sceneWaterTitle' },
  { id: 'egg', min: 8, group: 'kitchen', labelKey: 'sceneEgg', titleKey: 'sceneEggTitle' },
  { id: 'pasta', min: 10, group: 'kitchen', labelKey: 'scenePasta', titleKey: 'scenePastaTitle' },
  { id: 'oven', min: 15, group: 'kitchen', labelKey: 'sceneOven', titleKey: 'sceneOvenTitle' },
  { id: 'rice', min: 30, group: 'kitchen', labelKey: 'sceneRice', titleKey: 'sceneRiceTitle' },
  { id: 'stew', min: 40, group: 'kitchen', labelKey: 'sceneStew', titleKey: 'sceneStewTitle' },
  { id: 'skincare', min: 10, group: 'care', labelKey: 'sceneSkincare', titleKey: 'sceneSkincareTitle' },
  { id: 'eye', min: 10, group: 'care', labelKey: 'sceneEye', titleKey: 'sceneEyeTitle' },
  { id: 'mask', min: 15, group: 'care', labelKey: 'sceneMask', titleKey: 'sceneMaskTitle' },
  { id: 'hair', min: 20, group: 'care', labelKey: 'sceneHair', titleKey: 'sceneHairTitle' },
  { id: 'stretch', min: 5, group: 'rest', labelKey: 'sceneStretch', titleKey: 'sceneStretchTitle' },
  { id: 'walk', min: 10, group: 'rest', labelKey: 'sceneWalk', titleKey: 'sceneWalkTitle' },
  { id: 'meditation', min: 10, group: 'rest', labelKey: 'sceneMeditation', titleKey: 'sceneMeditationTitle' },
  { id: 'nap', min: 15, group: 'rest', labelKey: 'sceneNap', titleKey: 'sceneNapTitle' },
  { id: 'reading', min: 20, group: 'rest', labelKey: 'sceneReading', titleKey: 'sceneReadingTitle' },
  { id: 'yoga', min: 20, group: 'rest', labelKey: 'sceneYoga', titleKey: 'sceneYogaTitle' },
  { id: 'eyeCare', min: 5, group: 'study', labelKey: 'sceneEyeCare', titleKey: 'sceneEyeCareTitle' },
  { id: 'classBreak', min: 10, group: 'study', labelKey: 'sceneClassBreak', titleKey: 'sceneClassBreakTitle' },
  { id: 'vocab', min: 15, group: 'study', labelKey: 'sceneVocab', titleKey: 'sceneVocabTitle' },
  { id: 'homework', min: 25, group: 'study', labelKey: 'sceneHomework', titleKey: 'sceneHomeworkTitle' },
  { id: 'call', min: 10, group: 'work', labelKey: 'sceneCall', titleKey: 'sceneCallTitle' },
  { id: 'meetingPrep', min: 10, group: 'work', labelKey: 'sceneMeetingPrep', titleKey: 'sceneMeetingPrepTitle' },
  { id: 'wrapUp', min: 10, group: 'work', labelKey: 'sceneWrapUp', titleKey: 'sceneWrapUpTitle' },
  { id: 'meeting', min: 15, group: 'work', labelKey: 'sceneMeeting', titleKey: 'sceneMeetingTitle' },
  { id: 'standDesk', min: 15, group: 'work', labelKey: 'sceneStandDesk', titleKey: 'sceneStandDeskTitle' },
  { id: 'email', min: 20, group: 'work', labelKey: 'sceneEmail', titleKey: 'sceneEmailTitle' },
  { id: 'focus', min: 25, group: 'work', labelKey: 'sceneFocus', titleKey: 'sceneFocusTitle' },
  { id: 'hydrate', min: 5, group: 'labor', labelKey: 'sceneHydrate', titleKey: 'sceneHydrateTitle' },
  { id: 'workBreak', min: 10, group: 'labor', labelKey: 'sceneWorkBreak', titleKey: 'sceneWorkBreakTitle' },
  { id: 'shiftHandover', min: 10, group: 'labor', labelKey: 'sceneShiftHandover', titleKey: 'sceneShiftHandoverTitle' },
  { id: 'toolCheck', min: 15, group: 'labor', labelKey: 'sceneToolCheck', titleKey: 'sceneToolCheckTitle' },
  { id: 'safetyWait', min: 15, group: 'labor', labelKey: 'sceneSafetyWait', titleKey: 'sceneSafetyWaitTitle' },
  { id: 'feed', min: 15, group: 'farm', labelKey: 'sceneFeed', titleKey: 'sceneFeedTitle' },
  { id: 'farmTools', min: 15, group: 'farm', labelKey: 'sceneFarmTools', titleKey: 'sceneFarmToolsTitle' },
  { id: 'grainTurn', min: 20, group: 'farm', labelKey: 'sceneGrainTurn', titleKey: 'sceneGrainTurnTitle' },
  { id: 'irrigation', min: 30, group: 'farm', labelKey: 'sceneIrrigation', titleKey: 'sceneIrrigationTitle' },
  { id: 'dishes', min: 15, group: 'chores', labelKey: 'sceneDishes', titleKey: 'sceneDishesTitle' },
  { id: 'laundry', min: 30, group: 'chores', labelKey: 'sceneLaundry', titleKey: 'sceneLaundryTitle' },
]);
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
const langWrap = document.querySelector('#langWrap');
const langBtn = document.querySelector('#langBtn');
const langBtnLabel = document.querySelector('#langBtnLabel');
const langPanel = document.querySelector('#langPanel');
const stageSection = document.querySelector('#stageSection');
const actionsSection = document.querySelector('#actionsSection');
const ambientBtn = document.querySelector('#ambientBtn');
const ambientPanel = document.querySelector('#ambientPanel');
const ambientWrap = document.querySelector('#ambientWrap');
const metaDescription = document.querySelector('meta[name="description"]');

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
    if (sceneId && !SCENES.some((s) => s.id === sceneId)) return false;

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

const syncSceneSelect = () => {
  if (!sceneSelect || !sceneTrigger || !sceneList || !sceneTriggerLabel) return;
  sceneSelect.setAttribute('aria-label', tr('scenesLabel'));
  sceneTrigger.setAttribute('aria-label', tr('scenesLabel'));
  sceneList.setAttribute('aria-label', tr('scenesLabel'));

  const selected = activeScene ? SCENES.find((s) => s.id === activeScene) : null;
  if (selected) {
    sceneTriggerLabel.textContent = tr(selected.labelKey);
    sceneTrigger.classList.remove('is-placeholder');
  } else {
    sceneTriggerLabel.textContent = tr('scenePlaceholder');
    sceneTrigger.classList.add('is-placeholder');
  }

  sceneList.replaceChildren();
  for (const group of SCENE_GROUPS) {
    const items = SCENES.filter((s) => s.group === group.id);
    if (!items.length) continue;

    const groupLi = document.createElement('li');
    groupLi.className = 'scene-group';
    groupLi.setAttribute('role', 'presentation');

    const label = document.createElement('div');
    label.className = 'scene-group-label';
    label.setAttribute('aria-hidden', 'true');
    label.textContent = tr(group.labelKey);
    groupLi.append(label);

    const sub = document.createElement('ul');
    sub.className = 'scene-group-list';
    sub.setAttribute('role', 'group');
    sub.setAttribute('aria-label', tr(group.labelKey));

    for (const scene of items) {
      const li = document.createElement('li');
      li.setAttribute('role', 'presentation');
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.dataset.scene = scene.id;
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-selected', scene.id === activeScene ? 'true' : 'false');
      btn.classList.toggle('active', scene.id === activeScene);
      btn.textContent = tr(scene.labelKey);
      li.append(btn);
      sub.append(li);
    }

    groupLi.append(sub);
    sceneList.append(groupLi);
  }
};

const syncBrandTitle = () => {
  if (activeScene) {
    const scene = SCENES.find((s) => s.id === activeScene);
    if (scene) {
      brandTitle.textContent = tr(scene.titleKey);
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
  if (langBtn) langBtn.setAttribute('aria-label', pack.langLabel);
  if (langPanel) langPanel.setAttribute('aria-label', pack.langLabel);
  syncLangSelect();
  stageSection.setAttribute('aria-label', pack.stageLabel);
  actionsSection.setAttribute('aria-label', pack.actionsLabel);
  resetBtn.textContent = pack.reset;
  if (footnote) {
    const links = [
      { href: 'download.html', label: pack.downloadLabel || '下载 App' },
      { href: 'about.html', label: pack.aboutLabel },
      { href: 'privacy.html', label: pack.footerPrivacy },
      { href: 'terms.html', label: pack.footerTerms },
      { href: 'faq.html', label: pack.footerFaq },
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
  renderDailyStats();
  syncStartLabel();
  if (!titleBlinkId) {
    const suffix = pack.titleSuffix || '';
    document.title = (running || remainMs < totalMs)
      ? (suffix ? `${fmt(remainMs)} · ${suffix}` : fmt(remainMs))
      : pack.titleIdle;
  }
};

const setLangPanelOpen = (open) => {
  if (!langBtn || !langPanel) return;
  langPanel.hidden = !open;
  langBtn.setAttribute('aria-expanded', open ? 'true' : 'false');
};

const syncLangSelect = () => {
  if (!langPanel || !langBtnLabel) return;
  langBtnLabel.textContent = LOCALE_NATIVE_NAMES[locale] ?? locale;
  langPanel.replaceChildren();
  for (const code of LOCALE_CODES) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.lang = code;
    btn.setAttribute('role', 'option');
    btn.setAttribute('aria-selected', code === locale ? 'true' : 'false');
    btn.classList.toggle('active', code === locale);
    btn.textContent = LOCALE_NATIVE_NAMES[code] ?? code;
    langPanel.append(btn);
  }
};

const setLocale = async (next) => {
  const resolved = resolveLocale(next) ?? locale;
  await ensureLocale(resolved);
  locale = resolved;
  try { localStorage.setItem(STORAGE_KEY, locale); } catch { /* ignore */ }
  applyStaticI18n();
  render();
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
    const scene = SCENES.find((s) => s.id === activeScene);
    if (scene) return tr(scene.titleKey);
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

/** Fire sound + vibration (+ notification). Always pair channels — each API is flaky alone. */
const fireFinishAlert = () => {
  needAlertOnVisible = document.visibilityState !== 'visible';
  alertFinish({ notify: maybeNotify });
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
  const clock = fmt(remainMs);
  timeLabel.textContent = clock;
  timeText.innerHTML = digitalWatchSvg(clock);
  timeText.classList.toggle('is-running', !!running);
  const ratio = totalMs > 0 ? Math.min(1, Math.max(0, remainMs / totalMs)) : 0;
  progress.style.strokeDashoffset = String(CIRC * (1 - ratio));

  if (!titleBlinkId) {
    const suffix = tr('titleSuffix') || '';
    document.title = (running || remainMs < totalMs)
      ? (suffix ? `${fmt(remainMs)} · ${suffix}` : fmt(remainMs))
      : tr('titleIdle');
  }

  if (finished) {
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
  if (!running) return;
  const delay = Math.max(16, remainMs % 1000 || 1000);
  tickId = window.setTimeout(tick, delay);
};

const tick = () => {
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
  recordCompletedSession(totalMs);
  renderDailyStats();
  // Keep media channel warm through the alert; clear keepalive after fire.
  render();
  startBtn.disabled = false;
  resetBtn.disabled = false;
  setSetupEnabled(true);
  // Sound/haptic first — releasing wake lock can briefly alter visibility on some devices.
  fireFinishAlert();
  stopAudioKeepAlive();
  releaseWakeLock();
  startTitleBlink();
  persistTimerSession();
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
  ambientBtn.classList.toggle('is-on', current !== 'off');
  for (const btn of ambientPanel.querySelectorAll('button[data-ambient]')) {
    btn.classList.toggle('active', btn.dataset.ambient === current);
  }
};

void (async () => {
  await ensureLocale(locale);
  applyStaticI18n();
  // URL ?sec= wins over a previous same-tab session.
  const restored = bootSec <= 0 && restoreTimerSession();
  if (restored) {
    syncSceneUi();
    resetBtn.disabled = !(running || finished || remainMs < totalMs);
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
})();

langBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  const open = langPanel?.hidden !== false;
  setAmbientPanelOpen(false);
  setSceneListOpen(false);
  setLangPanelOpen(open);
});

langPanel?.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-lang]');
  if (!(btn instanceof HTMLButtonElement)) return;
  void setLocale(btn.dataset.lang);
  setLangPanelOpen(false);
});

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
  setLangPanelOpen(false);
  setSceneListOpen(open);
});

sceneList?.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-scene]');
  if (!(btn instanceof HTMLButtonElement) || btn.disabled) return;
  const scene = SCENES.find((s) => s.id === btn.dataset.scene);
  if (!scene) return;
  setPreset(scene.min, scene.id);
  setSceneListOpen(false);
});

ambientBtn?.addEventListener('click', (event) => {
  event.stopPropagation();
  const open = ambientPanel?.hidden !== false;
  setSceneListOpen(false);
  setLangPanelOpen(false);
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
  if (langWrap && langPanel && !langPanel.hidden && !langWrap.contains(target)) {
    setLangPanelOpen(false);
  }
  if (sceneSelect && sceneList && !sceneList.hidden && !sceneSelect.contains(target)) {
    setSceneListOpen(false);
  }
});

/* 结束后轻触表盘可再次触发振动与提示音（用户手势；iOS 无 Vibration API 时依赖声音） */
stageSection.addEventListener('pointerup', () => {
  if (!finished) return;
  needAlertOnVisible = false;
  void realertFromGesture();
});

document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape') {
    setSceneListOpen(false);
    setAmbientPanelOpen(false);
    setLangPanelOpen(false);
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
  if (!finished) return;
  if (needAlertOnVisible) {
    needAlertOnVisible = false;
    alertOnVisible();
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
