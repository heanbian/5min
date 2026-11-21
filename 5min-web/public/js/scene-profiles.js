/**
 * Locale scene display profiles — pin / group order / demote / hide.
 * Data: scene-profiles-data.js (from shared-export/locale-scene-profiles.json via export-shared).
 * SPDX-License-Identifier: Apache-2.0
 */
import RAW from './scene-profiles-data.js';

/** @typedef {{ pin: string[], groupOrder: string[], demoteGroups: string[], hideGroups: string[], hideScenes: string[] }} SceneProfile */

const emptyList = () => /** @type {string[]} */ ([]);

/** @type {Map<string, SceneProfile>} */
const profileCache = new Map();

/**
 * @param {string} locale
 * @returns {SceneProfile}
 */
export function resolveSceneProfile(locale) {
  const key = locale || 'default';
  const hit = profileCache.get(key);
  if (hit) return hit;
  const base = RAW.default || {};
  const over = RAW[locale] || {};
  const profile = {
    pin: Array.isArray(over.pin) ? over.pin.slice() : (base.pin || emptyList()).slice(),
    groupOrder: Array.isArray(over.groupOrder)
      ? over.groupOrder.slice()
      : (base.groupOrder || emptyList()).slice(),
    demoteGroups: Array.isArray(over.demoteGroups)
      ? over.demoteGroups.slice()
      : (base.demoteGroups || emptyList()).slice(),
    hideGroups: Array.isArray(over.hideGroups)
      ? over.hideGroups.slice()
      : (base.hideGroups || emptyList()).slice(),
    hideScenes: Array.isArray(over.hideScenes)
      ? over.hideScenes.slice()
      : (base.hideScenes || emptyList()).slice(),
  };
  profileCache.set(key, profile);
  return profile;
}

/**
 * @template {{ id: string }} T
 * @param {T[]} groups
 * @param {SceneProfile} profile
 * @returns {T[]}
 */
export function orderSceneGroups(groups, profile) {
  const hide = new Set(profile.hideGroups || []);
  const demote = new Set(profile.demoteGroups || []);
  const byId = new Map(groups.map((g) => [g.id, g]));
  const primary = [];
  const seen = new Set();
  for (const id of profile.groupOrder || []) {
    if (hide.has(id) || demote.has(id) || seen.has(id)) continue;
    const g = byId.get(id);
    if (!g) continue;
    primary.push(g);
    seen.add(id);
  }
  for (const g of groups) {
    if (hide.has(g.id) || demote.has(g.id) || seen.has(g.id)) continue;
    primary.push(g);
    seen.add(g.id);
  }
  const demoted = [];
  for (const id of profile.groupOrder || []) {
    if (!demote.has(id) || hide.has(id) || seen.has(id)) continue;
    const g = byId.get(id);
    if (!g) continue;
    demoted.push(g);
    seen.add(id);
  }
  for (const g of groups) {
    if (!demote.has(g.id) || hide.has(g.id) || seen.has(g.id)) continue;
    demoted.push(g);
    seen.add(g.id);
  }
  return primary.concat(demoted);
}

/**
 * @param {string} sceneId
 * @param {SceneProfile} profile
 */
export function isSceneHidden(sceneId, profile) {
  return (profile.hideScenes || []).includes(sceneId);
}

/**
 * Pin first, then ranked usage ids; unique; capped.
 * Skips hideScenes so the result can still fill to topN from ranked.
 * @param {string[]} ranked
 * @param {string[]} pin
 * @param {Set<string>|string[]} knownIds
 * @param {number} [topN=6]
 * @param {Set<string>|string[]} [hideScenes]
 */
export function mergePinnedSuggested(ranked, pin, knownIds, topN = 6, hideScenes = []) {
  const known = knownIds instanceof Set ? knownIds : new Set(knownIds);
  const hidden =
    hideScenes instanceof Set ? hideScenes : new Set(hideScenes || []);
  const out = [];
  const seen = new Set();
  const take = (id) => {
    if (!known.has(id) || seen.has(id) || hidden.has(id)) return false;
    out.push(id);
    seen.add(id);
    return out.length >= topN;
  };
  for (const id of pin || []) {
    if (take(id)) return out;
  }
  for (const id of ranked || []) {
    if (take(id)) return out;
  }
  return out;
}
