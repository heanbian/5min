/**
 * Copyright 2026 学记宝 / xuejibao.com
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Light shell cache for Add to Home Screen / repeat visits.
 * Bump CACHE when shipping shell asset changes.
 */

const CACHE = '5min-shell-v12';

/* Timer shell + app module graph; CJK fonts / non-default locale packs load on demand */
const PRECACHE = [
  './',
  './index.html',
  './css/fonts.css',
  './css/app.css',
  './js/boot.js',
  './js/app.js',
  './js/alert.js',
  './js/ambient.js',
  './js/stats.js',
  './js/history.js',
  './js/prefs.js',
  './js/cloudSync.js',
  './js/share.js',
  './js/custom-scenes.js',
  './js/p0Features.js',
  './js/scene-ranker.js',
  './js/scene-profiles.js',
  './js/scene-profiles-data.js',
  './js/scenes-data.js',
  './js/i18n/locales.js',
  './js/i18n/packs/zh-CN.js',
  './fonts/PlusJakartaSans-Regular.woff2',
  './fonts/PlusJakartaSans-Medium.woff2',
  './fonts/PlusJakartaSans-SemiBold.woff2',
  './fonts/PlusJakartaSans-Bold.woff2',
  './img/logo.svg',
  './img/logo.png',
  './img/favicon-32.png',
  './img/apple-touch-icon.png',
  './img/beian.png',
  './favicon.ico',
  './site.webmanifest',
];

function isShellPath(pathname) {
  return (
    pathname === '/' ||
    pathname === '/index.html' ||
    pathname.startsWith('/css/') ||
    pathname.startsWith('/js/') ||
    pathname.startsWith('/fonts/') ||
    pathname.startsWith('/img/') ||
    pathname === '/favicon.ico' ||
    pathname === '/site.webmanifest'
  );
}

async function putInCache(request, response) {
  try {
    const cache = await caches.open(CACHE);
    await cache.put(request, response);
  } catch {
    /* quota / private mode */
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      await cache.addAll(PRECACHE);
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try {
    url = new URL(req.url);
  } catch {
    return;
  }
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    const isHome = url.pathname === '/' || url.pathname === '/index.html';
    event.respondWith(
      (async () => {
        try {
          const res = await fetch(req);
          if (res.ok && isHome) await putInCache('./index.html', res.clone());
          return res;
        } catch {
          if (!isHome) return Response.error();
          return (await caches.match('./index.html')) || (await caches.match('./')) || Response.error();
        }
      })()
    );
    return;
  }

  if (!isShellPath(url.pathname)) return;

  const isVersioned = url.searchParams.has('v');
  const isCssOrJs =
    url.pathname.startsWith('/css/') || url.pathname.startsWith('/js/');
  const networkFirst = isCssOrJs && !isVersioned;

  if (networkFirst) {
    event.respondWith(
      (async () => {
        try {
          const res = await fetch(req);
          if (res.ok) await putInCache(req, res.clone());
          return res;
        } catch {
          return (await caches.match(req)) || Response.error();
        }
      })()
    );
    return;
  }

  event.respondWith(
    (async () => {
      const cached = await caches.match(req);
      if (cached) return cached;
      const res = await fetch(req);
      if (res.ok) await putInCache(req, res.clone());
      return res;
    })()
  );
});
