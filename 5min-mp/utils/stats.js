/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Today stats — backed by history store (14-day). Keeps prior API for callers.
 */

const history = require('./history');

function getTodayStats() {
  return history.todayStats();
}

function recordCompletedSession(elapsedMs, sceneId) {
  history.recordSession(elapsedMs, sceneId || '');
  return history.todayStats();
}

function statsMinutes(totalMs) {
  const ms = Math.max(0, Number(totalMs) || 0);
  if (ms <= 0) return 0;
  return Math.max(1, Math.round(ms / 60000));
}

module.exports = {
  getTodayStats,
  recordCompletedSession,
  statsMinutes,
};
