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

let vibrateTimer = null;
let vibrateUntil = 0;

function clearAlerts() {
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

/**
 * 到期提醒：振动若干秒（小程序无自定义音频文件时以振动 + toast 为主）
 * @param {{ title?: string, body?: string, durationMs?: number }} [opts]
 */
function alertFinish(opts) {
  const options = opts || {};
  clearAlerts();
  const duration = Math.max(1000, options.durationMs || ALERT_DURATION_MS);
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

  if (options.title || options.body) {
    wx.showToast({
      title: options.title || options.body || '计时已结束',
      icon: 'none',
      duration: Math.min(duration, 3000),
    });
  }
}

module.exports = {
  alertFinish,
  clearAlerts,
  pulseVibrate,
};
