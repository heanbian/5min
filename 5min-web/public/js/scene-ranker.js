/**
 * On-device scene ranking from local session history (shared rules with native/MP).
 * SPDX-License-Identifier: Apache-2.0
 */

export const GROUP_ID = 'suggested';
export const LABEL_KEY = 'sceneGroupSuggested';
export const TOP_N = 6;
export const CHIP_N = 5;
const MIN_COUNT = 2;
const RECENT_DAYS = 3;
const HISTORY_WINDOW_DAYS = 14;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * @param {{sceneId:string,at:number}[]} sessions
 * @param {Set<string>|string[]} knownIds
 * @param {number} [nowMs]
 * @returns {string[]}
 */
export function rank(sessions, knownIds, nowMs) {
  const now = typeof nowMs === 'number' ? nowMs : Date.now();
  const known = knownIds instanceof Set ? knownIds : new Set(knownIds || []);
  const countById = new Map();
  const lastAtById = new Map();
  const sameHourById = new Map();
  const nowHour = new Date(now).getHours();
  for (const session of sessions || []) {
    const id = String((session && session.sceneId) || '').trim();
    if (!id || !known.has(id)) continue;
    countById.set(id, (countById.get(id) || 0) + 1);
    const at = Number(session.at) || 0;
    const prev = lastAtById.get(id);
    if (prev === undefined || at > prev) lastAtById.set(id, at);
    if (at > 0 && new Date(at).getHours() === nowHour) {
      sameHourById.set(id, (sameHourById.get(id) || 0) + 1);
    }
  }
  const ranked = [];
  for (const [id, count] of countById) {
    const lastAt = lastAtById.get(id) || 0;
    const daysSince = Math.max(0, Math.floor((now - lastAt) / DAY_MS));
    if (!(count >= MIN_COUNT || daysSince <= RECENT_DAYS)) continue;
    const hourBoost = (sameHourById.get(id) || 0) * 12;
    const score = count * 100 + Math.max(0, HISTORY_WINDOW_DAYS - daysSince) + hourBoost;
    ranked.push({ id, score, lastAt });
  }
  ranked.sort((a, b) => (a.score !== b.score ? b.score - a.score : b.lastAt - a.lastAt));
  return ranked.slice(0, TOP_N).map((r) => r.id);
}
