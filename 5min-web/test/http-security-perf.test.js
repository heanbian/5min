'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const net = require('net');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { performance } = require('perf_hooks');

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
  const t0 = performance.now();
  return new Promise((resolve, reject) => {
    const payload = opts.body == null ? null : Buffer.from(String(opts.body), 'utf8');
    const headers = Object.assign({}, opts.headers || {});
    if (payload && !headers['Content-Type'] && !headers['content-type']) {
      headers['Content-Type'] = 'application/json';
    }
    if (payload) {
      headers['Content-Length'] = String(payload.length);
    }
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
            body: Buffer.concat(chunks),
            ms: performance.now() - t0
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
  const confPath = path.join(os.tmpdir(), 'fivemin-http-security-perf-' + port + '.conf');
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

function percentile(samples, q) {
  const sorted = samples.slice().sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(q * (sorted.length - 1)))];
}

test('HTTP 安全响应头、敏感路径与路径穿越', async () => {
  await withServer(async (port) => {
    const home = await request(port, '/');
    assert.equal(home.status, 200);
    const headers = home.headers;
    assert.match(headers['content-security-policy'] || '', /default-src 'self'/);
    assert.match(headers['content-security-policy'] || '', /script-src[^;]*'self'/);
    assert.match(headers['content-security-policy'] || '', /object-src 'none'/);
    assert.match(headers['content-security-policy'] || '', /frame-ancestors 'none'/);
    assert.match(headers['content-security-policy'] || '', /script-src-attr 'none'/);
    assert.equal(headers['x-frame-options'], 'DENY');
    assert.equal(headers['x-content-type-options'], 'nosniff');
    assert.ok(headers['referrer-policy']);
    assert.match(headers['permissions-policy'] || '', /camera=\(\)/);
    assert.match(headers['cache-control'] || '', /no-cache/i);
    assert.equal(headers['x-powered-by'], undefined);

    const css = await request(port, '/css/app.css?v=test');
    assert.equal(css.status, 200);
    assert.match(css.headers['cache-control'] || '', /max-age=31536000/);
    assert.match(css.headers['cache-control'] || '', /immutable/);

    const sw = await request(port, '/sw.js');
    assert.equal(sw.status, 200);
    assert.match(sw.headers['cache-control'] || '', /no-cache/i);
    assert.equal(sw.headers['service-worker-allowed'], '/');

    for (const p of [
      '/server.conf',
      '/.env',
      '/package.json',
      '/bizjs/db.js',
      '/routes/public.js',
      '/server.js'
    ]) {
      const res = await request(port, p);
      assert.equal(res.status, 404, p);
      assert.equal(/DB_PASSWORD|postgres|express/i.test(res.body.toString('utf8')), false, p);
    }

    for (const p of [
      '/../../../etc/passwd',
      '/js/../../server.conf',
      '/%2e%2e/%2e%2e/package.json',
      '/about.html/../server.conf'
    ]) {
      const res = await request(port, p);
      assert.ok(res.status >= 400, p + ' status=' + res.status);
      assert.equal(/root:|DB_PASSWORD|"express"/i.test(res.body.toString('utf8')), false, p);
    }

    const status = await request(port, '/api/status');
    assert.equal(status.status, 200);
    const payload = JSON.parse(status.body.toString('utf8'));
    assert.equal(payload.success, true);
    assert.equal(payload.data.name, '5min');
    const flat = JSON.stringify(payload);
    assert.equal(/DB_PASSWORD|client_secret|SESSION_SECRET|private_key/i.test(flat), false);

    const privacy = await request(port, '/privacy.html');
    assert.equal(privacy.status, 200);
    assert.match(privacy.headers['content-type'] || '', /text\/html/);

    const about = await request(port, '/about.html');
    assert.equal(about.status, 200);
    const aboutHtml = about.body.toString('utf8');
    assert.match(aboutHtml, /css\/about\.css\?v=[0-9a-f]+/i);
    assert.match(aboutHtml, /css\/fonts\.css\?v=[0-9a-f]+/i);

    const download = await request(port, '/download.html');
    assert.equal(download.status, 200);
    const downloadHtml = download.body.toString('utf8');
    assert.match(downloadHtml, /css\/download\.css\?v=[0-9a-f]+/i);
    assert.match(downloadHtml, /js\/download\.js\?v=[0-9a-f]+/i);
    assert.equal(/\?v=16\b/.test(downloadHtml), false);

    // Round 2: storage auth must never accept credentials in JSON body.
    const bodyAuth = await request(port, '/api/v1/storage/register', {
      method: 'POST',
      body: JSON.stringify({
        deviceId: '00000000-0000-4000-8000-000000000001',
        deviceSecret: 'a'.repeat(64)
      })
    });
    assert.equal(bodyAuth.status, 400, 'reject body credentials');
    const bodyAuthJson = JSON.parse(bodyAuth.body.toString('utf8'));
    assert.equal(bodyAuthJson.success, false);
    assert.match(String(bodyAuthJson.message || ''), /请求头/);

    const headerOnlyMissing = await request(port, '/api/v1/storage/snapshot', {
      method: 'GET',
      headers: { 'X-Device-Id': 'not-a-uuid', 'X-Device-Secret': 'short' }
    });
    assert.ok(headerOnlyMissing.status >= 400, 'invalid header credentials rejected');
  });
});

test('HTTP 页面与静态资源延迟在可接受范围', async () => {
  await withServer(async (port) => {
    async function bench(pathname, n) {
      const samples = [];
      let bytes = 0;
      for (let i = 0; i < n; i += 1) {
        const res = await request(port, pathname);
        assert.equal(res.status, 200, pathname);
        samples.push(res.ms);
        bytes = res.body.length;
      }
      return {
        p50: percentile(samples, 0.5),
        p95: percentile(samples, 0.95),
        max: Math.max(...samples),
        bytes
      };
    }

    const home = await bench('/', 25);
    assert.ok(home.p95 < 120, '首页 p95=' + home.p95);
    assert.ok(home.bytes < 100 * 1024, '首页 HTML 过大: ' + home.bytes);

    const js = await bench('/js/app.js', 20);
    assert.ok(js.p95 < 120, 'app.js p95=' + js.p95);
    assert.ok(js.bytes < 250 * 1024, 'app.js 过大: ' + js.bytes);

    const cloudSync = await bench('/js/cloudSync.js', 15);
    assert.ok(cloudSync.p95 < 120, 'cloudSync.js p95=' + cloudSync.p95);
    assert.ok(cloudSync.bytes < 40 * 1024, 'cloudSync.js 过大: ' + cloudSync.bytes);

    const api = await bench('/api/status', 40);
    assert.ok(api.p95 < 60, 'status p95=' + api.p95);
    assert.ok(api.bytes < 2 * 1024, 'status 响应体过大');

    const css = await bench('/css/app.css', 20);
    assert.ok(css.p95 < 120, 'css p95=' + css.p95);

    // Storage auth path should stay cheap even when rejecting bad input.
    const samples = [];
    for (let i = 0; i < 20; i += 1) {
      const res = await request(port, '/api/v1/storage/register', {
        method: 'POST',
        body: JSON.stringify({ deviceSecret: 'x'.repeat(64) })
      });
      assert.equal(res.status, 400);
      samples.push(res.ms);
    }
    const p95 = percentile(samples, 0.95);
    assert.ok(p95 < 80, 'storage reject p95=' + p95);
  });
});

test('并发静态请求保持可用', async () => {
  await withServer(async (port) => {
    const paths = ['/', '/js/app.js', '/css/app.css', '/api/status', '/about.html'];
    const jobs = [];
    for (let i = 0; i < 40; i += 1) {
      jobs.push(request(port, paths[i % paths.length]));
    }
    const results = await Promise.all(jobs);
    for (const res of results) {
      assert.equal(res.status, 200);
      assert.ok(res.ms < 500, '慢请求 ' + res.ms);
    }
  });
});
