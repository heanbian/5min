'use strict';

/** 页面访问记录。不提供管理页面。静态资源与接口不记录。 */

const fs = require('fs');
const path = require('path');

const GEO_CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const GEO_CACHE_MAX = 2000;
const DEDUPE_MS = 60 * 1000;
const GEO_TIMEOUT_MS = 900;
/** 单 IP 每分钟最多写入条数（跨路径合计），抑制刷库。 */
const WRITE_RATE_LIMIT = 30;
const WRITE_RATE_WINDOW_MS = 60 * 1000;

/** @type {Map<string, { at: number, data: object }>} */
const geoCache = new Map();
/** @type {Map<string, number>} */
const recentHits = new Map();
/** @type {Map<string, { start: number, count: number }>} */
const writeRate = new Map();

function allowWrite(ip) {
  const key = String(ip || '') || 'unknown';
  const now = Date.now();
  const row = writeRate.get(key);
  if (!row || now - row.start >= WRITE_RATE_WINDOW_MS) {
    writeRate.set(key, { start: now, count: 1 });
    if (writeRate.size > 5000) {
      for (const [k, v] of writeRate) {
        if (now - v.start >= WRITE_RATE_WINDOW_MS) writeRate.delete(k);
      }
    }
    return true;
  }
  if (row.count >= WRITE_RATE_LIMIT) return false;
  row.count += 1;
  return true;
}

function geoCacheSet(ip, entry) {
  geoCache.set(ip, entry);
  if (geoCache.size <= GEO_CACHE_MAX) return;
  const now = Date.now();
  for (const [key, value] of geoCache) {
    if (now - value.at >= GEO_CACHE_TTL_MS) geoCache.delete(key);
  }
  if (geoCache.size <= GEO_CACHE_MAX) return;
  const overflow = geoCache.size - GEO_CACHE_MAX + 100;
  let removed = 0;
  for (const key of geoCache.keys()) {
    geoCache.delete(key);
    if (++removed >= overflow) break;
  }
}

const SKIP_EXT =
  /\.(js|css|map|png|jpe?g|gif|webp|svg|ico|woff2?|ttf|eot|mp3|mp4|webm|json|txt|xml|webmanifest)$/i;
const SECRET_QUERY = new Set([
  'code',
  'state',
  'token',
  'access_token',
  'id_token',
  'refresh_token',
  'verifier'
]);

function siteJsonPath() {
  const { resolvePublicPath } = require('./paths');
  return path.join(resolvePublicPath(), 'site' + '.json');
}

const sitePages = JSON.parse(fs.readFileSync(siteJsonPath(), 'utf8')).pages.map((page) => page.path);
const RECORD_PATHS = new Set(
  sitePages.concat(['/privacy.html', '/terms.html', '/about.html', '/faq.html', '/'])
);

function clamp(value, max) {
  return String(value == null ? '' : value).trim().slice(0, max);
}

function isPrivateIp(ip) {
  const s = String(ip || '').replace(/^::ffff:/i, '');
  if (!s || s === '::1' || s === '0:0:0:0:0:0:0:1') return true;
  if (s.startsWith('fe80:') || s.startsWith('fc') || s.startsWith('fd')) return true;
  if (/^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(s)) return true;
  if (s.startsWith('10.') || s.startsWith('192.168.') || s.startsWith('169.254.')) return true;
  const m172 = /^172\.(\d+)\./.exec(s);
  if (m172) {
    const n = Number(m172[1]);
    if (n >= 16 && n <= 31) return true;
  }
  // CGNAT 100.64.0.0/10
  const m100 = /^100\.(\d+)\./.exec(s);
  if (m100) {
    const n = Number(m100[1]);
    if (n >= 64 && n <= 127) return true;
  }
  return false;
}

/** 仅允许字面量 IP，拒绝主机名，降低 geo 查询 SSRF 风险。 */
function isLiteralIp(ip) {
  const s = String(ip || '').replace(/^::ffff:/i, '');
  if (/^(\d{1,3}\.){3}\d{1,3}$/.test(s)) {
    return s.split('.').every((part) => {
      const n = Number(part);
      return Number.isInteger(n) && n >= 0 && n <= 255 && String(n) === part;
    });
  }
  if (s.includes(':') && /^[0-9a-fA-F:]+$/.test(s) && s.length <= 45) return true;
  return false;
}

function trustProxyEnabled(req) {
  try {
    return !!(req && req.app && req.app.get('trust proxy'));
  } catch {
    return false;
  }
}

function clientIp(req) {
  if (trustProxyEnabled(req)) {
    return String((req && req.ip) || '')
      .replace(/^::ffff:/i, '')
      .slice(0, 64);
  }
  const socket =
    (req && req.socket && req.socket.remoteAddress) ||
    (req && req.connection && req.connection.remoteAddress) ||
    '';
  return String(socket).replace(/^::ffff:/i, '').slice(0, 64);
}

function geoEnabled() {
  const flag = String(process.env.VISITOR_GEO_ENABLED || 'true').toLowerCase();
  return !(flag === '0' || flag === 'false' || flag === 'off');
}

function composeLocation(parts) {
  return [parts.country, parts.region, parts.city].filter(Boolean).join(' ').trim().slice(0, 256);
}

function headerGeo(req) {
  const country = clamp(
    req.get('cf-ipcountry') || req.get('x-country-code') || req.get('cloudfront-viewer-country'),
    64
  );
  if (!country || country === 'XX' || country === 'T1') {
    return { country: '', region: '', city: '', isp: '', location: '' };
  }
  return {
    country,
    region: '',
    city: '',
    isp: '',
    location: composeLocation({ country, region: '', city: '' })
  };
}

async function lookupGeo(ip, req) {
  if (isPrivateIp(ip)) {
    return { country: '', region: '', city: '', isp: '', location: '内网/本地' };
  }

  const fromHeader = trustProxyEnabled(req)
    ? headerGeo(req)
    : { country: '', region: '', city: '', isp: '', location: '' };

  if (!isLiteralIp(ip)) {
    return fromHeader;
  }

  const cached = geoCache.get(ip);
  if (cached && Date.now() - cached.at < GEO_CACHE_TTL_MS) return cached.data;

  if (!geoEnabled()) return fromHeader;

  try {
    // 免费档仅提供 HTTP；禁止跟随重定向，并校验最终主机，降低 SSRF。
    const url =
      'http://ip-api.com/json/' +
      encodeURIComponent(ip) +
      '?lang=zh-CN&fields=status,country,regionName,city,isp,query';
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), GEO_TIMEOUT_MS);
    const response = await fetch(url, {
      signal: controller.signal,
      redirect: 'error',
      headers: { Accept: 'application/json' }
    });
    clearTimeout(timer);
    if (!response.ok) throw new Error('geo http ' + response.status);
    const finalHost = (() => {
      try {
        return new URL(response.url || url).hostname;
      } catch {
        return '';
      }
    })();
    if (finalHost && finalHost !== 'ip-api.com') {
      throw new Error('geo host mismatch');
    }
    const body = await response.json();
    if (body.status !== 'success') throw new Error('geo status');
    const data = {
      country: clamp(body.country, 64),
      region: clamp(body.regionName, 128),
      city: clamp(body.city, 128),
      isp: clamp(body.isp, 128),
      location: composeLocation({
        country: body.country,
        region: body.regionName,
        city: body.city
      })
    };
    geoCacheSet(ip, { at: Date.now(), data });
    return data;
  } catch {
    if (fromHeader.location || fromHeader.country) {
      geoCacheSet(ip, { at: Date.now(), data: fromHeader });
      return fromHeader;
    }
    const empty = { country: '', region: '', city: '', isp: '', location: '' };
    geoCacheSet(ip, { at: Date.now() - GEO_CACHE_TTL_MS + 5 * 60 * 1000, data: empty });
    return empty;
  }
}

function requestPath(req) {
  return String(req.path || req.url || '').split('?')[0] || '/';
}

function shouldRecord(req) {
  if (req.method !== 'GET' && req.method !== 'HEAD') return false;
  const raw = requestPath(req);
  if (raw.startsWith('/api/')) return false;
  if (SKIP_EXT.test(raw)) return false;
  return RECORD_PATHS.has(raw);
}

function sanitizeQuery(raw) {
  const text = String(raw || '');
  if (!text) return '';
  const params = new URLSearchParams(text);
  for (const key of [...params.keys()]) {
    if (SECRET_QUERY.has(String(key).toLowerCase())) params.delete(key);
  }
  return clamp(params.toString(), 512);
}

function sanitizeReferer(raw) {
  const text = clamp(raw, 512);
  if (!text) return '';
  try {
    const u = new URL(text);
    const q = sanitizeQuery(u.search ? u.search.slice(1) : '');
    u.search = q ? '?' + q : '';
    u.hash = '';
    u.username = '';
    u.password = '';
    return clamp(u.toString(), 512);
  } catch {
    const qAt = text.indexOf('?');
    if (qAt < 0) return text;
    const base = text.slice(0, qAt);
    const q = sanitizeQuery(text.slice(qAt + 1));
    return clamp(q ? base + '?' + q : base, 512);
  }
}

function pool() {
  return require('./db');
}

async function ensureVisitorLogTable() {
  const db = pool();
  await db.query(`
    CREATE TABLE IF NOT EXISTS fivemin_visitor_log (
      id            SERIAL PRIMARY KEY,
      ip            VARCHAR(64) NOT NULL DEFAULT '',
      path          VARCHAR(512) NOT NULL DEFAULT '',
      query         VARCHAR(512) NOT NULL DEFAULT '',
      referer       VARCHAR(512) NOT NULL DEFAULT '',
      user_agent    VARCHAR(512) NOT NULL DEFAULT '',
      country       VARCHAR(64) NOT NULL DEFAULT '',
      region        VARCHAR(128) NOT NULL DEFAULT '',
      city          VARCHAR(128) NOT NULL DEFAULT '',
      isp           VARCHAR(128) NOT NULL DEFAULT '',
      location      VARCHAR(256) NOT NULL DEFAULT '',
      created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      deleted       BOOLEAN NOT NULL DEFAULT FALSE
    )
  `);
  await db.query(`
    CREATE INDEX IF NOT EXISTS idx_fivemin_visitor_log_created_at
      ON fivemin_visitor_log (created_at DESC)
  `);
  await db.query(`
    CREATE INDEX IF NOT EXISTS idx_fivemin_visitor_log_ip
      ON fivemin_visitor_log (ip)
  `);
}

async function recordVisitor(req) {
  if (!shouldRecord(req)) return;

  const ip = clientIp(req) || '';
  if (!allowWrite(ip)) return;
  const hitPath = clamp(req.path || '/', 512) || '/';
  const dedupeKey = ip + '|' + hitPath;
  const now = Date.now();
  const last = recentHits.get(dedupeKey) || 0;
  if (now - last < DEDUPE_MS) return;
  recentHits.set(dedupeKey, now);
  if (recentHits.size > 5000) {
    for (const [key, at] of recentHits) {
      if (now - at > DEDUPE_MS) recentHits.delete(key);
    }
  }
  if (recentHits.size > 5000) {
    const extra = recentHits.size - 4000;
    let removed = 0;
    for (const key of recentHits.keys()) {
      recentHits.delete(key);
      if (++removed >= extra) break;
    }
  }

  const geo = await lookupGeo(ip, req);
  const query = sanitizeQuery(
    req.url && req.url.includes('?') ? req.url.slice(req.url.indexOf('?') + 1) : ''
  );

  await pool().query(
    `INSERT INTO fivemin_visitor_log
      (ip, path, query, referer, user_agent, country, region, city, isp, location)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [
      clamp(ip, 64),
      hitPath,
      query,
      sanitizeReferer(req.get('referer') || req.get('referrer') || ''),
      clamp(req.get('user-agent') || '', 512),
      geo.country || '',
      geo.region || '',
      geo.city || '',
      geo.isp || '',
      geo.location || ''
    ]
  );
}

function visitorLogMiddleware(req, res, next) {
  next();
  setImmediate(() => {
    recordVisitor(req).catch((err) => {
      console.error('写入访客记录失败: ' + (err && err.message ? err.message : err));
    });
  });
}

module.exports = {
  ensureVisitorLogTable,
  visitorLogMiddleware,
  shouldRecord,
  isPrivateIp,
  isLiteralIp,
  sanitizeQuery,
  sanitizeReferer
};
