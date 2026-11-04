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
 * Procedural ambient loops (rain / waves / clock) via Web Audio — no media assets.
 * Must be started from a user gesture.
 */

export const AMBIENT_MODES = Object.freeze(['off', 'rain', 'waves', 'clock']);

const AudioCtx = globalThis.AudioContext ?? globalThis.webkitAudioContext;

/** @type {AudioContext | null} */
let ctx = null;
/** @type {GainNode | null} */
let master = null;
/** @type {AudioNode[]} */
let nodes = [];
/** @type {number[]} */
let timerIds = [];
/** @type {'off' | 'rain' | 'waves' | 'clock'} */
let mode = 'off';

const preferPlaybackSession = () => {
  try {
    const session = /** @type {{ type?: string }} */ (navigator).audioSession;
    if (session && typeof session === 'object') session.type = 'playback';
  } catch {
    /* ignore */
  }
};

const ensureCtx = async () => {
  if (!AudioCtx) return null;
  preferPlaybackSession();
  ctx ??= new AudioCtx();
  if (ctx.state === 'suspended') {
    try { await ctx.resume(); } catch { /* ignore */ }
  }
  if (!master && ctx) {
    master = ctx.createGain();
    master.gain.value = 0.22;
    master.connect(ctx.destination);
  }
  return ctx;
};

const clearGraph = () => {
  for (const id of timerIds) clearInterval(id);
  timerIds = [];
  for (const node of nodes) {
    try {
      if ('stop' in node && typeof node.stop === 'function') node.stop();
    } catch { /* ignore */ }
    try { node.disconnect(); } catch { /* ignore */ }
  }
  nodes = [];
};

const noiseBuffer = (audioCtx, seconds = 2) => {
  const len = Math.floor(audioCtx.sampleRate * seconds);
  const buffer = audioCtx.createBuffer(1, len, audioCtx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < len; i += 1) data[i] = Math.random() * 2 - 1;
  return buffer;
};

const startRain = (audioCtx) => {
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
};

const startWaves = (audioCtx) => {
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

  // Slow swell
  const swell = () => {
    if (!ctx || mode !== 'waves' || !gain) return;
    const now = ctx.currentTime;
    gain.gain.cancelScheduledValues(now);
    gain.gain.setValueAtTime(gain.gain.value, now);
    gain.gain.linearRampToValueAtTime(0.18 + Math.random() * 0.28, now + 2.2 + Math.random());
  };
  swell();
  timerIds.push(window.setInterval(swell, 2800));
};

const startClock = (audioCtx) => {
  const tick = () => {
    if (!ctx || mode !== 'clock' || !master) return;
    const t0 = ctx.currentTime;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
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
  timerIds.push(window.setInterval(tick, 1000));
};

export const getAmbientMode = () => mode;

export const stopAmbient = () => {
  mode = 'off';
  clearGraph();
};

/**
 * @param {'off' | 'rain' | 'waves' | 'clock'} next
 */
export const setAmbientMode = async (next) => {
  if (!AMBIENT_MODES.includes(next)) return mode;
  clearGraph();
  mode = next;
  if (next === 'off') return mode;

  const audioCtx = await ensureCtx();
  if (!audioCtx || audioCtx.state !== 'running') {
    mode = 'off';
    return mode;
  }

  if (next === 'rain') startRain(audioCtx);
  else if (next === 'waves') startWaves(audioCtx);
  else if (next === 'clock') startClock(audioCtx);
  return mode;
};
