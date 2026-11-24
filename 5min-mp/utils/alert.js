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

const { ALERT_DURATION_MS, VIBRATE_PATTERN_MS } = require('./catalog');
const { t } = require('./i18n');

/** Stronger local finish (WeChat has no sticky OS notification). */
const STRONG_ALERT_DURATION_MS = Math.max(ALERT_DURATION_MS * 2, 10000);
const STRONG_VIBRATE_STEP_MS = 450;
const REALERT_COOLDOWN_MS = 2500;

let vibrateTimer = null;
let vibrateUntil = 0;
let toneCtx = null;
let toneNodes = [];
let toneTimer = null;
let finishModalOpen = false;
let lastRealertAt = 0;

function clearTone() {
  if (toneTimer) {
    clearTimeout(toneTimer);
    toneTimer = null;
  }
  toneNodes.forEach((node) => {
    try {
      if (node && typeof node.stop === 'function') node.stop();
    } catch (e) {
      /* ignore */
    }
    try {
      if (node && typeof node.disconnect === 'function') node.disconnect();
    } catch (e) {
      /* ignore */
    }
  });
  toneNodes = [];
}

function clearAlerts() {
  clearTone();
  if (vibrateTimer) {
    clearInterval(vibrateTimer);
    vibrateTimer = null;
  }
  vibrateUntil = 0;
  try {
    wx.stopVibrateLong && wx.stopVibrateLong();
  } catch (e) {
    /* ignore */
  }
}

function pulseVibrate() {
  try {
    wx.vibrateLong({
      type: 'heavy',
      fail() {
        wx.vibrateShort({ type: 'heavy' });
      },
    });
  } catch (e) {
    try {
      wx.vibrateShort({ type: 'heavy' });
    } catch (err) {
      /* ignore */
    }
  }
}

function ensureToneCtx() {
  if (!wx.createWebAudioContext) return null;
  if (!toneCtx) {
    try {
      toneCtx = wx.createWebAudioContext();
    } catch (e) {
      return null;
    }
  }
  return toneCtx;
}

/** Unlock audio graph on a user gesture (Start). */
function unlockAlertAudio() {
  const ctx = ensureToneCtx();
  if (!ctx) return;
  try {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    gain.gain.value = 0.0001;
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.05);
  } catch (e) {
    /* ignore */
  }
}

function beep(ctx, freq, start, dur, peak) {
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.value = freq;
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(peak, start + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + dur);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(start);
  osc.stop(start + dur + 0.02);
  toneNodes.push(osc, gain);
}

function playFinishTone(durationMs) {
  const ctx = ensureToneCtx();
  if (!ctx) return;
  clearTone();
  const now = ctx.currentTime;
  const total = Math.max(1, (durationMs || ALERT_DURATION_MS) / 1000);
  // ~5s pulse train similar to native ToneGenerator / web chime.
  for (let i = 0; i < 8; i += 1) {
    const t0 = now + i * 0.62;
    if (t0 - now > total) break;
    beep(ctx, 880, t0, 0.18, 0.22);
    beep(ctx, 1174, t0 + 0.2, 0.16, 0.18);
  }
  toneTimer = setTimeout(() => clearTone(), Math.min(durationMs || ALERT_DURATION_MS, 5500) + 80);
}

function getAppSafe() {
  try {
    return typeof getApp === 'function' ? getApp() : null;
  } catch (e) {
    return null;
  }
}

/**
 * Remember a finish alert so App/page onShow can re-cue while still pending.
 * @param {object|null} opts
 */
function setFinishAlertPending(opts) {
  const app = getAppSafe();
  if (!app || !app.globalData) return;
  app.globalData.finishAlertPending = opts
    ? {
        title: opts.title || '',
        body: opts.body || '',
        withNotify: opts.withNotify !== false,
        withVibrate: opts.withVibrate !== false,
        withTone: opts.withTone === true,
      }
    : null;
}

function clearFinishAlertPending() {
  const app = getAppSafe();
  if (!app || !app.globalData) return;
  app.globalData.finishAlertPending = null;
  app.globalData.finishAlerting = false;
  finishModalOpen = false;
}

/**
 * 到期提醒：提示音 + 振动 + toast / 需确认的 modal
 * @param {{
 *   title?: string,
 *   body?: string,
 *   durationMs?: number,
 *   withNotify?: boolean,
 *   withVibrate?: boolean,
 *   withTone?: boolean,
 *   strong?: boolean,
 *   requireDismiss?: boolean,
 *   onDismiss?: () => void,
 * }} [opts]
 */
function alertFinish(opts) {
  const options = opts || {};
  clearAlerts();
  const strong = options.strong === true;
  const requireDismiss = options.requireDismiss === true || strong;
  const duration = Math.max(
    1000,
    options.durationMs || (strong ? STRONG_ALERT_DURATION_MS : ALERT_DURATION_MS)
  );
  const withVibrate = options.withVibrate !== false;
  const withNotify = options.withNotify !== false;
  const withTone = options.withTone === true;

  if (withTone) {
    playFinishTone(duration);
  }

  if (withVibrate) {
    vibrateUntil = Date.now() + duration;
    pulseVibrate();
    const step = strong
      ? STRONG_VIBRATE_STEP_MS
      : (VIBRATE_PATTERN_MS[0] || 500) + (VIBRATE_PATTERN_MS[1] || 150);
    vibrateTimer = setInterval(() => {
      if (Date.now() >= vibrateUntil) {
        // Keep vibration going while dismiss modal is open.
        if (requireDismiss && finishModalOpen) {
          vibrateUntil = Date.now() + STRONG_VIBRATE_STEP_MS * 4;
          pulseVibrate();
          return;
        }
        clearAlerts();
        return;
      }
      pulseVibrate();
    }, step);
  }

  if (withNotify && (options.title || options.body || requireDismiss)) {
    const title = options.title || t('statusDone');
    const body = options.body || t('statusDone');
    if (requireDismiss) {
      finishModalOpen = true;
      try {
        wx.showModal({
          title,
          content: body,
          showCancel: false,
          confirmText: t('confirmLabel'),
          success() {
            finishModalOpen = false;
            clearAlerts();
            const app = getAppSafe();
            if (app && app.globalData) app.globalData.finishAlerting = false;
            if (typeof options.onDismiss === 'function') options.onDismiss();
          },
          fail() {
            finishModalOpen = false;
            const app = getAppSafe();
            if (app && app.globalData) app.globalData.finishAlerting = false;
          },
        });
      } catch (e) {
        finishModalOpen = false;
        wx.showToast({
          title,
          icon: 'none',
          duration: Math.min(duration, 3000),
        });
      }
    } else {
      wx.showToast({
        title: title || body,
        icon: 'none',
        duration: Math.min(duration, 3000),
      });
    }
  }
}

/** Strong local finish: longer vibrateLong pulses + dismiss-required modal. */
function alertFinishStrong(opts) {
  alertFinish(Object.assign({}, opts || {}, { strong: true, requireDismiss: true }));
}

/**
 * Re-fire pending finish alert (App/page onShow). No-ops if already alerting
 * or within cooldown.
 */
function realertFinishIfPending() {
  const app = getAppSafe();
  if (!app || !app.globalData) return false;
  const pending = app.globalData.finishAlertPending;
  if (!pending) return false;
  if (app.globalData.finishAlerting || finishModalOpen) return false;
  const now = Date.now();
  if (now - lastRealertAt < REALERT_COOLDOWN_MS) return false;
  lastRealertAt = now;
  app.globalData.finishAlerting = true;
  alertFinishStrong({
    title: pending.title || t('statusDone'),
    body: pending.body || t('statusDone'),
    withNotify: pending.withNotify !== false,
    withVibrate: pending.withVibrate !== false,
    withTone: pending.withTone === true,
  });
  return true;
}

module.exports = {
  alertFinish,
  alertFinishStrong,
  clearAlerts,
  pulseVibrate,
  unlockAlertAudio,
  setFinishAlertPending,
  clearFinishAlertPending,
  realertFinishIfPending,
};
