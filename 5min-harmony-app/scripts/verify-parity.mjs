/**
 * Lightweight parity checks mirroring 5min-mp security helpers
 * (parseRecoveryCode / weak credentials / CSV escape) for Harmony ports.
 */
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function parseRecoveryCode(raw) {
  const text = String(raw || '').trim().replace(/\s+/g, '');
  const idx = text.indexOf(':');
  if (idx <= 0) return null;
  const deviceId = text.slice(0, idx);
  const deviceSecret = text.slice(idx + 1);
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
      deviceId,
    )
  ) {
    return null;
  }
  if (!/^[0-9a-f]{32,128}$/i.test(deviceSecret)) return null;
  if (/^0{8}-0{4}-4000-8000-0{12}$/i.test(deviceId)) return null;
  if (/^0+$/i.test(deviceSecret)) return null;
  return { deviceId, deviceSecret };
}

function isWeakDeviceCredentials(deviceId, deviceSecret) {
  if (!deviceId || !deviceSecret) return true;
  if (/^0+$/i.test(deviceSecret)) return true;
  if (/^0{8}-0{4}-4000-8000-0{12}$/i.test(deviceId)) return true;
  return false;
}

function escapeCsvCell(value) {
  let s = String(value == null ? '' : value);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

const goodId = '550e8400-e29b-41d4-a716-446655440000';
const goodSecret = 'a'.repeat(64);

assert.ok(parseRecoveryCode(`${goodId}:${goodSecret}`));
assert.ok(parseRecoveryCode(`  ${goodId} : ${goodSecret}  `));
assert.equal(parseRecoveryCode(''), null);
assert.equal(parseRecoveryCode('nocolon'), null);
assert.equal(parseRecoveryCode(`${goodId}:short`), null);
assert.equal(
  parseRecoveryCode(`00000000-0000-0000-0000-000000000000:${goodSecret}`),
  null,
);
assert.equal(parseRecoveryCode(`${goodId}:${'0'.repeat(64)}`), null);
assert.equal(parseRecoveryCode(`${goodId}:${'g'.repeat(64)}`), null);

assert.ok(isWeakDeviceCredentials('', 'x'));
assert.ok(isWeakDeviceCredentials(goodId, '0'.repeat(64)));
assert.ok(
  isWeakDeviceCredentials('00000000-0000-4000-8000-000000000000', goodSecret),
);
assert.ok(!isWeakDeviceCredentials(goodId, goodSecret));

assert.equal(escapeCsvCell('=cmd'), "'=cmd");
assert.equal(escapeCsvCell('hello,world'), '"hello,world"');
assert.equal(escapeCsvCell('plain'), 'plain');

const prefs = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/common/PrefsStore.ets'),
  'utf8',
);
const cloud = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/common/CloudSync.ets'),
  'utf8',
);
const records = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/ui/RecordsTab.ets'),
  'utf8',
);
const mine = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/ui/MineTab.ets'),
  'utf8',
);
const index = fs.readFileSync(
  path.join(root, 'entry/src/main/ets/pages/Index.ets'),
  'utf8',
);
assert.ok(prefs.includes('[1-5][0-9a-f]{3}'));
assert.ok(cloud.includes('isWeakDeviceCredentials'));
assert.ok(records.includes("[=+\\-@\\t\\r]"));
assert.ok(mine.includes('prefOvertimeInsight'));
assert.ok(mine.includes('customSceneDeleteConfirm'));
assert.ok(index.includes('this.running || this.inOvertime'));
assert.ok(index.includes('privacyDisagree'));
assert.ok(mine.includes('https://5min.chat/privacy.html'));
assert.ok(mine.includes('https://5min.chat/terms.html'));
assert.ok(mine.includes('https://5min.chat/about.html'));
assert.ok(index.includes('https://5min.chat/privacy.html'));
assert.ok(index.includes('https://5min.chat/terms.html'));
assert.ok(!fs.existsSync(path.join(root, 'entry/src/main/ets/pages/Legal.ets')));

console.log('verify-parity: ok');
