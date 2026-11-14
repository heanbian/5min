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

const PRESET_MINS = Object.freeze(scenesJson.presetsMin || [3, 5, 10]);
const DEFAULT_MIN = scenesJson.defaultMin || 5;
const ALERT_DURATION_MS = scenesJson.alertDurationMs || 5000;
const VIBRATE_PATTERN_MS = Object.freeze(
  scenesJson.vibratePatternMs || [500, 150, 500, 150, 500]
);

const GROUPS = Object.freeze(scenesJson.groups || []);
const SCENES = Object.freeze(scenesJson.scenes || []);
const CUSTOM_GROUP_ID = 'custom';

function sceneById(id) {
  return SCENES.find((s) => s.id === id) || null;
}

function buildScenePicker() {
  const customScenes = prefs.getCustomScenes();
  const unit = t('customUnit');
  const range = GROUPS.map((g) => ({
    id: g.id,
    label: t(g.labelKey),
  }));
  if (customScenes.length > 0) {
    range.unshift({
      id: CUSTOM_GROUP_ID,
      label: t('sceneGroupCustom'),
    });
  }
  const scenesByGroup = {};
  GROUPS.forEach((g) => {
    scenesByGroup[g.id] = SCENES.filter((s) => s.group === g.id).map((s) => ({
      id: s.id,
      min: s.min,
      label: t(s.labelKey),
      title: t(s.titleKey),
    }));
  });
  if (customScenes.length > 0) {
    scenesByGroup[CUSTOM_GROUP_ID] = customScenes.map((s) => ({
      id: s.id,
      min: s.min,
      label: `${s.name} · ${s.min} ${unit}`,
      title: s.name,
    }));
  }
  return { range, scenesByGroup };
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
  sceneById,
  buildScenePicker,
  resolveSceneTitle,
};
