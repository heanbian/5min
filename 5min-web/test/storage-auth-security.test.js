'use strict';

/**
 * Round-2 storage auth security: body credentials rejected; header-only register path.
 */
const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const net = require('net');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const root = path.join(__dirname, '..');

function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      server.close((err) => (err ? reject(err) : resolve(port)));
    });
    server.on('error', reject);
  });
}

function request(port, pathname, opts = {}) {
  return new Promise((resolve, reject) => {
    const payload = opts.body == null ? null : Buffer.from(String(opts.body), 'utf8');
    const headers = Object.assign({}, opts.headers || {});
    if (payload && !headers['Content-Type'] && !headers['content-type']) {
      headers['Content-Type'] = 'application/json';
    }
    if (payload) headers['Content-Length'] = String(payload.length);
    const req = http.request(
      {
        host: '127.0.0.1',
        port,
        path: pathname,
        method: opts.method || 'GET',
        headers
      },
      (res) => {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: Buffer.concat(chunks)
          });
        });
      }
    );
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
    if (payload) req.write(payload);
    req.end();
  });
}

function startServer(port, confPath) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, ['server.js'], {
      cwd: root,
      env: {
        ...process.env,
        DOTENV_CONFIG_PATH: confPath,
        PORT: String(port),
        NODE_ENV: 'test',
        TRUST_PROXY: '0',
        VISITOR_GEO_ENABLED: 'false'
      },
      stdio: ['ignore', 'pipe', 'pipe']
    });
    let output = '';
    const onData = (buf) => {
      output += buf.toString('utf8');
      if (new RegExp('server running on port ' + port).test(output)) {
        child.stdout.off('data', onData);
        child.stderr.off('data', onData);
        resolve(child);
      }
    };
    child.stdout.on('data', onData);
    child.stderr.on('data', onData);
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code != null && code !== 0) reject(new Error('server exited early:\n' + output));
    });
    setTimeout(() => reject(new Error('server start timeout:\n' + output)), 15000);
  });
}

async function withServer(run) {
  const port = await freePort();
  const confPath = path.join(os.tmpdir(), 'fivemin-storage-auth-' + port + '.conf');
  fs.writeFileSync(
    confPath,
    [
      'PORT=' + port,
      'NODE_ENV=test',
      'TRUST_PROXY=0',
      'VISITOR_GEO_ENABLED=false',
      'DB_HOST=127.0.0.1',
      'DB_PORT=1',
      'DB_USER=test',
      'DB_PASSWORD=test',
      'DB_NAME=fivemin_test'
    ].join('\n') + '\n'
  );
  const child = await startServer(port, confPath);
  try {
    await run(port);
  } finally {
    child.kill('SIGTERM');
    await new Promise((resolve) => {
      const timer = setTimeout(() => {
        child.kill('SIGKILL');
        resolve();
      }, 3000);
      child.on('exit', () => {
        clearTimeout(timer);
        resolve();
      });
    });
    try {
      fs.unlinkSync(confPath);
    } catch (_) {}
  }
}

test('storage 拒绝 JSON body 中的 deviceId/deviceSecret', async () => {
  await withServer(async (port) => {
    for (const body of [
      { deviceSecret: 'a'.repeat(64) },
      { deviceId: '00000000-0000-4000-8000-000000000099' },
      {
        deviceId: '00000000-0000-4000-8000-000000000099',
        deviceSecret: 'b'.repeat(64),
        prefs: { ambient: 'off' }
      }
    ]) {
      const res = await request(port, '/api/v1/storage/register', {
        method: 'POST',
        body: JSON.stringify(body)
      });
      assert.equal(res.status, 400, JSON.stringify(body));
      const json = JSON.parse(res.body.toString('utf8'));
      assert.equal(json.success, false);
      assert.match(String(json.message || ''), /请求头/);
    }

    const prefsBody = await request(port, '/api/v1/storage/prefs', {
      method: 'PUT',
      headers: {
        'X-Device-Id': '00000000-0000-4000-8000-000000000099',
        'X-Device-Secret': 'c'.repeat(64)
      },
      body: JSON.stringify({
        deviceSecret: 'leak',
        prefs: { ambient: 'off' }
      })
    });
    assert.equal(prefsBody.status, 400);

    // Without body credentials, invalid header auth still fails closed (no DB required).
    const snap = await request(port, '/api/v1/storage/snapshot', {
      method: 'GET',
      headers: {
        'X-Device-Id': 'not-valid',
        'X-Device-Secret': 'short'
      }
    });
    assert.ok(snap.status >= 400);
    assert.equal(snap.headers['cache-control'], 'no-store');

    // Header-only register with empty JSON body: invalid credentials → 400 (not body-auth path).
    const emptyBody = await request(port, '/api/v1/storage/register', {
      method: 'POST',
      headers: {
        'X-Device-Id': 'not-a-uuid',
        'X-Device-Secret': 'short'
      },
      body: JSON.stringify({})
    });
    assert.equal(emptyBody.status, 400);
    const emptyJson = JSON.parse(emptyBody.body.toString('utf8'));
    assert.equal(emptyJson.success, false);
    assert.match(String(emptyJson.message || ''), /deviceId|deviceSecret|无效/);

    // Valid-shaped headers + empty body should not trip body-auth rejection.
    const shaped = await request(port, '/api/v1/storage/register', {
      method: 'POST',
      headers: {
        'X-Device-Id': '00000000-0000-4000-8000-000000000099',
        'X-Device-Secret': 'd'.repeat(64)
      },
      body: JSON.stringify({})
    });
    assert.notEqual(shaped.status, 400, 'empty body must not look like body credentials');
    // DB may be unavailable in this harness → 500; auth shape must still be accepted.
    assert.ok([200, 500].includes(shaped.status), 'status=' + shaped.status);
    if (shaped.status === 200) {
      const ok = JSON.parse(shaped.body.toString('utf8'));
      assert.equal(ok.success, true);
    }
  });
});

test('storage 写接口限流在突发下返回 429', async () => {
  await withServer(async (port) => {
    const headers = {
      'X-Device-Id': '00000000-0000-4000-8000-000000000077',
      'X-Device-Secret': 'e'.repeat(64),
      'Content-Type': 'application/json'
    };
    let saw429 = false;
    // REGISTER_LIMIT is 10/min; fire well above that.
    for (let i = 0; i < 24; i += 1) {
      const res = await request(port, '/api/v1/storage/register', {
        method: 'POST',
        headers,
        body: JSON.stringify({})
      });
      if (res.status === 429) {
        saw429 = true;
        const json = JSON.parse(res.body.toString('utf8'));
        assert.equal(json.success, false);
        break;
      }
    }
    assert.equal(saw429, true, 'expected register rate limit 429');
  });
});
