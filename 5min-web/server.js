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
      console.error(`如厕计时器 已在运行 pid=${old}，请先执行 ./stop.sh`);
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
  console.log(`如厕计时器 已后台启动 pid=${child.pid}`);
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

if (isProd) {
  const pepper = String(process.env.STORAGE_PEPPER || '').trim();
  if (!pepper || pepper === '5min-dev-pepper-change-me' || pepper.length < 16) {
    console.error(
      '生产环境必须设置 STORAGE_PEPPER（≥16 字符的随机盐，勿使用示例值）'
    );
    process.exit(1);
  }
}

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
  feedAssetTree(hash, path.join(publicPath, 'fonts'));
  feedAssetTree(hash, path.join(publicPath, 'img'));
  const favicon = path.join(publicPath, 'favicon.ico');
  if (fs.existsSync(favicon)) {
    const st = fs.statSync(favicon);
    hash.update('favicon.ico');
    hash.update(String(st.size));
    hash.update(String(Math.floor(st.mtimeMs)));
  }
  return hash.digest('hex').slice(0, 12);
}

const ASSET_VERSION = computeAssetVersion();

/** 本站静态资源路径（相对 / 绝对 / 5min.chat）是否需要追加 ?v= */
function isVersionableAssetUrl(url) {
  const u = String(url || '').trim();
  if (!u || u.startsWith('data:') || u.startsWith('blob:') || u.startsWith('#')) return false;
  if (/^[a-z][a-z0-9+.-]*:/i.test(u) && !/^https?:\/\/5min\.chat\//i.test(u)) return false;
  const pathOnly = u.replace(/^https?:\/\/5min\.chat/i, '').split('?')[0].split('#')[0];
  const base = pathOnly.split('/').pop() || '';
  if (
    base === 'favicon.ico' ||
    base === 'site.webmanifest' ||
    base === 'sw.js' ||
    pathOnly === '/favicon.ico' ||
    pathOnly === '/site.webmanifest' ||
    pathOnly === '/sw.js'
  ) {
    return true;
  }
  // ES module / CSS 相对引用：./alert.js、../fonts/x.woff2
  if (/^\.\.?\/.+\.(?:js|mjs|css|png|svg|jpe?g|webp|woff2?|ico)$/i.test(pathOnly)) return true;
  return /(?:^|\/)(?:css|js|fonts|img)\//.test(pathOnly);
}

function appendAssetVersion(url) {
  const u = String(url || '');
  if (!isVersionableAssetUrl(u) || /[?&]v=/.test(u)) return u;
  const hashIdx = u.indexOf('#');
  const base = hashIdx >= 0 ? u.slice(0, hashIdx) : u;
  const hash = hashIdx >= 0 ? u.slice(hashIdx) : '';
  const sep = base.includes('?') ? '&' : '?';
  return `${base}${sep}v=${ASSET_VERSION}${hash}`;
}

function rewriteHtmlAssets(html) {
  let out = String(html);
  out = out.replace(/\b(href|src)=(["'])([^"']+)\2/gi, (full, attr, quote, url) => {
    if (!isVersionableAssetUrl(url)) return full;
    return `${attr}=${quote}${appendAssetVersion(url)}${quote}`;
  });
  out = out.replace(/\bcontent=(["'])(https:\/\/5min\.chat\/(?:img|css|js|fonts)\/[^"']+)\1/gi, (full, quote, url) => {
    return `content=${quote}${appendAssetVersion(url)}${quote}`;
  });
  return out;
}

function rewriteCssUrls(css) {
  return String(css).replace(/url\(\s*(['"]?)([^'")]+)\1\s*\)/gi, (full, quote, url) => {
    const trimmed = String(url || '').trim();
    if (!isVersionableAssetUrl(trimmed)) return full;
    const q = quote || '';
    return `url(${q}${appendAssetVersion(trimmed)}${q})`;
  });
}

function rewriteJsModules(js) {
  let out = String(js);
  out = out.replace(/\b(from|import)\s*(['"])(\.\/[^'"]+\.js)\2/g, (full, kw, quote, url) => {
    return `${kw} ${quote}${appendAssetVersion(url)}${quote}`;
  });
  out = out.replace(
    /\bimport\s*\(\s*(['"])(\.\/[^'"]+\.js)\1\s*\)/g,
    (full, quote, url) => `import(${quote}${appendAssetVersion(url)}${quote})`
  );
  out = out.replace(
    /navigator\.serviceWorker\.register\(\s*(['"])(\.\/sw\.js)\1\s*\)/g,
    (full, quote, url) => `navigator.serviceWorker.register(${quote}${appendAssetVersion(url)}${quote})`
  );
  out = out.replace(
    /(['"])((?:\.\.?\/)*(?:css|js|fonts|img)\/[^'"]+\.(?:js|css|png|svg|jpe?g|webp|woff2?|ico))\1/gi,
    (full, quote, url) => `${quote}${appendAssetVersion(url)}${quote}`
  );
  return out;
}

/** Rewritten text bodies keyed by absolute path (invalidated when ASSET_VERSION changes). */
const rewrittenCache = new Map();

function cachedRewrite(filePath, rewriter) {
  const hit = rewrittenCache.get(filePath);
  if (hit && hit.version === ASSET_VERSION) return hit.body;
  const body = rewriter(fs.readFileSync(filePath, 'utf8'));
  rewrittenCache.set(filePath, { version: ASSET_VERSION, body });
  return body;
}

function rewriteServiceWorker(js) {
  let out = String(js);
  out = out.replace(
    /const CACHE = ['"]([^'"]+)['"]/,
    (full, name) => `const CACHE = '${name}-${ASSET_VERSION}'`
  );
  out = out.replace(
    /(['"])(\.\/(?:css|js|fonts|img)\/[^'"]+|\.\/favicon\.ico|\.\/site\.webmanifest)\1/g,
    (full, quote, url) => `${quote}${appendAssetVersion(url)}${quote}`
  );
  return out;
}

function rewriteManifest(jsonText) {
  let out = String(jsonText);
  out = out.replace(/("src"\s*:\s*")([^"]+)(")/g, (full, a, url, b) => {
    if (!isVersionableAssetUrl(url)) return full;
    return `${a}${appendAssetVersion(url)}${b}`;
  });
  return out;
}

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
  const html = cachedRewrite(filePath, rewriteHtmlAssets);
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache');
  return res.send(html);
}

function resolvePublicFile(relUrlPath) {
  const raw = String(relUrlPath || '').replace(/\\/g, '/').replace(/^\//, '');
  if (!raw || raw.includes('\0') || raw.split('/').includes('..')) return null;
  const rootResolved = path.resolve(publicPath);
  const filePath = path.resolve(rootResolved, raw);
  const prefix = rootResolved.endsWith(path.sep) ? rootResolved : rootResolved + path.sep;
  if (filePath !== rootResolved && !filePath.startsWith(prefix)) return null;
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) return null;
  return filePath;
}

function sendRewrittenText(res, filePath, contentType, body) {
  res.setHeader('Content-Type', contentType);
  staticHeaders(res, filePath);
  return res.send(body);
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
  const fingerprinted =
    versioned && /\.(js|mjs|css|png|jpe?g|gif|webp|ico|svg|woff2?)$/i.test(filePath);
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

/** CSS / JS / SW / manifest：注入资产版本号后再输出 */
app.get('/sw.js', (req, res) => {
  const filePath = resolvePublicFile('sw.js');
  if (!filePath) return res.status(404).send('Not found');
  const body = cachedRewrite(filePath, rewriteServiceWorker);
  return sendRewrittenText(res, filePath, 'text/javascript; charset=utf-8', body);
});

app.get('/site.webmanifest', (req, res) => {
  const filePath = resolvePublicFile('site.webmanifest');
  if (!filePath) return res.status(404).send('Not found');
  const body = cachedRewrite(filePath, rewriteManifest);
  return sendRewrittenText(res, filePath, 'application/manifest+json; charset=utf-8', body);
});

app.get(/^\/css\/.+\.css$/i, (req, res, next) => {
  const filePath = resolvePublicFile(req.path);
  if (!filePath) return next();
  const body = cachedRewrite(filePath, rewriteCssUrls);
  return sendRewrittenText(res, filePath, 'text/css; charset=utf-8', body);
});

app.get(/^\/js\/.+\.js$/i, (req, res, next) => {
  const filePath = resolvePublicFile(req.path);
  if (!filePath) return next();
  const body = cachedRewrite(filePath, rewriteJsModules);
  return sendRewrittenText(res, filePath, 'text/javascript; charset=utf-8', body);
});

// HarmonyOS App Linking 直达回落：浏览器打开 /5min-harmony-app 时跳转应用市场详情
const HARMONY_AG_URL = 'https://appgallery.huawei.com/app/detail?id=chat.5min.app';
app.get(['/5min-harmony-app', '/5min-harmony-app/'], (req, res) => {
  res.redirect(302, HARMONY_AG_URL);
});

// HarmonyOS App Linking：send / express.static 默认忽略 dotfiles，须显式放行
app.get('/.well-known/applinking.json', (req, res) => {
  const filePath = path.join(publicPath, '.well-known', 'applinking.json');
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    res.status(404);
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    return res.send('Not found');
  }
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('Cache-Control', 'no-cache');
  return res.send(fs.readFileSync(filePath));
});

/* HTML must go through sendHtmlFile (asset ?v=) — register before express.static */
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

app.get(/^\/[^/]+\.html$/i, (req, res, next) => {
  const fileName = String(req.path || '').replace(/^\//, '');
  if (!fileName || fileName.includes('..')) return next();
  if (!resolvePublicFile(fileName)) return next();
  return sendHtmlFile(res, fileName);
});

app.use(
  express.static(publicPath, {
    etag: true,
    lastModified: true,
    index: false,
    dotfiles: 'allow',
    setHeaders: staticHeaders
  })
);

app.use((req, res) => {
  res.status(404);
  const accept = String(req.get('accept') || '');
  if (accept.includes('application/json') && !accept.includes('text/html')) {
    return res.json({ success: false, message: '页面不存在' });
  }
  if (fs.existsSync(path.join(publicPath, '404.html'))) {
    return sendHtmlFile(res, '404.html');
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
    `如厕计时器 server running on port ${PORT} (NODE_ENV=${process.env.NODE_ENV || 'development'}, ASSET_V=${ASSET_VERSION})`
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
