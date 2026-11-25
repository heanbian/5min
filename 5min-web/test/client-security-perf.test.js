'use strict';

/**
 * Client-side security + performance smoke for Plan A modules
 * (history export, recovery code, p0 features).
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { performance } = require('node:perf_hooks');

const publicJs = (name) =>
  pathToFileURL(path.join(__dirname, '../public/js', name)).href;

function mockStorage() {
  const map = new Map();
  globalThis.localStorage = {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => {
      map.set(k, String(v));
    },
    removeItem: (k) => {
      map.delete(k);
    },
  };
}

test('recovery code parse rejects malformed / short secrets', async () => {
  mockStorage();
  const prefs = await import(publicJs('prefs.js'));
  assert.equal(prefs.parseRecoveryCode(''), null);
  assert.equal(prefs.parseRecoveryCode('not-a-code'), null);
  assert.equal(prefs.parseRecoveryCode('abc:def'), null);
  assert.equal(
    prefs.parseRecoveryCode('00000000-0000-4000-8000-000000000001:abcd'),
    null,
  );
  // UUID version nibble must be 1–5; variant must be 8/9/a/b.
  assert.equal(
    prefs.parseRecoveryCode(
      `00000000-0000-0000-0000-000000000001:${'a'.repeat(64)}`,
    ),
    null,
  );
  const ok = prefs.parseRecoveryCode(
    `00000000-0000-4000-8000-000000000001:${'ab'.repeat(32)}`,
  );
  assert.ok(ok);
  assert.equal(ok.deviceId, '00000000-0000-4000-8000-000000000001');
  assert.equal(ok.deviceSecret.length, 64);
});

test('history CSV escapes formula injection and updates elapsed', async () => {
  mockStorage();
  const history = await import(publicJs('history.js'));
  const id = history.recordSession(300_000, 'toilet');
  history.updateSessionElapsed(id, 420_000);
  const rows = history.getHistory();
  assert.equal(rows[0].elapsedMs, 420_000);
  assert.equal(rows[0].minutes, 7);

  const evilId = history.recordSession(60_000, 'x');
  // Inject a malicious scene label via export callback.
  const csv = history.exportHistoryCsv((row) => {
    if (row.id === evilId) return '=CMD|"/c calc"!A1';
    return row.sceneId;
  }, 'Time,Scene,Planned min,Actual min');
  // Formula neutralized with leading quote, then CSV-quoted because of embedded ".
  assert.match(csv, /"'=CMD\|""\/c calc""!A1"/);
  assert.ok(!csv.split('\n').some((line) => /(^|,)=CMD/.test(line)));
  assert.equal(typeof history.escapeCsvCell, 'function');
  assert.equal(history.escapeCsvCell('+1+1'), "'+1+1");
});

test('history export of 500 rows stays fast', async () => {
  mockStorage();
  const history = await import(publicJs('history.js'));
  const t0 = performance.now();
  for (let i = 0; i < 500; i += 1) {
    history.recordSession(60_000, i % 2 ? 'toilet' : 'brush');
  }
  const csv = history.exportHistoryCsv((r) => r.sceneId, 'h1,h2,h3,h4');
  const ms = performance.now() - t0;
  assert.ok(csv.split('\n').length >= 500);
  assert.ok(ms < 2000, `export too slow: ${ms}ms`);
});

test('p0 overtime / alert profile / ritual packs', async () => {
  mockStorage();
  const p0 = await import(publicJs('p0Features.js'));
  assert.equal(p0.getStandRitual(), p0.RITUAL_BASIC);
  p0.setStandRitual(p0.RITUAL_OFF);
  assert.equal(p0.getStandRitual(), p0.RITUAL_OFF);
  p0.setAlertProfile(p0.PROFILE_SILENT);
  const alerts = p0.resolveFinishAlerts({
    getFinishTone: () => true,
    getFinishVibrate: () => true,
    getFinishNotify: () => true,
  });
  assert.equal(alerts.withTone, false);
  assert.equal(alerts.withVibrate, false);
  assert.equal(alerts.withNotify, true);

  const kitchen = p0.resolveRitualPack('noodles', 'kitchen');
  assert.equal(kitchen.titleKey, 'standRitualTitleKitchen');
  assert.equal(kitchen.stepKeys.length, 3);

  const before = p0.readOvertimeStats();
  assert.equal(before.count, 0);
  p0.recordOvertime(90_000);
  p0.recordOvertime(30_000);
  const after = p0.readOvertimeStats();
  assert.equal(after.count, 2);
  assert.equal(after.ms, 120_000);
  assert.equal(p0.insightMinutes(after.ms), 2);
});
