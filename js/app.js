/**
 * Copyright 2026 学记宝 / heanbian
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
  STORAGE_KEY,
  detectLocale,
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
} from './ambient.js';

const CIRC = 2 * Math.PI * 54;
const PRESET_MINS = Object.freeze([3, 5, 10]);
const SCENE_GROUPS = Object.freeze([
  { id: 'daily', labelKey: 'sceneGroupDaily' },
  { id: 'kitchen', labelKey: 'sceneGroupKitchen' },
  { id: 'care', labelKey: 'sceneGroupCare' },
  { id: 'rest', labelKey: 'sceneGroupRest' },
  { id: 'work', labelKey: 'sceneGroupWork' },
  { id: 'chores', labelKey: 'sceneGroupChores' },
]);

const SCENES = Object.freeze([
  { id: 'brush', min: 3, group: 'daily', labelKey: 'sceneBrush', titleKey: 'sceneBrushTitle' },
  { id: 'toilet', min: 5, group: 'daily', labelKey: 'sceneToilet', titleKey: 'sceneToiletTitle' },
  { id: 'noodles', min: 3, group: 'kitchen', labelKey: 'sceneNoodles', titleKey: 'sceneNoodlesTitle' },
  { id: 'microwave', min: 3, group: 'kitchen', labelKey: 'sceneMicrowave', titleKey: 'sceneMicrowaveTitle' },
  { id: 'tea', min: 5, group: 'kitchen', labelKey: 'sceneTea', titleKey: 'sceneTeaTitle' },
  { id: 'coffee', min: 5, group: 'kitchen', labelKey: 'sceneCoffee', titleKey: 'sceneCoffeeTitle' },
  { id: 'water', min: 5, group: 'kitchen', labelKey: 'sceneWater', titleKey: 'sceneWaterTitle' },
  { id: 'egg', min: 8, group: 'kitchen', labelKey: 'sceneEgg', titleKey: 'sceneEggTitle' },
  { id: 'pasta', min: 10, group: 'kitchen', labelKey: 'scenePasta', titleKey: 'scenePastaTitle' },
  { id: 'oven', min: 15, group: 'kitchen', labelKey: 'sceneOven', titleKey: 'sceneOvenTitle' },
  { id: 'rice', min: 30, group: 'kitchen', labelKey: 'sceneRice', titleKey: 'sceneRiceTitle' },
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
  { id: 'call', min: 10, group: 'work', labelKey: 'sceneCall', titleKey: 'sceneCallTitle' },
  { id: 'meeting', min: 15, group: 'work', labelKey: 'sceneMeeting', titleKey: 'sceneMeetingTitle' },
  { id: 'focus', min: 25, group: 'work', labelKey: 'sceneFocus', titleKey: 'sceneFocusTitle' },
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
const presets = document.querySelector('#presets');
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

/** 七段电子表：a 顶 / b 右上 / c 右下 / d 底 / e 左下 / f 左上 / g 中 */
const DIGIT_SEGS = Object.freeze([
  'abcdef', 'bc', 'abged', 'abgcd', 'fgbc',
  'afgcd', 'afgcde', 'abc', 'abcdefg', 'abfgcd',
]);
const ALL_SEGS = 'abcdefg';

const svgN = (v) => Math.round(Number(v) * 10) / 10;

const hBar = (x, y, w, t) =>
  `M${svgN(x)} ${svgN(y + t / 2)} L${svgN(x + t / 2)} ${svgN(y)} H${svgN(x + w - t / 2)} L${svgN(x + w)} ${svgN(y + t / 2)} L${svgN(x + w - t / 2)} ${svgN(y + t)} H${svgN(x + t / 2)} Z`;

const vBar = (x, y, h, t) =>
  `M${svgN(x + t / 2)} ${svgN(y)} L${svgN(x + t)} ${svgN(y + t / 2)} V${svgN(y + h - t / 2)} L${svgN(x + t / 2)} ${svgN(y + h)} L${svgN(x)} ${svgN(y + h - t / 2)} V${svgN(y + t / 2)} Z`;

const digitSegMap = (ox, oy) => {
  const dw = 22;
  const dh = 36;
  const t = 4;
  const gap = 1;
  const mid = dh / 2;
  return {
    a: hBar(ox + 2.5, oy, dw - 5, t),
    g: hBar(ox + 2.5, oy + mid - t / 2, dw - 5, t),
    d: hBar(ox + 2.5, oy + dh - t, dw - 5, t),
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
    else out += `<path fill="currentColor" opacity="0.05" d="${segs[k]}"/>`;
  }
  return out;
};

const colonPaths = (ox, oy) => {
  const cx = svgN(ox + 6);
  return (
    `<circle fill="currentColor" cx="${cx}" cy="${svgN(oy + 10)}" r="2.6"/>` +
    `<circle fill="currentColor" cx="${cx}" cy="${svgN(oy + 26)}" r="2.6"/>`
  );
};

/** 固定 MM:SS 五槽布局，切换 3/5/10 分钟时尺寸不变 */
const WATCH_W = 144;
const WATCH_H = 48;
const WATCH_SLOTS = Object.freeze([
  { kind: 'digit', x: 4 },
  { kind: 'digit', x: 34 },
  { kind: 'colon', x: 64 },
  { kind: 'digit', x: 80 },
  { kind: 'digit', x: 110 },
]);

/** 计时数字：电子表七段液晶风格（恒定画布） */
const digitalWatchSvg = (text) => {
  const raw = String(text).replace(/\D/g, '').padStart(4, '0').slice(-4);
  const digits = [raw[0], raw[1], raw[2], raw[3]].map(Number);
  const oy = 6;
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
  brandTitle.textContent = LOCALES[locale].brandTitle;
};

const applyStaticI18n = () => {
  const pack = LOCALES[locale];
  document.documentElement.lang = pack.htmlLang;
  syncBrandTitle();
  if (langBtn) langBtn.setAttribute('aria-label', pack.langLabel);
  if (langPanel) langPanel.setAttribute('aria-label', pack.langLabel);
  syncLangSelect();
  stageSection.setAttribute('aria-label', pack.stageLabel);
  actionsSection.setAttribute('aria-label', pack.actionsLabel);
  presets.setAttribute('aria-label', pack.presetsLabel);
  resetBtn.textContent = pack.reset;
  footnote.replaceChildren(
    document.createTextNode(`${pack.footnote} `),
    Object.assign(document.createElement('a'), {
      href: 'about.html',
      textContent: pack.aboutLabel,
    }),
  );
  metaDescription?.setAttribute('content', pack.metaDescription);

  for (const btn of presets.querySelectorAll('button[data-min]')) {
    const n = Number(btn.dataset.min);
    btn.textContent = tr('minutes', { n });
  }

  syncSceneSelect();
  syncAmbientI18n();
  renderDailyStats();
  syncStartLabel();
  if (!titleBlinkId) {
    document.title = (running || remainMs < totalMs)
      ? `${fmt(remainMs)} · ${pack.titleSuffix}`
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
  langBtnLabel.textContent = LOCALES[locale]?.nativeName ?? locale;
  langPanel.replaceChildren();
  for (const code of LOCALE_CODES) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.lang = code;
    btn.setAttribute('role', 'option');
    btn.setAttribute('aria-selected', code === locale ? 'true' : 'false');
    btn.classList.toggle('active', code === locale);
    btn.textContent = LOCALES[code].nativeName;
    langPanel.append(btn);
  }
};

const setLocale = (next) => {
  const resolved = resolveLocale(next) ?? locale;
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

const startTitleBlink = () => {
  stopTitleBlink();
  let flip = false;
  titleBlinkId = window.setInterval(() => {
    document.title = flip ? tr('titleDoneBlink') : tr('titleDoneZero');
    flip = !flip;
  }, 800);
};

const maybeNotify = () => {
  if (!('Notification' in globalThis)) return;
  if (Notification.permission !== 'granted') return;
  try {
    const n = new Notification(tr('notifyTitle'), {
      body: tr('notifyBody'),
      icon: 'img/logo.png',
      tag: '5min-toilet-timer',
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

const setPresetsEnabled = (enabled) => {
  for (const btn of presets.querySelectorAll('button[data-min]')) {
    btn.disabled = !enabled;
  }
  if (sceneTrigger) sceneTrigger.disabled = !enabled;
  if (!enabled) setSceneListOpen(false);
};

const syncPresetActive = () => {
  const min = totalMs / 60_000;
  for (const btn of presets.querySelectorAll('button[data-min]')) {
    btn.classList.toggle('active', Number(btn.dataset.min) === min);
  }
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
  const ratio = totalMs > 0 ? Math.min(1, Math.max(0, remainMs / totalMs)) : 0;
  progress.style.strokeDashoffset = String(CIRC * (1 - ratio));

  if (!titleBlinkId) {
    document.title = (running || remainMs < totalMs)
      ? `${fmt(remainMs)} · ${tr('titleSuffix')}`
      : tr('titleIdle');
  }

  if (finished) {
    setTone('danger');
    statusEl.textContent = tr('statusDone');
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
  setPresetsEnabled(true);
  // Sound/haptic first — releasing wake lock can briefly alter visibility on some devices.
  fireFinishAlert();
  stopAudioKeepAlive();
  releaseWakeLock();
  startTitleBlink();
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
    setPresetsEnabled(true);
    render();
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
  setPresetsEnabled(false);
  render();
  scheduleTick();
  acquireWakeLock();
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
  setPresetsEnabled(true);
  render();
};

const setPreset = (min, sceneId = null) => {
  if (!Number.isFinite(min) || min <= 0 || running) return;
  totalMs = min * 60 * 1000;
  activeScene = sceneId;
  syncPresetActive();
  reset();
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

applyStaticI18n();
syncPresetActive();
syncAmbientUi();
renderDailyStats();

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
  setLocale(btn.dataset.lang);
  setLangPanelOpen(false);
});

/* pointerdown：尽早占用用户手势，提升 iOS / 部分 WebView 音频解锁成功率 */
startBtn.addEventListener('pointerdown', () => {
  void unlockAlertAudio();
});
startBtn.addEventListener('click', start);
resetBtn.addEventListener('click', reset);

presets.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-min]');
  if (!(btn instanceof HTMLButtonElement) || btn.disabled) return;
  const min = Number(btn.dataset.min);
  if (!PRESET_MINS.includes(min)) return;
  setSceneListOpen(false);
  setPreset(min, null);
});

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
  if (document.visibilityState !== 'visible') return;
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

window.addEventListener('beforeunload', (event) => {
  if (!running) return;
  event.preventDefault();
  event.returnValue = '';
});

render();
