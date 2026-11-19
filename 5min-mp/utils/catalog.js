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

const scenesJson = require('../shared/scenes.js');
const { t } = require('./i18n');
const prefs = require('./prefs');
const history = require('./history');
const sceneRanker = require('./sceneRanker');

const PRESET_MINS = Object.freeze(scenesJson.presetsMin || [3, 5, 10]);
const DEFAULT_MIN = scenesJson.defaultMin || 5;
const ALERT_DURATION_MS = scenesJson.alertDurationMs || 5000;
const VIBRATE_PATTERN_MS = Object.freeze(
  scenesJson.vibratePatternMs || [500, 150, 500, 150, 500]
);

const GROUPS = Object.freeze(scenesJson.groups || []);
const SCENES = Object.freeze(scenesJson.scenes || []);
const CUSTOM_GROUP_ID = 'custom';
const SUGGESTED_GROUP_ID = sceneRanker.GROUP_ID;

function sceneById(id) {
  return SCENES.find((s) => s.id === id) || null;
}

function knownSceneIds(customScenes) {
  const known = new Set(SCENES.map((s) => s.id));
  (customScenes || []).forEach((s) => known.add(s.id));
  return known;
}

function suggestedSceneIds() {
  const customScenes = prefs.getCustomScenes();
  const unit = t('customUnit');
  const sessions = history.getHistory().map((item) => ({
    sceneId: item.sceneId || '',
    at: item.at || 0,
  }));
  // Drop IDs that no longer resolve (deleted custom, etc.) — avoids empty picker rows.
  return sceneRanker
    .rank(sessions, knownSceneIds(customScenes))
    .filter((id) => !!sceneRow(id, customScenes, unit));
}

function sceneRow(id, customScenes, unit) {
  const custom = (customScenes || []).find((s) => s.id === id);
  if (custom) {
    const name = String(custom.name || '').trim();
    if (!name) return null;
    return {
      id: custom.id,
      min: custom.min,
      label: `${name} · ${custom.min} ${unit}`,
      title: name,
    };
  }
  const scene = sceneById(id);
  if (!scene) return null;
  const label = t(scene.labelKey);
  if (!label || !String(label).trim()) return null;
  return {
    id: scene.id,
    min: scene.min,
    label,
    title: t(scene.titleKey),
  };
}

function buildScenePicker() {
  const customScenes = prefs.getCustomScenes();
  const unit = t('customUnit');
  const suggested = suggestedSceneIds();
  const range = [];
  const scenesByGroup = {};

  // multiSelector: never push a group whose second-column list is empty (shows blank rows).
  const suggestedRows = suggested
    .map((id) => sceneRow(id, customScenes, unit))
    .filter(Boolean);
  if (suggestedRows.length > 0) {
    range.push({
      id: SUGGESTED_GROUP_ID,
      label: t(sceneRanker.LABEL_KEY),
    });
    scenesByGroup[SUGGESTED_GROUP_ID] = suggestedRows;
  }

  const customRows = customScenes
    .map((s) => sceneRow(s.id, customScenes, unit))
    .filter(Boolean);
  if (customRows.length > 0) {
    range.push({
      id: CUSTOM_GROUP_ID,
      label: t('sceneGroupCustom'),
    });
    scenesByGroup[CUSTOM_GROUP_ID] = customRows;
  }

  GROUPS.forEach((g) => {
    const rows = SCENES.filter((s) => s.group === g.id)
      .map((s) => sceneRow(s.id, customScenes, unit))
      .filter(Boolean);
    if (rows.length === 0) return;
    range.push({
      id: g.id,
      label: t(g.labelKey),
    });
    scenesByGroup[g.id] = rows;
  });

  return { range, scenesByGroup, suggested };
}

function resolveSceneTitle(id) {
  if (!id) return null;
  const custom = prefs.getCustomScenes().find((s) => s.id === id);
  if (custom) return custom.name;
  const scene = sceneById(id);
  if (scene) return t(scene.titleKey);
  return null;
}

module.exports = {
  PRESET_MINS,
  DEFAULT_MIN,
  ALERT_DURATION_MS,
  VIBRATE_PATTERN_MS,
  GROUPS,
  SCENES,
  CUSTOM_GROUP_ID,
  SUGGESTED_GROUP_ID,
  sceneById,
  buildScenePicker,
  suggestedSceneIds,
  resolveSceneTitle,
  CHIP_N: sceneRanker.CHIP_N,
};
