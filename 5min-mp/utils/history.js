/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Local session history (wx.storage), 14-day retention — product parity with
 * Harmony HistoryStore RDB under 5min-chat. Survives upgrades (same storage).
 */

const HISTORY_DAYS = 14;
const STORAGE_KEY = '5min.chat.history.v1';

function makeRowId(at) {
  const uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
  return `${at}_${uuid}`;
}

function cutoffMs() {
  return Date.now() - HISTORY_DAYS * 24 * 60 * 60 * 1000;
}

function todayStartMs() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

function readAll() {
  try {
    const raw = wx.getStorageSync(STORAGE_KEY);
    if (!Array.isArray(raw)) return [];
    return raw
      .filter((row) => row && Number(row.at) > 0 && Number(row.minutes) > 0)
      .map((row) => ({
        id: String(row.id || `legacy_${Math.floor(Number(row.at))}`),
        at: Math.floor(Number(row.at)),
        minutes: Math.floor(Number(row.minutes)),
        sceneId: String(row.sceneId || ''),
        elapsedMs: Math.max(0, Math.floor(Number(row.elapsedMs) || 0)),
      }));
  } catch (e) {
    return [];
  }
}

function writeAll(list) {
  try {
    wx.setStorageSync(STORAGE_KEY, list);
  } catch (e) {
    /* quota */
  }
}

function prune(list) {
  const cut = cutoffMs();
  return list.filter((row) => row.at >= cut);
}

function scheduleCloudPush() {
  try {
    const prefs = require('./prefs');
    if (prefs.getStorageMode() !== 'cloud') return;
    clearTimeout(scheduleCloudPush._timer);
    scheduleCloudPush._timer = setTimeout(() => {
      try {
        require('./cloudSync')
          .pushSessionsOnly()
          .catch(() => {});
      } catch (e) {
        /* ignore */
      }
    }, 800);
  } catch (e) {
    /* ignore */
  }
}

function recordSession(elapsedMs, sceneId) {
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  if (ms <= 0) return '';
  const minutes = Math.max(1, Math.round(ms / 60000));
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
  scheduleCloudPush();
  return id;
}

function updateSessionElapsed(id, elapsedMs) {
  if (!id) return;
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  const minutes = Math.max(1, Math.round(ms / 60000));
  const list = prune(readAll());
  const idx = list.findIndex((row) => row.id === id);
  if (idx < 0) return;
  list[idx] = { ...list[idx], minutes, elapsedMs: ms };
  writeAll(list);
}

function deleteSession(id) {
  if (!id) return;
  const list = prune(readAll()).filter((row) => row.id !== id);
  writeAll(list);
  try {
    const prefs = require('./prefs');
    if (prefs.getStorageMode() === 'cloud') {
      require('./cloudSync')
        .deleteRemoteSession(id)
        .catch(() => {});
    }
  } catch (e) {
    /* ignore */
  }
}

function clearHistory() {
  writeAll([]);
  try {
    const prefs = require('./prefs');
    if (prefs.getStorageMode() === 'cloud') {
      require('./cloudSync')
        .clearRemoteSessions()
        .catch(() => {});
    }
  } catch (e) {
    /* ignore */
  }
}

/** Replace local history with a sanitized list (used by cloud merge). */
function replaceAll(list) {
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
}

/** Sessions in last HISTORY_DAYS, newest first; optional sceneId filter. */
function getHistory(sceneId) {
  let list = prune(readAll());
  writeAll(list);
  if (sceneId) {
    const sid = String(sceneId);
    list = list.filter((row) => row.sceneId === sid);
  }
  return list.slice().sort((a, b) => b.at - a.at);
}

/** Period count/mins + streak from a single history read. */
function shareSummaryValues() {
  const { getStreak } = require('./streak');
  const list = getHistory();
  let mins = 0;
  for (let i = 0; i < list.length; i += 1) mins += list[i].minutes;
  return {
    count: list.length,
    minutes: mins,
    streak: getStreak(list),
  };
}

function todayStats() {
  const start = todayStartMs();
  const list = prune(readAll());
  let count = 0;
  let ms = 0;
  for (let i = 0; i < list.length; i += 1) {
    const row = list[i];
    if (row.at < start) continue;
    count += 1;
    ms += row.elapsedMs > 0 ? row.elapsedMs : row.minutes * 60000;
  }
  return { count, totalMs: ms };
}

module.exports = {
  HISTORY_DAYS,
  STORAGE_KEY,
  recordSession,
  updateSessionElapsed,
  deleteSession,
  clearHistory,
  replaceAll,
  getHistory,
  shareSummaryValues,
  todayStats,
};