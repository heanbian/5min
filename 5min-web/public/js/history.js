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
 * Local session history (localStorage), 14-day retention —
 * API shape mirrors 5min-mp/utils/history.js.
 */

export const HISTORY_DAYS = 14;
export const STORAGE_KEY = '5min.chat.history.v1';

const makeRowId = (at) => {
  const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
  return `${at}_${uuid}`;
};

const cutoffMs = () => Date.now() - HISTORY_DAYS * 24 * 60 * 60 * 1000;

const todayStartMs = () => {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
};

/** Local calendar day key YYYY-MM-DD */
const dayKeyFromMs = (ms) => {
  const d = new Date(ms);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const readAll = () => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .filter((row) => row && Number(row.at) > 0 && Number(row.minutes) > 0)
      .map((row) => ({
        id: String(row.id || `legacy_${Math.floor(Number(row.at))}`),
        at: Math.floor(Number(row.at)),
        minutes: Math.floor(Number(row.minutes)),
        sceneId: String(row.sceneId || ''),
        elapsedMs: Math.max(0, Math.floor(Number(row.elapsedMs) || 0)),
      }));
  } catch {
    return [];
  }
};

const writeAll = (list) => {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
  } catch {
    /* private mode / quota */
  }
};

const prune = (list) => {
  const cut = cutoffMs();
  return list.filter((row) => row.at >= cut);
};

/**
 * @param {number} elapsedMs
 * @param {string} [sceneId]
 * @returns {string} session id (empty when skipped)
 */
export const recordSession = (elapsedMs, sceneId = '') => {
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  if (ms <= 0) return '';
  const minutes = Math.max(1, Math.round(ms / 60_000));
  const at = Date.now();
  const id = makeRowId(at);
  const next = prune(readAll());
  next.push({
    id,
    at,
    minutes,
    sceneId: sceneId ? String(sceneId) : '',
    elapsedMs: ms,
  });
  writeAll(next);
  return id;
};

/**
 * @param {string} id
 * @param {number} elapsedMs
 */
export const updateSessionElapsed = (id, elapsedMs) => {
  if (!id) return;
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  const minutes = Math.max(1, Math.round(ms / 60_000));
  const list = prune(readAll());
  const idx = list.findIndex((row) => row.id === id);
  if (idx < 0) return;
  list[idx] = { ...list[idx], minutes, elapsedMs: ms };
  writeAll(list);
};

/** @param {string} id */
export const deleteSession = (id) => {
  if (!id) return;
  writeAll(prune(readAll()).filter((row) => row.id !== id));
};

export const clearHistory = () => {
  writeAll([]);
};

/** Replace local history with a sanitized list (cloud merge). */
export const replaceAll = (list) => {
  const cleaned = (Array.isArray(list) ? list : [])
    .filter((row) => row && Number(row.at) > 0 && Number(row.minutes) > 0)
    .map((row) => ({
      id: String(row.id || makeRowId(Math.floor(Number(row.at)))),
      at: Math.floor(Number(row.at)),
      minutes: Math.floor(Number(row.minutes)),
      sceneId: String(row.sceneId || ''),
      elapsedMs: Math.max(0, Math.floor(Number(row.elapsedMs) || 0)),
    }));
  writeAll(prune(cleaned));
};

/**
 * Sessions in last HISTORY_DAYS, newest first; optional sceneId filter.
 * @param {string} [sceneId]
 */
export const getHistory = (sceneId) => {
  // Read-only: pruning persists on write paths (record/delete/clear/replace).
  let list = prune(readAll());
  if (sceneId) {
    const sid = String(sceneId);
    list = list.filter((row) => row.sceneId === sid);
  }
  return list.slice().sort((a, b) => b.at - a.at);
};

/** Alias of getHistory — product Batch B naming. */
export const listSessions = (sceneId) => getHistory(sceneId);

export const periodStats = () => {
  const list = getHistory();
  let mins = 0;
  for (let i = 0; i < list.length; i += 1) mins += list[i].minutes;
  return { count: list.length, minutes: mins };
};

export const todayStats = () => {
  const start = todayStartMs();
  const list = prune(readAll());
  let count = 0;
  let ms = 0;
  for (let i = 0; i < list.length; i += 1) {
    const row = list[i];
    if (row.at < start) continue;
    count += 1;
    ms += row.elapsedMs > 0 ? row.elapsedMs : row.minutes * 60_000;
  }
  return { count, totalMs: ms };
};

/** Alias of todayStats. */
export const getTodayStats = () => todayStats();

/**
 * Consecutive local calendar days (ending today or yesterday) with ≥1 session.
 * @param {Array<{at:number}>} [list] optional preloaded history (avoids extra read)
 * @returns {number}
 */
export const getStreak = (list) => {
  const rows = list || getHistory();
  if (!rows.length) return 0;
  const days = new Set(rows.map((row) => dayKeyFromMs(row.at)));
  const cursor = new Date();
  cursor.setHours(0, 0, 0, 0);
  const today = dayKeyFromMs(cursor.getTime());
  if (!days.has(today)) {
    cursor.setDate(cursor.getDate() - 1);
    const yday = dayKeyFromMs(cursor.getTime());
    if (!days.has(yday)) return 0;
  }
  let streak = 0;
  while (days.has(dayKeyFromMs(cursor.getTime()))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
};

/** Period count/mins + streak from a single history read. */
export const shareSummaryValues = () => {
  const list = getHistory();
  let mins = 0;
  for (let i = 0; i < list.length; i += 1) mins += list[i].minutes;
  return {
    count: list.length,
    minutes: mins,
    streak: getStreak(list),
  };
};

