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

/** Procedural ambient via wx.createWebAudioContext — no media assets. */

const AMBIENT_MODES = Object.freeze(['off', 'rain', 'waves', 'clock']);
const AMBIENT_STORAGE_KEY = '5min.ambient';

let ctx = null;
let master = null;
let nodes = [];
let timerIds = [];
let mode = 'off';

function readSaved() {
  try {
    const saved = wx.getStorageSync(AMBIENT_STORAGE_KEY);
    if (AMBIENT_MODES.indexOf(saved) >= 0) return saved;
  } catch (e) {
    /* ignore */
  }
  return 'off';
}

function persist(next) {
  try {
    wx.setStorageSync(AMBIENT_STORAGE_KEY, next);
  } catch (e) {
    /* ignore */
  }
}

function clearGraph() {
  timerIds.forEach((id) => clearInterval(id));
  timerIds = [];
  nodes.forEach((node) => {
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
  nodes = [];
}

function ensureCtx() {
  if (!wx.createWebAudioContext) return null;
  if (!ctx) {
    try {
      ctx = wx.createWebAudioContext();
    } catch (e) {
      return null;
    }
  }
  if (!master && ctx) {
    master = ctx.createGain();
    master.gain.value = 0.22;
    master.connect(ctx.destination);
  }
  return ctx;
}

function noiseBuffer(audioCtx, seconds) {
  const len = Math.floor(audioCtx.sampleRate * (seconds || 2));
  const buffer = audioCtx.createBuffer(1, len, audioCtx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < len; i += 1) data[i] = Math.random() * 2 - 1;
  return buffer;
}

function startRain(audioCtx) {
  const src = audioCtx.createBufferSource();
  src.buffer = noiseBuffer(audioCtx, 2.5);
  src.loop = true;
  const filter = audioCtx.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.value = 1200;
  filter.Q.value = 0.55;
  const gain = audioCtx.createGain();
  gain.gain.value = 0.55;
  src.connect(filter);
  filter.connect(gain);
  gain.connect(master);
  src.start();
  nodes.push(src, filter, gain);
}

function startWaves(audioCtx) {
  const src = audioCtx.createBufferSource();
  src.buffer = noiseBuffer(audioCtx, 3);
  src.loop = true;
  const filter = audioCtx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.value = 480;
  filter.Q.value = 0.7;
  const gain = audioCtx.createGain();
  gain.gain.value = 0.35;
  src.connect(filter);
  filter.connect(gain);
  gain.connect(master);
  src.start();
  nodes.push(src, filter, gain);

  const swell = () => {
    if (!ctx || mode !== 'waves' || !gain) return;
    const now = ctx.currentTime;
    try {
      gain.gain.cancelScheduledValues(now);
      gain.gain.setValueAtTime(gain.gain.value, now);
      gain.gain.linearRampToValueAtTime(
        0.18 + Math.random() * 0.28,
        now + 2.2 + Math.random()
      );
    } catch (e) {
      /* ignore */
    }
  };
  swell();
  timerIds.push(setInterval(swell, 2800));
}

function startClock(audioCtx) {
  const tick = () => {
    if (!ctx || mode !== 'clock' || !master) return;
    const t0 = ctx.currentTime;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'sine';
    osc.frequency.value = 1180;
    gain.gain.setValueAtTime(0.0001, t0);
    gain.gain.exponentialRampToValueAtTime(0.2, t0 + 0.004);
    gain.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.06);
    osc.connect(gain);
    gain.connect(master);
    osc.start(t0);
    osc.stop(t0 + 0.08);
    nodes.push(osc, gain);
  };
  tick();
  timerIds.push(setInterval(tick, 1000));
}

function getAmbientMode() {
  return mode;
}

/** 停止发声但保留偏好（页面卸载时用） */
function pauseAmbient() {
  clearGraph();
}

function stopAmbient() {
  mode = 'off';
  clearGraph();
  persist(mode);
  return mode;
}

function setAmbientMode(next) {
  if (AMBIENT_MODES.indexOf(next) < 0) return mode;
  clearGraph();
  mode = next;
  persist(mode);
  if (next === 'off') return mode;

  const audioCtx = ensureCtx();
  if (!audioCtx) {
    mode = 'off';
    persist(mode);
    return mode;
  }

  if (next === 'rain') startRain(audioCtx);
  else if (next === 'waves') startWaves(audioCtx);
  else if (next === 'clock') startClock(audioCtx);
  return mode;
}

function initAmbient() {
  mode = readSaved();
  if (mode !== 'off') {
    // 等用户手势再真正起播；此处只恢复偏好
  }
  return mode;
}

module.exports = {
  AMBIENT_MODES,
  AMBIENT_STORAGE_KEY,
  initAmbient,
  getAmbientMode,
  setAmbientMode,
  pauseAmbient,
  stopAmbient,
};
