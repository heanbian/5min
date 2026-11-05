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

/** 七段电子表：与 5min-web / Android DigitalWatch 对齐（viewBox 144×48） */

const DIGIT_SEGS = Object.freeze([
  'abcdef',
  'bc',
  'abged',
  'abgcd',
  'fgbc',
  'afgcd',
  'afgcde',
  'abc',
  'abcdefg',
  'abfgcd',
]);
const ALL_SEGS = 'abcdefg';
const WATCH_W = 144;
const WATCH_H = 48;
const WATCH_SLOTS = Object.freeze([
  { kind: 'digit', x: 4 },
  { kind: 'digit', x: 34 },
  { kind: 'colon', x: 64 },
  { kind: 'digit', x: 80 },
  { kind: 'digit', x: 110 },
]);

function hBarPath(ctx, x, y, w, t) {
  ctx.beginPath();
  ctx.moveTo(x, y + t / 2);
  ctx.lineTo(x + t / 2, y);
  ctx.lineTo(x + w - t / 2, y);
  ctx.lineTo(x + w, y + t / 2);
  ctx.lineTo(x + w - t / 2, y + t);
  ctx.lineTo(x + t / 2, y + t);
  ctx.closePath();
}

function vBarPath(ctx, x, y, h, t) {
  ctx.beginPath();
  ctx.moveTo(x + t / 2, y);
  ctx.lineTo(x + t, y + t / 2);
  ctx.lineTo(x + t, y + h - t / 2);
  ctx.lineTo(x + t / 2, y + h);
  ctx.lineTo(x, y + h - t / 2);
  ctx.lineTo(x, y + t / 2);
  ctx.closePath();
}

function digitSegMap(ox, oy) {
  const dw = 22;
  const dh = 36;
  const t = 4;
  const gap = 1;
  const mid = dh / 2;
  return {
    a: (ctx) => hBarPath(ctx, ox + 2.5, oy, dw - 5, t),
    g: (ctx) => hBarPath(ctx, ox + 2.5, oy + mid - t / 2, dw - 5, t),
    d: (ctx) => hBarPath(ctx, ox + 2.5, oy + dh - t, dw - 5, t),
    f: (ctx) => vBarPath(ctx, ox, oy + t + gap, mid - t - gap * 2, t),
    b: (ctx) => vBarPath(ctx, ox + dw - t, oy + t + gap, mid - t - gap * 2, t),
    e: (ctx) => vBarPath(ctx, ox, oy + mid + gap, mid - t - gap * 2, t),
    c: (ctx) => vBarPath(ctx, ox + dw - t, oy + mid + gap, mid - t - gap * 2, t),
  };
}

function drawDigit(ctx, d, ox, oy, color) {
  const segs = digitSegMap(ox, oy);
  const on = DIGIT_SEGS[d] || '';
  for (let i = 0; i < ALL_SEGS.length; i += 1) {
    const k = ALL_SEGS[i];
    const draw = segs[k];
    if (!draw) continue;
    draw(ctx);
    ctx.fillStyle = color;
    ctx.globalAlpha = on.indexOf(k) >= 0 ? 1 : 0.05;
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

function drawColon(ctx, ox, oy, color) {
  const cx = ox + 6;
  ctx.fillStyle = color;
  ctx.globalAlpha = 1;
  ctx.beginPath();
  ctx.arc(cx, oy + 10, 2.6, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.arc(cx, oy + 26, 2.6, 0, Math.PI * 2);
  ctx.fill();
}

/**
 * 在 dial 画布中心绘制七段表（不负责清屏）
 * @param {CanvasRenderingContext2D} ctx
 * @param {number} size dial 边长（CSS px）
 * @param {string} timeText 如 "5:00"
 * @param {string} color
 */
function drawDigitalWatch(ctx, size, timeText, color) {
  const raw = String(timeText).replace(/\D/g, '').padStart(4, '0').slice(-4);
  const digits = [raw[0], raw[1], raw[2], raw[3]].map(Number);
  const watchW = size * 0.64;
  const watchH = watchW * (WATCH_H / WATCH_W);
  const scale = Math.min(watchW / WATCH_W, watchH / WATCH_H);
  const dx = (size - WATCH_W * scale) / 2;
  const dy = (size - WATCH_H * scale) / 2;
  const oy = 6;

  ctx.save();
  ctx.translate(dx, dy);
  ctx.scale(scale, scale);

  let di = 0;
  for (let i = 0; i < WATCH_SLOTS.length; i += 1) {
    const slot = WATCH_SLOTS[i];
    if (slot.kind === 'colon') {
      drawColon(ctx, slot.x, oy, color);
    } else {
      drawDigit(ctx, digits[di], slot.x, oy, color);
      di += 1;
    }
  }
  ctx.restore();
}

module.exports = {
  WATCH_W,
  WATCH_H,
  drawDigitalWatch,
};
