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
 * Cross-platform finish alert: sound + vibration.
 *
 * Platform notes
 * - iPhone / iOS WebKit: no Vibration API; Web Audio is muted by the ringer
 *   switch unless AudioSession type is "playback" (Safari 17+) or a looping
 *   HTMLAudioElement keeps the media channel open (older iOS).
 * - Android / HarmonyOS (ArkWeb): Vibration + AudioContext work in foreground;
 *   background / lock screen often ignores vibrate until visible again.
 * - Firefox Android: vibrate() may return true without haptic — always pair audio.
 * - PC: vibration no-ops; Web Audio / HTMLAudio / Notification carry the alert.
 */

/** Finish alert length: sound + vibration both run ~5 seconds. */
const ALERT_DURATION_MS = 5_000;
const ALERT_DURATION_SEC = ALERT_DURATION_MS / 1000;
/**
 * Vibration pattern totaling ~5000ms (vibrate/pause pairs).
 * 8×(450 on + 150 off) + final 450 on = 8×600 + 450 = 5250 → trim last pause.
 * 7×(500+150) + 500 = 7×650 + 500 = 5050ms.
 */
const VIBRATE_PATTERN = Object.freeze([
  500, 150, 500, 150, 500, 150, 500, 150,
  500, 150, 500, 150, 500, 150, 500,
]);
/** Early retries only — avoid stretching the cue well past 5s. */
const VIBRATE_RETRY_MS = Object.freeze([0, 280]);
const AUDIO_KEEPALIVE_MS = 8_000;
const SAMPLE_RATE = 22_050;

const AudioCtx = globalThis.AudioContext ?? globalThis.webkitAudioContext;

/** @type {AudioContext | null} */
let audioCtx = null;
/** @type {HTMLAudioElement | null} */
let silentEl = null;
/** @type {HTMLAudioElement | null} */
let alertEl = null;
/** @type {string | null} */
let silentUri = null;
/** @type {string | null} */
let alertUri = null;
let keepAliveId = 0;
/** @type {number[]} */
let hapticTimerIds = [];
let unlocked = false;

const supportsVibrate = () => typeof navigator.vibrate === 'function';

/** Prefer media/playback channel so iOS silent switch does not mute alerts. */
const preferPlaybackSession = () => {
  try {
    const session = /** @type {{ type?: string }} */ (navigator).audioSession;
    if (session && typeof session === 'object') {
      session.type = 'playback';
    }
  } catch {
    /* ignore unsupported / read-only */
  }
};

const floatTo16BitPCM = (view, offset, samples) => {
  for (let i = 0; i < samples.length; i += 1, offset += 2) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    view.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7fff, true);
  }
};

/** Build a mono 16-bit WAV data URI from Float32 samples. */
const samplesToWavUri = (samples, sampleRate = SAMPLE_RATE) => {
  const dataSize = samples.length * 2;
  const buffer = new ArrayBuffer(44 + dataSize);
  const view = new DataView(buffer);
  const writeStr = (at, str) => {
    for (let i = 0; i < str.length; i += 1) view.setUint8(at + i, str.charCodeAt(i));
  };
  writeStr(0, 'RIFF');
  view.setUint32(4, 36 + dataSize, true);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeStr(36, 'data');
  view.setUint32(40, dataSize, true);
  floatTo16BitPCM(view, 44, samples);

  const bytes = new Uint8Array(buffer);
  let binary = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return `data:audio/wav;base64,${btoa(binary)}`;
};

const makeSilentUri = () => {
  // ~180ms of near-silence — long enough for iOS media-channel unlock when looped.
  const n = Math.floor(SAMPLE_RATE * 0.18);
  const samples = new Float32Array(n);
  for (let i = 0; i < n; i += 1) samples[i] = (Math.random() * 2 - 1) * 0.00002;
  return samplesToWavUri(samples);
};

/** Distinct finish cue: buzz + rising chime, ~5s (HTMLAudio fallback path). */
const makeAlertUri = () => {
  const duration = ALERT_DURATION_SEC;
  const n = Math.floor(SAMPLE_RATE * duration);
  const samples = new Float32Array(n);
  const tone = (t0, t1, freq, type, peak) => {
    const i0 = Math.max(0, Math.floor(t0 * SAMPLE_RATE));
    const i1 = Math.min(n, Math.floor(t1 * SAMPLE_RATE));
    const len = i1 - i0;
    for (let i = 0; i < len; i += 1) {
      const t = i / SAMPLE_RATE;
      const env = Math.sin((Math.PI * i) / Math.max(1, len));
      const phase = 2 * Math.PI * freq * t;
      const wave = type === 'square'
        ? (Math.sin(phase) >= 0 ? 1 : -1) * 0.55
        : Math.sin(phase);
      samples[i0 + i] += wave * peak * env;
    }
  };
  // Low square buzz pulses across ~5s — stand-in when vibration is missing.
  for (let i = 0; i < 8; i += 1) {
    const t0 = i * 0.62;
    tone(t0, t0 + 0.2, i % 2 === 0 ? 140 : 175, 'square', 0.36);
  }
  // Rising chime cycles across ~5s
  for (let cycle = 0; cycle < 4; cycle += 1) {
    const base = 0.35 + cycle * 1.15;
    tone(base, base + 0.28, 523.25, 'sine', 0.52);
    tone(base + 0.14, base + 0.42, 659.25, 'sine', 0.52);
    tone(base + 0.28, base + 0.58, 783.99, 'sine', 0.55);
  }
  // Soft clip
  for (let i = 0; i < n; i += 1) {
    samples[i] = Math.max(-1, Math.min(1, samples[i]));
  }
  return samplesToWavUri(samples);
};

const ensureUris = () => {
  silentUri ??= makeSilentUri();
  alertUri ??= makeAlertUri();
};

const makeAudioEl = (src, { loop = false } = {}) => {
  const el = new Audio();
  el.preload = 'auto';
  el.loop = loop;
  el.playsInline = true;
  el.setAttribute('playsinline', '');
  el.setAttribute('webkit-playsinline', '');
  el.setAttribute('x-webkit-airplay', 'deny');
  el.src = src;
  el.volume = 1;
  return el;
};

/** Create + resume AudioContext; prefer sync kickoff so iOS keeps the user-gesture token. */
const ensureAudio = async () => {
  if (!AudioCtx) return null;
  preferPlaybackSession();
  audioCtx ??= new AudioCtx();
  if (audioCtx.state === 'suspended') {
    try {
      const p = audioCtx.resume();
      if (p && typeof p.then === 'function') await p;
    } catch { /* ignore */ }
  }
  return audioCtx;
};

/** Silent oscillator tick — call without awaiting across awaits (gesture-sensitive). */
const tickWebAudioSync = (ctx) => {
  if (!ctx) return;
  try {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    gain.gain.value = 0.0001;
    osc.connect(gain);
    gain.connect(ctx.destination);
    const t0 = ctx.currentTime;
    osc.start(t0);
    osc.stop(t0 + 0.03);
  } catch {
    /* ignore */
  }
};

const startSilentLoop = () => {
  ensureUris();
  try {
    silentEl ??= makeAudioEl(silentUri, { loop: true });
    silentEl.currentTime = 0;
    return silentEl.play().catch(() => {});
  } catch {
    return Promise.resolve();
  }
};

const stopSilentLoop = () => {
  if (!silentEl) return;
  try {
    silentEl.pause();
    silentEl.currentTime = 0;
  } catch {
    /* ignore */
  }
};

const playHtmlAlert = async () => {
  ensureUris();
  preferPlaybackSession();
  try {
    // Fresh element each time — more reliable on iOS / HarmonyOS WebViews than replay.
    alertEl?.pause();
    alertEl = makeAudioEl(alertUri, { loop: false });
    alertEl.currentTime = 0;
    const p = alertEl.play();
    if (p && typeof p.then === 'function') await p;
  } catch {
    /* ignore */
  }
};

const playToneSeries = async (notes) => {
  try {
    preferPlaybackSession();
    const ctx = await ensureAudio();
    if (!ctx || ctx.state !== 'running') return false;
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
    return true;
  } catch {
    return false;
  }
};

const playChime = () => {
  /** @type {{ freq: number, at: number, peak: number, dur: number }[]} */
  const notes = [];
  for (let cycle = 0; cycle < 4; cycle += 1) {
    const base = cycle * 1.2;
    notes.push(
      { freq: 523.25, at: base, peak: 0.22, dur: 0.38 },
      { freq: 659.25, at: base + 0.14, peak: 0.22, dur: 0.38 },
      { freq: 783.99, at: base + 0.28, peak: 0.24, dur: 0.42 },
    );
  }
  return playToneSeries(notes);
};

/** Audible stand-in when Vibration API is missing or a no-op (~5s). */
const playBuzzFallback = () => {
  /** @type {{ freq: number, type: OscillatorType, at: number, peak: number, dur: number }[]} */
  const notes = [];
  for (let i = 0; i < 8; i += 1) {
    notes.push({
      freq: i % 2 === 0 ? 140 : 175,
      type: 'square',
      at: i * 0.62,
      peak: 0.16,
      dur: 0.22,
    });
  }
  return playToneSeries(notes);
};

/**
 * Fire Web Audio + HTMLAudio in parallel. HTMLAudio covers iOS silent-switch
 * and WebViews where AudioContext was suspended after unlock.
 */
const playAllAudio = async () => {
  preferPlaybackSession();
  await ensureAudio();
  // Do not await sequentially — race both paths for first audible success.
  void playBuzzFallback();
  void playChime();
  void playHtmlAlert();
};

/**
 * Vibration API quirks:
 * - iOS / all WebKit: API absent → audio buzz only.
 * - Background / locked: ignored until visible (retry on visibilitychange).
 * - Avoid vibrate(0) cancel-then-start races on some Chromium / ArkWeb builds.
 */
const pulseVibrate = (pattern = VIBRATE_PATTERN) => {
  if (!supportsVibrate()) return false;
  if (document.visibilityState !== 'visible') return false;
  try {
    const ok = navigator.vibrate([...pattern]);
    return ok === true || ok === undefined;
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
      if (document.visibilityState !== 'visible') return;
      // Restart the full ~5s pattern; early retry covers flaky first calls only.
      pulseVibrate(VIBRATE_PATTERN);
    }, delay);
    hapticTimerIds.push(id);
  }
};

export const stopAudioKeepAlive = () => {
  if (!keepAliveId) return;
  clearInterval(keepAliveId);
  keepAliveId = 0;
};

export const startAudioKeepAlive = () => {
  stopAudioKeepAlive();
  keepAliveId = window.setInterval(() => {
    preferPlaybackSession();
    if (audioCtx?.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
    // Nudge silent loop if the media element stalled (common after iOS lock).
    if (silentEl && silentEl.paused) {
      silentEl.play().catch(() => {});
    }
  }, AUDIO_KEEPALIVE_MS);
};

/**
 * Must run inside a user gesture (Start). Unlocks Web Audio + HTMLAudio media
 * channel and pins AudioSession to playback for later finish alerts.
 *
 * Critical: kick off resume()/play()/oscillator synchronously before any await,
 * otherwise iOS may drop the transient user-activation token.
 */
export const unlockAlertAudio = async () => {
  preferPlaybackSession();
  ensureUris();

  /** @type {Promise<unknown>[]} */
  const pending = [];

  if (AudioCtx) {
    audioCtx ??= new AudioCtx();
    if (audioCtx.state === 'suspended') {
      try { pending.push(audioCtx.resume()); } catch { /* ignore */ }
    }
    tickWebAudioSync(audioCtx);
  }

  pending.push(startSilentLoop());

  try {
    alertEl ??= makeAudioEl(alertUri, { loop: false });
    alertEl.load();
  } catch {
    /* ignore */
  }

  await Promise.allSettled(pending);
  unlocked = true;
};

export const clearAlerts = () => {
  clearHapticTimers();
  stopAudioKeepAlive();
  stopSilentLoop();
  try { alertEl?.pause(); } catch { /* ignore */ }
};

/**
 * Full finish alert. Call while page may still hold wake lock / foreground.
 * @param {{ notify?: () => void }} [opts]
 */
export const alertFinish = (opts = {}) => {
  preferPlaybackSession();
  scheduleFinishHaptics();
  void playAllAudio();
  try { opts.notify?.(); } catch { /* ignore */ }
  // Drop the silent unlock loop after the cue finishes (avoids lingering iOS Now Playing).
  window.setTimeout(() => stopSilentLoop(), ALERT_DURATION_MS + 300);
};

/** Re-fire from a user gesture (tap dial) — critical on iOS / muted haptics. */
export const realertFromGesture = async () => {
  preferPlaybackSession();
  clearHapticTimers();
  pulseVibrate();
  // Unlock + play in the same gesture turn (sync kickoff inside unlock/play).
  const unlockP = unlockAlertAudio();
  void playAllAudio();
  await unlockP;
  // Re-arm full ~5s haptic after unlock on Android / HarmonyOS.
  window.setTimeout(() => pulseVibrate(VIBRATE_PATTERN), 40);
};

/** Page became visible again after a backgrounded finish. */
export const alertOnVisible = () => {
  preferPlaybackSession();
  if (audioCtx?.state === 'suspended') {
    audioCtx.resume().catch(() => {});
  }
  scheduleFinishHaptics();
  void playAllAudio();
};

export const getVibratePattern = () => [...VIBRATE_PATTERN];

export const isAlertUnlocked = () => unlocked;
