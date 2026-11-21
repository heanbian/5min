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

/** Daily usage stats — localStorage only, never uploaded. */
export const STATS_STORAGE_KEY = '5min.dailyStats';
/** Lightweight scene sessions for picker ranking (14-day window, local only). */
export const SCENE_SESSIONS_KEY = '5min.sceneSessions';
const SCENE_HISTORY_DAYS = 14;
const SCENE_HISTORY_MAX = 200;

const todayKey = () => {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
};

const empty = (date = todayKey()) => ({
  date,
  count: 0,
  totalMs: 0,
});

const readRaw = () => {
  try {
    const raw = localStorage.getItem(STATS_STORAGE_KEY);
    if (!raw) return empty();
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return empty();
    if (parsed.date !== todayKey()) return empty();
    const count = Number(parsed.count);
    const totalMs = Number(parsed.totalMs);
    return {
      date: todayKey(),
      count: Number.isFinite(count) && count > 0 ? Math.floor(count) : 0,
      totalMs: Number.isFinite(totalMs) && totalMs > 0 ? Math.floor(totalMs) : 0,
    };
  } catch {
    return empty();
  }
};

const writeRaw = (data) => {
  try {
    localStorage.setItem(STATS_STORAGE_KEY, JSON.stringify(data));
  } catch {
    /* private mode / quota */
  }
};

/** @returns {{ date: string, count: number, totalMs: number }} */
export const getTodayStats = () => readRaw();

/**
 * Record one completed countdown (called on finish).
 * @param {number} elapsedMs duration completed for this session
 * @param {string} [sceneId]
 */
export const recordCompletedSession = (elapsedMs, sceneId = '') => {
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  if (ms <= 0) return getTodayStats();
  const cur = readRaw();
  const next = {
    date: todayKey(),
    count: cur.count + 1,
    totalMs: cur.totalMs + ms,
  };
  writeRaw(next);
  recordSceneSession(sceneId);
  return next;
};

const readSceneSessions = () => {
  try {
    const raw = localStorage.getItem(SCENE_SESSIONS_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    const cut = Date.now() - SCENE_HISTORY_DAYS * 24 * 60 * 60 * 1000;
    return parsed
      .map((row) => ({
        sceneId: String((row && row.sceneId) || '').trim(),
        at: Math.floor(Number(row && row.at) || 0),
      }))
      .filter((row) => row.sceneId && row.at >= cut)
      .slice(0, SCENE_HISTORY_MAX);
  } catch {
    return [];
  }
};

const writeSceneSessions = (list) => {
  try {
    localStorage.setItem(SCENE_SESSIONS_KEY, JSON.stringify(list.slice(0, SCENE_HISTORY_MAX)));
  } catch {
    /* private mode / quota */
  }
};

/** @param {string} sceneId */
export const recordSceneSession = (sceneId) => {
  const id = String(sceneId || '').trim();
  if (!id) return getSceneSessions();
  const next = [{ sceneId: id, at: Date.now() }, ...readSceneSessions()].slice(0, SCENE_HISTORY_MAX);
  writeSceneSessions(next);
  return next;
};

/** @returns {{sceneId:string,at:number}[]} */
export const getSceneSessions = () => readSceneSessions();

/** Whole minutes for display (minimum 1 when there is any recorded time under 60s). */
export const statsMinutes = (totalMs) => {
  const ms = Math.max(0, Number(totalMs) || 0);
  if (ms <= 0) return 0;
  return Math.max(1, Math.round(ms / 60_000));
};
