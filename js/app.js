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

const CIRC = 2 * Math.PI * 54;
const PRESET_MINS = Object.freeze([3, 5, 10]);
/** Longer pulses — short patterns are easy to miss on many phones. */
const VIBRATE_PATTERN = Object.freeze([480, 140, 480, 140, 720, 180, 480]);
const VIBRATE_RETRY_MS = Object.freeze([0, 280, 900, 1800, 3200]);

const progress = document.querySelector('#progress');
const timeText = document.querySelector('#timeText');
const timeLabel = document.querySelector('#timeLabel');
const statusEl = document.querySelector('#status');
const startBtn = document.querySelector('#startBtn');
const resetBtn = document.querySelector('#resetBtn');
const presets = document.querySelector('#presets');
const brandTitle = document.querySelector('#brandTitle');
const footnote = document.querySelector('#footnote');
const langSelect = document.querySelector('#langSelect');
const langLabel = document.querySelector('#langLabel');
const stageSection = document.querySelector('#stageSection');
const actionsSection = document.querySelector('#actionsSection');
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
let hapticTimerIds = [];
let audioKeepAliveId = 0;
/** @type {AudioContext | null} */
let audioCtx = null;
/** @type {WakeLockSentinel | null} */
let wakeLock = null;
let notifyAsked = false;
let needHapticOnVisible = false;

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

const applyStaticI18n = () => {
  const pack = LOCALES[locale];
  document.documentElement.lang = pack.htmlLang;
  brandTitle.textContent = pack.brandTitle;
  langLabel.textContent = pack.langLabel;
  langSelect.setAttribute('aria-label', pack.langLabel);
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

  syncStartLabel();
  if (!titleBlinkId) {
    document.title = (running || remainMs < totalMs)
      ? `${fmt(remainMs)} · ${pack.titleSuffix}`
      : pack.titleIdle;
  }
};

const fillLangSelect = () => {
  langSelect.replaceChildren();
  for (const code of LOCALE_CODES) {
    const opt = document.createElement('option');
    opt.value = code;
    opt.textContent = LOCALES[code].nativeName;
    langSelect.append(opt);
  }
  langSelect.value = locale;
};

const setLocale = (next) => {
  const resolved = resolveLocale(next) ?? locale;
  locale = resolved;
  try { localStorage.setItem(STORAGE_KEY, locale); } catch { /* ignore */ }
  langSelect.value = locale;
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

const supportsVibrate = () => typeof navigator.vibrate === 'function';

/**
 * Vibration API quirks:
 * - iOS / all WebKit: API absent → always rely on audio.
 * - Firefox Android: often returns true but does not haptic.
 * - cancel-then-start (`vibrate(0)` then pattern) races on some Chromium WebViews.
 * - Background / locked screen: vibrate is ignored until visible again.
 */
const pulseVibrate = (pattern = VIBRATE_PATTERN) => {
  if (!supportsVibrate()) return false;
  if (document.visibilityState !== 'visible') return false;
  try {
    return navigator.vibrate([...pattern]) === true;
  } catch {
    return false;
  }
};

const clearHapticTimers = () => {
  for (const id of hapticTimerIds) clearTimeout(id);
  hapticTimerIds = [];
};

const scheduleFinishHaptics = () => {
  clearHapticTimers();
  for (const delay of VIBRATE_RETRY_MS) {
    const id = window.setTimeout(() => {
      if (!finished || document.visibilityState !== 'visible') return;
      pulseVibrate(delay === 0 ? VIBRATE_PATTERN : [520, 120, 520]);
    }, delay);
    hapticTimerIds.push(id);
  }
};

const AudioCtx = globalThis.AudioContext ?? globalThis.webkitAudioContext;

const ensureAudio = async () => {
  if (!AudioCtx) return null;
  audioCtx ??= new AudioCtx();
  if (audioCtx.state === 'suspended') {
    try { await audioCtx.resume(); } catch { /* ignore */ }
  }
  return audioCtx;
};

/** Unlock / keep Web Audio alive after the start gesture (needed for finish chime minutes later). */
const unlockAudio = async () => {
  try {
    const ctx = await ensureAudio();
    if (!ctx) return;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    gain.gain.value = 0.0001;
    osc.connect(gain);
    gain.connect(ctx.destination);
    const t0 = ctx.currentTime;
    osc.start(t0);
    osc.stop(t0 + 0.02);
  } catch {
    /* ignore */
  }
};

const stopAudioKeepAlive = () => {
  if (!audioKeepAliveId) return;
  clearInterval(audioKeepAliveId);
  audioKeepAliveId = 0;
};

const startAudioKeepAlive = () => {
  stopAudioKeepAlive();
  audioKeepAliveId = window.setInterval(() => {
    if (!running || !audioCtx) return;
    if (audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
  }, 12_000);
};

const playToneSeries = async (notes) => {
  try {
    const ctx = await ensureAudio();
    if (!ctx) return;
    const now = ctx.currentTime;
    for (const note of notes) {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = note.type ?? 'sine';
      osc.frequency.value = note.freq;
      const t0 = now + (note.at ?? 0);
      gain.gain.setValueAtTime(0.0001, t0);
      gain.gain.exponentialRampToValueAtTime(note.peak ?? 0.16, t0 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, t0 + (note.dur ?? 0.32));
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(t0);
      osc.stop(t0 + (note.dur ?? 0.32) + 0.02);
    }
  } catch {
    /* ignore audio failures */
  }
};

const playChime = () => playToneSeries([
  { freq: 523.25, at: 0, peak: 0.22, dur: 0.4 },
  { freq: 659.25, at: 0.14, peak: 0.22, dur: 0.4 },
  { freq: 783.99, at: 0.28, peak: 0.22, dur: 0.45 },
]);

/** Audible stand-in when Vibration API is missing or a no-op (common on iOS / Firefox Android). */
const playBuzzFallback = () => playToneSeries([
  { freq: 140, type: 'square', at: 0, peak: 0.14, dur: 0.18 },
  { freq: 140, type: 'square', at: 0.26, peak: 0.14, dur: 0.18 },
  { freq: 180, type: 'square', at: 0.52, peak: 0.16, dur: 0.28 },
  { freq: 140, type: 'square', at: 0.9, peak: 0.12, dur: 0.18 },
]);

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
      vibrate: [...VIBRATE_PATTERN],
    });
    n.addEventListener('click', () => {
      globalThis.focus();
      pulseVibrate();
      playBuzzFallback();
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

/** Always pair haptic attempts with audio — vibrate() success is unreliable. */
const alertFinish = () => {
  needHapticOnVisible = document.visibilityState !== 'visible';
  scheduleFinishHaptics();
  playBuzzFallback();
  playChime();
  maybeNotify();
};

/** User gesture re-trigger (iOS / muted haptic systems). */
const realertFromGesture = () => {
  if (!finished) return;
  needHapticOnVisible = false;
  pulseVibrate();
  playBuzzFallback();
  playChime();
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
};

const setTone = (tone) => {
  document.body.classList.toggle('warn', tone === 'warn');
  document.body.classList.toggle('danger', tone === 'danger');
  progress.classList.toggle('is-safe', tone === 'safe');
  progress.classList.toggle('is-warn', tone === 'warn');
  progress.classList.toggle('is-danger', tone === 'danger');
  statusEl.classList.toggle('is-warn', tone === 'warn');
  statusEl.classList.toggle('is-danger', tone === 'danger');
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
  stopAudioKeepAlive();
  render();
  startBtn.disabled = false;
  resetBtn.disabled = false;
  setPresetsEnabled(true);
  // Haptic/audio first — releasing wake lock can briefly alter visibility on some devices.
  alertFinish();
  releaseWakeLock();
  startTitleBlink();
};

const start = () => {
  if (running) {
    running = false;
    clearTick();
    stopAudioKeepAlive();
    clearHapticTimers();
    remainMs = Math.max(0, endAt - Date.now());
    endAt = 0;
    releaseWakeLock();
    setPresetsEnabled(true);
    render();
    return;
  }

  stopTitleBlink();
  clearHapticTimers();
  needHapticOnVisible = false;
  requestNotifyOnce();
  unlockAudio();
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
  stopAudioKeepAlive();
  clearHapticTimers();
  needHapticOnVisible = false;
  stopTitleBlink();
  releaseWakeLock();
  remainMs = totalMs;
  startBtn.disabled = false;
  resetBtn.disabled = true;
  setPresetsEnabled(true);
  render();
};

const setPreset = (min) => {
  if (!Number.isFinite(min) || min <= 0 || running) return;
  totalMs = min * 60 * 1000;
  for (const btn of presets.querySelectorAll('button[data-min]')) {
    btn.classList.toggle('active', Number(btn.dataset.min) === min);
  }
  reset();
};

fillLangSelect();
applyStaticI18n();

langSelect.addEventListener('change', () => {
  setLocale(langSelect.value);
});

startBtn.addEventListener('click', start);
resetBtn.addEventListener('click', reset);

presets.addEventListener('click', (event) => {
  const btn = event.target.closest('button[data-min]');
  if (!(btn instanceof HTMLButtonElement) || btn.disabled) return;
  const min = Number(btn.dataset.min);
  if (!PRESET_MINS.includes(min)) return;
  setPreset(min);
});

/* 结束后点表盘可再触发震动/提示音（用户手势；iOS 无 Vibration API 时靠声音） */
stageSection.addEventListener('click', () => {
  realertFromGesture();
});

document.addEventListener('keydown', (event) => {
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
      if (audioCtx?.state === 'suspended') audioCtx.resume().catch(() => {});
    }
    return;
  }
  if (!finished) return;
  if (needHapticOnVisible) {
    needHapticOnVisible = false;
    scheduleFinishHaptics();
    playBuzzFallback();
    playChime();
  }
  startTitleBlink();
});

window.addEventListener('beforeunload', (event) => {
  if (!running) return;
  event.preventDefault();
  event.returnValue = '';
});

render();
