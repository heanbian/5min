/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Local session history (wx.storage), 14-day retention — product parity with
 * Harmony HistoryStore RDB under 5min-chat. Survives upgrades (same storage).
 */

const HISTORY_DAYS = 14;
const STORAGE_KEY = '5min.chat.history.v1';

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

function recordSession(elapsedMs, sceneId) {
  const ms = Math.max(0, Math.floor(Number(elapsedMs) || 0));
  if (ms <= 0) return;
  const minutes = Math.max(1, Math.round(ms / 60000));
  const next = prune(readAll());
  next.push({
    at: Date.now(),
    minutes,
    sceneId: sceneId ? String(sceneId) : '',
    elapsedMs: ms,
  });
  writeAll(next);
}

/** Sessions in last HISTORY_DAYS, newest first. */
function getHistory() {
  const list = prune(readAll());
  writeAll(list);
  return list.slice().sort((a, b) => b.at - a.at);
}

function periodStats() {
  const list = getHistory();
  let mins = 0;
  for (let i = 0; i < list.length; i += 1) mins += list[i].minutes;
  return { count: list.length, minutes: mins };
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
  getHistory,
  periodStats,
  todayStats,
};
