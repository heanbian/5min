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

let vibrateTimer = null;
let vibrateUntil = 0;
let toneCtx = null;
let toneNodes = [];
let toneTimer = null;

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

/**
 * 到期提醒：提示音 + 振动 + toast（由 withTone / withVibrate / withNotify 控制）
 * @param {{ title?: string, body?: string, durationMs?: number, withNotify?: boolean, withVibrate?: boolean, withTone?: boolean }} [opts]
 */
function alertFinish(opts) {
  const options = opts || {};
  clearAlerts();
  const duration = Math.max(1000, options.durationMs || ALERT_DURATION_MS);
  const withVibrate = options.withVibrate !== false;
  const withNotify = options.withNotify !== false;
  const withTone = options.withTone === true;

  if (withTone) {
    playFinishTone(duration);
  }

  if (withVibrate) {
    vibrateUntil = Date.now() + duration;
    pulseVibrate();
    const step =
      (VIBRATE_PATTERN_MS[0] || 500) + (VIBRATE_PATTERN_MS[1] || 150);
    vibrateTimer = setInterval(() => {
      if (Date.now() >= vibrateUntil) {
        clearAlerts();
        return;
      }
      pulseVibrate();
    }, step);
  }

  if (withNotify && (options.title || options.body)) {
    wx.showToast({
      title: options.title || options.body || t('statusDone'),
      icon: 'none',
      duration: Math.min(duration, 3000),
    });
  }
}

module.exports = {
  alertFinish,
  clearAlerts,
  pulseVibrate,
  unlockAlertAudio,
};
