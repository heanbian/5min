'use strict';

(function bootstrapDaemon() {
  const wantDaemon =
    process.argv.includes('-d') || process.argv.includes('--daemon');
  if (!wantDaemon) return;

  const fs = require('fs');
  const path = require('path');
  const { spawn } = require('child_process');
  const { resolveAppRoot } = require('./bizjs/paths');

  const root = resolveAppRoot();
  const pidFile = path.join(root, 'fivemin.pid');
  const logDir = path.join(root, 'logs');
  fs.mkdirSync(logDir, { recursive: true });
  const outLog = path.join(logDir, 'fivemin.out.log');
  const outFd = fs.openSync(outLog, 'a');

  if (fs.existsSync(pidFile)) {
    const old = String(fs.readFileSync(pidFile, 'utf8') || '').trim();
    if (old && killable(old)) {
      console.error(`如厕计时器(5min) 已在运行 pid=${old}，请先执行 ./stop.sh`);
      process.exit(1);
    }
    try {
      fs.unlinkSync(pidFile);
    } catch (_) {}
  }

  const childArgs = process.argv
    .slice(1)
    .filter((a) => a !== '-d' && a !== '--daemon');
  const child = spawn(process.execPath, childArgs, {
    detached: true,
    stdio: ['ignore', outFd, outFd],
    cwd: root,
    env: process.env
  });
  fs.writeFileSync(pidFile, String(child.pid), 'utf8');
  child.unref();
  console.log(`如厕计时器(5min) 已后台启动 pid=${child.pid}`);
  console.log(`pid 文件: ${pidFile}`);
  console.log(`日志: ${outLog}`);
  process.exit(0);

  function killable(pid) {
    try {
      process.kill(Number(pid), 0);
    } catch (_) {
      return false;
    }
  }
})();

const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const express = require('express');
const helmet = require('helmet');
const dotenv = require('dotenv');
const { resolveAppRoot, resolvePublicPath, assertPublicReady } = require('./bizjs/paths');
const { visitorLogMiddleware, ensureVisitorLogTable } = require('./bizjs/visitor-log');
const { ensureCloudStorageTables } = require('./bizjs/cloud-storage');
const registerPublicRoutes = require('./routes/public');
const registerStorageRoutes = require('./routes/storage');

const APP_ROOT = resolveAppRoot();
const PID_FILE = path.join(APP_ROOT, 'fivemin.pid');

function findConfigPath() {
  if (process.env.DOTENV_CONFIG_PATH) return process.env.DOTENV_CONFIG_PATH;
  const cwdPath = path.join(process.cwd(), 'server.conf');
  if (fs.existsSync(cwdPath)) return cwdPath;
  const rootPath = path.join(APP_ROOT, 'server.conf');
  if (fs.existsSync(rootPath)) return rootPath;
  return cwdPath;
}

dotenv.config({
  path: findConfigPath(),
  override: true
});

const PORT = Number(process.env.PORT) || 3300;
const isProd = String(process.env.NODE_ENV || '').toLowerCase() === 'production';
const publicPath = resolvePublicPath();
assertPublicReady(publicPath);
const site = JSON.parse(fs.readFileSync(path.join(publicPath, 'site' + '.json'), 'utf8'));
const pages = new Map((site.pages || []).map((page) => [page.path, page]));

function feedAssetTree(hash, dir) {
  if (!fs.existsSync(dir)) return;
  fs.readdirSync(dir, { withFileTypes: true }).forEach((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      feedAssetTree(hash, full);
      return;
    }
    const st = fs.statSync(full);
    hash.update(entry.name);
    hash.update(String(st.size));
    hash.update(String(Math.floor(st.mtimeMs)));
  });
}

function computeAssetVersion() {
  if (process.env.ASSET_VERSION) return String(process.env.ASSET_VERSION);
  const pkgCandidates = [
    path.join(APP_ROOT, 'package.json'),
    path.join(__dirname, 'package.json')
  ];
  const pkgPath = pkgCandidates.find((item) => fs.existsSync(item));
  const pkgVersion = pkgPath
    ? String(JSON.parse(fs.readFileSync(pkgPath, 'utf8')).version || '0')
    : '0';
  const hash = crypto.createHash('sha1');
  hash.update(pkgVersion);
  feedAssetTree(hash, path.join(publicPath, 'js'));
  feedAssetTree(hash, path.join(publicPath, 'css'));
  return hash.digest('hex').slice(0, 12);
}

const ASSET_VERSION = computeAssetVersion();

function clearPidFile() {
  try {
    if (!fs.existsSync(PID_FILE)) return;
    const pid = String(fs.readFileSync(PID_FILE, 'utf8') || '').trim();
    if (pid && Number(pid) === process.pid) fs.unlinkSync(PID_FILE);
  } catch (_) {}
}

function sendHtmlFile(res, fileName) {
  const raw = String(fileName || '').replace(/\\/g, '/');
  if (!raw || raw.includes('\0') || path.isAbsolute(raw) || raw.split('/').includes('..')) {
    res.status(404);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.send('页面不存在');
  }
  const rootResolved = path.resolve(publicPath);
  const filePath = path.resolve(rootResolved, raw);
  const prefix = rootResolved.endsWith(path.sep) ? rootResolved : rootResolved + path.sep;
  if (filePath !== rootResolved && !filePath.startsWith(prefix)) {
    res.status(404);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.send('页面不存在');
  }
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    res.status(404);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.send('页面不存在');
  }
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache');
  return res.sendFile(filePath);
}

const app = express();
app.disable('x-powered-by');

if (process.env.TRUST_PROXY === '1' || process.env.TRUST_PROXY === 'true') {
  app.set('trust proxy', 1);
}

const sessionSecure = isProd && process.env.TRUST_PROXY !== '0';

app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'blob:'],
        fontSrc: ["'self'", 'data:'],
        connectSrc: ["'self'", 'blob:'],
        mediaSrc: ["'self'", 'blob:'],
        workerSrc: ["'self'", 'blob:'],
        objectSrc: ["'none'"],
        baseUri: ["'self'"],
        formAction: ["'self'"],
        frameAncestors: ["'none'"],
        scriptSrcAttr: ["'none'"]
      }
    },
    referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
    crossOriginEmbedderPolicy: false,
    crossOriginOpenerPolicy: sessionSecure ? { policy: 'same-origin' } : false,
    originAgentCluster: sessionSecure,
    xFrameOptions: { action: 'deny' },
    hsts: isProd && sessionSecure ? undefined : false
  })
);

app.use((req, res, next) => {
  res.setHeader(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()'
  );
  next();
});

app.use(visitorLogMiddleware);
registerPublicRoutes(app);
registerStorageRoutes(app);

function staticHeaders(res, filePath) {
  const ext = path.extname(filePath).toLowerCase();
  const base = path.basename(filePath);
  if (ext === '.html') res.setHeader('Content-Type', 'text/html; charset=utf-8');
  else if (ext === '.js' || ext === '.mjs') res.setHeader('Content-Type', 'text/javascript; charset=utf-8');
  else if (ext === '.css') res.setHeader('Content-Type', 'text/css; charset=utf-8');
  else if (ext === '.svg') res.setHeader('Content-Type', 'image/svg+xml; charset=utf-8');
  else if (ext === '.json') res.setHeader('Content-Type', 'application/json; charset=utf-8');
  else if (ext === '.txt') res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  else if (ext === '.xml') res.setHeader('Content-Type', 'application/xml; charset=utf-8');
  else if (ext === '.webmanifest') res.setHeader('Content-Type', 'application/manifest+json; charset=utf-8');

  if (base === 'sw.js') {
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Service-Worker-Allowed', '/');
    return;
  }

  const versioned = Boolean(res.req && res.req.query && res.req.query.v);
  const fingerprinted = versioned && /\.(js|mjs|css)$/i.test(filePath);
  if (ext === '.html' || ext === '.json' || ext === '.webmanifest') {
    res.setHeader('Cache-Control', 'no-cache');
  } else if (fingerprinted) {
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
  } else if (/\.(js|mjs|css)$/i.test(filePath)) {
    res.setHeader('Cache-Control', 'public, max-age=86400, must-revalidate');
  } else if (/\.(png|jpe?g|gif|webp|ico|svg|woff2?)$/i.test(filePath)) {
    res.setHeader('Cache-Control', 'public, max-age=604800');
  } else {
    res.setHeader('Cache-Control', 'public, max-age=3600');
  }
}

app.use(
  express.static(publicPath, {
    etag: true,
    lastModified: true,
    index: false,
    setHeaders: staticHeaders
  })
);

app.get('/', (req, res) => sendHtmlFile(res, 'index.html'));

for (const pagePath of pages.keys()) {
  if (pagePath === '/') continue;
  app.get(pagePath, (req, res) => {
    const page = pages.get(req.path);
    const fileName = page && page.path ? String(page.path).replace(/^\//, '') : '';
    if (!fileName || fileName.includes('..')) {
      res.status(404);
      return res.send('页面不存在');
    }
    return sendHtmlFile(res, fileName);
  });
}

app.use((req, res) => {
  res.status(404);
  const accept = String(req.get('accept') || '');
  if (accept.includes('application/json') && !accept.includes('text/html')) {
    return res.json({ success: false, message: '页面不存在' });
  }
  const notFound = path.join(publicPath, '404.html');
  if (fs.existsSync(notFound)) {
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.sendFile(notFound);
  }
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  return res.send('页面不存在');
});

app.use((err, req, res, next) => {
  if (res.headersSent) return next(err);
  console.error(err && err.stack ? err.stack : err);
  const status = Number(err && err.status) >= 400 ? Number(err.status) : 500;
  res.status(status);
  res.setHeader('Content-Type', 'text/plain; charset=utf-8');
  return res.send('服务异常');
});

const server = app.listen(PORT, () => {
  console.log(
    `如厕计时器(5min) server running on port ${PORT} (NODE_ENV=${process.env.NODE_ENV || 'development'}, ASSET_V=${ASSET_VERSION})`
  );
  ensureVisitorLogTable()
    .then(() => console.log('访客记录表已就绪'))
    .catch((err) => {
      console.error('访客记录表初始化失败: ' + (err && err.message ? err.message : err));
    });
  ensureCloudStorageTables()
    .then(() => console.log('云存储表已就绪'))
    .catch((err) => {
      console.error('云存储表初始化失败: ' + (err && err.message ? err.message : err));
    });
});

function shutdown(signal) {
  console.log(`收到 ${signal}，正在退出…`);
  clearPidFile();
  server.close(() => {
    try {
      const pool = require('./bizjs/db');
      pool.end().finally(() => process.exit(0));
    } catch {
      process.exit(0);
    }
  });
  setTimeout(() => process.exit(0), 3000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('exit', clearPidFile);
