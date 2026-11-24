/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Consecutive local calendar days with ≥1 completed session.
 */

const history = require('./history');

function dayKeyFromMs(ms) {
  const d = new Date(ms);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/**
 * Streak ending today (or yesterday if today has no session yet).
 * @param {Array<{at:number}>} [list] optional preloaded history (avoids extra read)
 * @returns {number}
 */
function getStreak(list) {
  const rows = list || history.getHistory();
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
}

module.exports = {
  getStreak,
  dayKeyFromMs,
};
