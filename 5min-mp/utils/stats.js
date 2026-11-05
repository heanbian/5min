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

/** Daily usage stats — wx.storage only, never uploaded. */
const STATS_STORAGE_KEY = '5min.dailyStats';

function todayKey() {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function empty(date) {
  return {
    date: date || todayKey(),
    count: 0,
    totalMs: 0,
  };
}

function readRaw() {
  try {
    const parsed = wx.getStorageSync(STATS_STORAGE_KEY);
    if (!parsed || typeof parsed !== 'object') return empty();
    if (parsed.date !== todayKey()) return empty();
    const count = Number(parsed.count);
    const totalMs = Number(parsed.totalMs);
    return {
      date: todayKey(),
      count: Number.isFinite(count) && count > 0 ? Math.floor(count) : 0,
      totalMs: Number.isFinite(totalMs) && totalMs > 0 ? Math.floor(totalMs) : 0,
    };
  } catch (e) {
    return empty();
  }
}

function writeRaw(data) {
  try {
    wx.setStorageSync(STATS_STORAGE_KEY, data);
  } catch (e) {
    /* quota / private mode */
  }
}

function getTodayStats() {
  return readRaw();
}

function recordCompletedSession(elapsedMs) {
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  if (ms <= 0) return getTodayStats();
  const cur = readRaw();
  const next = {
    date: todayKey(),
    count: cur.count + 1,
    totalMs: cur.totalMs + ms,
  };
  writeRaw(next);
  return next;
}

function statsMinutes(totalMs) {
  const ms = Math.max(0, Number(totalMs) || 0);
  if (ms <= 0) return 0;
  return Math.max(1, Math.round(ms / 60000));
}

module.exports = {
  STATS_STORAGE_KEY,
  getTodayStats,
  recordCompletedSession,
  statsMinutes,
};
