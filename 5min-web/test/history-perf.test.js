/**
 * Lightweight history module correctness + performance smoke tests.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const { pathToFileURL } = require('node:url');

const historyUrl = pathToFileURL(
  path.join(__dirname, '../public/js/history.js'),
).href;

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

test('history record/list/streak stay fast for 500 sessions', async () => {
  mockStorage();
  const history = await import(historyUrl);
  const t0 = Date.now();
  for (let i = 0; i < 500; i += 1) {
    history.recordSession(60_000 + (i % 7) * 1000, i % 2 === 0 ? 'toilet' : 'brush');
  }
  const list = history.getHistory();
  const streak = history.getStreak();
  const period = history.periodStats();
  const elapsed = Date.now() - t0;
  assert.ok(list.length > 0);
  assert.equal(typeof streak, 'number');
  assert.equal(period.count, list.length);
  assert.ok(elapsed < 1500, `history ops too slow: ${elapsed}ms`);
});
