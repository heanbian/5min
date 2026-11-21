/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Locale scene display profiles — pin / group order / demote / hide.
 */

const RAW = require('../shared/locale-scene-profiles.js');

const profileCache = Object.create(null);

function emptyList() {
  return [];
}

function resolveSceneProfile(locale) {
  const key = locale || 'default';
  if (profileCache[key]) return profileCache[key];
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
  profileCache[key] = profile;
  return profile;
}

function orderSceneGroups(groups, profile) {
  const hide = {};
  (profile.hideGroups || []).forEach((id) => {
    hide[id] = true;
  });
  const demote = {};
  (profile.demoteGroups || []).forEach((id) => {
    demote[id] = true;
  });
  const byId = {};
  (groups || []).forEach((g) => {
    byId[g.id] = g;
  });
  const primary = [];
  const seen = {};
  (profile.groupOrder || []).forEach((id) => {
    if (hide[id] || demote[id] || seen[id]) return;
    const g = byId[id];
    if (!g) return;
    primary.push(g);
    seen[id] = true;
  });
  (groups || []).forEach((g) => {
    if (hide[g.id] || demote[g.id] || seen[g.id]) return;
    primary.push(g);
    seen[g.id] = true;
  });
  const demoted = [];
  (profile.groupOrder || []).forEach((id) => {
    if (!demote[id] || hide[id] || seen[id]) return;
    const g = byId[id];
    if (!g) return;
    demoted.push(g);
    seen[id] = true;
  });
  (groups || []).forEach((g) => {
    if (!demote[g.id] || hide[g.id] || seen[g.id]) return;
    demoted.push(g);
    seen[g.id] = true;
  });
  return primary.concat(demoted);
}

function isSceneHidden(sceneId, profile) {
  return (profile.hideScenes || []).indexOf(sceneId) >= 0;
}

function mergePinnedSuggested(ranked, pin, knownIds, topN, hideScenes) {
  const limit = typeof topN === 'number' ? topN : 6;
  const known =
    knownIds instanceof Set ? knownIds : new Set(knownIds || []);
  const hidden = Object.create(null);
  (hideScenes || []).forEach((id) => {
    hidden[id] = true;
  });
  const out = [];
  const seen = Object.create(null);
  const take = (id) => {
    if (out.length >= limit) return true;
    if (!known.has(id) || seen[id] || hidden[id]) return false;
    out.push(id);
    seen[id] = true;
    return out.length >= limit;
  };
  (pin || []).some(take);
  (ranked || []).some(take);
  return out;
}

module.exports = {
  resolveSceneProfile,
  orderSceneGroups,
  isSceneHidden,
  mergePinnedSuggested,
};
