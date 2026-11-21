'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  sanitizePrefs,
  sanitizeSession,
} = require('../bizjs/cloud-storage');

describe('cloud-storage sanitize', () => {
  it('defaults prefs and clamps fields', () => {
    const p = sanitizePrefs({
      ambient: 'rain',
      storageMode: 'cloud',
      customMin: 999,
      customScenes: [{ id: 'c1', name: '  Focus  ', min: 3 }],
    });
    assert.equal(p.ambient, 'rain');
    assert.equal(p.storageMode, 'cloud');
    assert.equal(p.customMin, 90);
    assert.equal(p.customScenes.length, 1);
    assert.equal(p.customScenes[0].name, 'Focus');
    assert.equal(p.customScenes[0].min, 3);
    assert.equal(p.standRitual, 'basic');
    assert.equal(p.alertProfile, 'normal');
    assert.equal(p.overtimeInsight, true);
  });

  it('sanitizes P0 preference fields', () => {
    const p = sanitizePrefs({
      standRitual: 'off',
      alertProfile: 'silent',
      overtimeInsight: false,
    });
    assert.equal(p.standRitual, 'off');
    assert.equal(p.alertProfile, 'silent');
    assert.equal(p.overtimeInsight, false);
    assert.equal(sanitizePrefs({ alertProfile: 'loud' }).alertProfile, 'normal');
  });

  it('rejects invalid storageMode to local', () => {
    assert.equal(sanitizePrefs({ storageMode: 'usb' }).storageMode, 'local');
  });

  it('accepts session clientId alias id', () => {
    const s = sanitizeSession({ id: 'abc', at: 1000, minutes: 5, sceneId: 'toilet' });
    assert.equal(s.clientId, 'abc');
    assert.equal(s.minutes, 5);
    assert.equal(s.deleted, false);
  });

  it('allows deleted tombstone without positive minutes', () => {
    const s = sanitizeSession({ clientId: 'x', at: 1, deleted: true, minutes: 0 });
    assert.ok(s);
    assert.equal(s.deleted, true);
  });
});
