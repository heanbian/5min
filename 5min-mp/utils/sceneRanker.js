/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * On-device scene ranking from local session history (shared rules across clients).
 */

const GROUP_ID = 'suggested';
const LABEL_KEY = 'sceneGroupSuggested';
const TOP_N = 6;
const CHIP_N = 5;
const MIN_COUNT = 2;
const RECENT_DAYS = 3;
const HISTORY_WINDOW_DAYS = 14;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Rank known scenes by frequency + recency. Empty when nothing qualifies (cold start).
 * @param {{sceneId:string,at:number}[]} sessions
 * @param {Set<string>|string[]} knownIds
 * @param {number} [nowMs]
 * @returns {string[]}
 */
function rank(sessions, knownIds, nowMs) {
  const now = typeof nowMs === 'number' ? nowMs : Date.now();
  const known =
    knownIds instanceof Set ? knownIds : new Set(knownIds || []);
  const countById = new Map();
  const lastAtById = new Map();
  const sameHourById = new Map();
  const nowHour = new Date(now).getHours();
  (sessions || []).forEach((session) => {
    const id = String((session && session.sceneId) || '').trim();
    if (!id || !known.has(id)) return;
    countById.set(id, (countById.get(id) || 0) + 1);
    const at = Number(session.at) || 0;
    const prev = lastAtById.get(id);
    if (prev === undefined || at > prev) lastAtById.set(id, at);
    if (at > 0 && new Date(at).getHours() === nowHour) {
      sameHourById.set(id, (sameHourById.get(id) || 0) + 1);
    }
  });
  const ranked = [];
  countById.forEach((count, id) => {
    const lastAt = lastAtById.get(id) || 0;
    const daysSince = Math.max(0, Math.floor((now - lastAt) / DAY_MS));
    const qualifies = count >= MIN_COUNT || daysSince <= RECENT_DAYS;
    if (!qualifies) return;
    const hourBoost = (sameHourById.get(id) || 0) * 12;
    const score = count * 100 + Math.max(0, HISTORY_WINDOW_DAYS - daysSince) + hourBoost;
    ranked.push({ id, score, lastAt });
  });
  ranked.sort((a, b) => {
    if (a.score !== b.score) return b.score - a.score;
    return b.lastAt - a.lastAt;
  });
  return ranked.slice(0, TOP_N).map((r) => r.id);
}

module.exports = {
  GROUP_ID,
  LABEL_KEY,
  TOP_N,
  CHIP_N,
  MIN_COUNT,
  RECENT_DAYS,
  HISTORY_WINDOW_DAYS,
  DAY_MS,
  rank,
};
