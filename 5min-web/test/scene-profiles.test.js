'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');

const root = path.join(__dirname, '..');
const profilesPath = path.join(root, 'shared-export', 'locale-scene-profiles.json');
const scenesPath = path.join(root, 'shared-export', 'scenes.json');

test('locale-scene-profiles pins and groups reference catalog ids', () => {
  const profiles = JSON.parse(fs.readFileSync(profilesPath, 'utf8'));
  const scenesRoot = JSON.parse(fs.readFileSync(scenesPath, 'utf8'));
  const sceneIds = new Set(scenesRoot.scenes.map((s) => s.id));
  const groupIds = new Set(scenesRoot.groups.map((g) => g.id));

  assert.ok(profiles.default, 'missing default profile');
  for (const [locale, raw] of Object.entries(profiles)) {
    for (const id of raw.pin || []) {
      assert.ok(sceneIds.has(id), `${locale} pin unknown scene ${id}`);
    }
    for (const id of raw.groupOrder || []) {
      assert.ok(groupIds.has(id), `${locale} groupOrder unknown ${id}`);
    }
    for (const id of raw.demoteGroups || []) {
      assert.ok(groupIds.has(id), `${locale} demoteGroups unknown ${id}`);
    }
    for (const id of raw.hideGroups || []) {
      assert.ok(groupIds.has(id), `${locale} hideGroups unknown ${id}`);
    }
    for (const id of raw.hideScenes || []) {
      assert.ok(sceneIds.has(id), `${locale} hideScenes unknown ${id}`);
    }
  }
});

test('scene-profiles helpers: pin-first merge and demote order', async () => {
  const mod = await import(
    pathToFileURL(path.join(root, 'public/js/scene-profiles.js')).href
  );
  const profile = mod.resolveSceneProfile('ja');
  assert.deepEqual(profile.pin.slice(0, 3), ['toilet', 'bathSoak', 'noodles']);

  const groups = [
    { id: 'farm' },
    { id: 'daily' },
    { id: 'transit' },
    { id: 'kitchen' },
    { id: 'labor' },
  ];
  assert.deepEqual(
    mod.orderSceneGroups(groups, profile).map((g) => g.id),
    ['daily', 'kitchen', 'transit', 'labor', 'farm']
  );

  const merged = mod.mergePinnedSuggested(
    ['focus', 'walk'],
    profile.pin,
    new Set(['toilet', 'bathSoak', 'noodles', 'tea', 'shower', 'focus', 'walk']),
    6
  );
  assert.equal(merged[0], 'toilet');
  assert.ok(merged.includes('focus'));
  assert.equal(merged.length, 6);

  const withHide = mod.mergePinnedSuggested(
    ['focus', 'walk', 'coffee'],
    ['toilet', 'focus'],
    new Set(['toilet', 'focus', 'walk', 'coffee']),
    3,
    ['focus']
  );
  assert.deepEqual(withHide, ['toilet', 'walk', 'coffee']);
});
