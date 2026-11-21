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

const CACHE = '5min-shell-v9';

/* Minimal shell: CJK fonts + non-default locale packs load on demand */
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

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)))
      )
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try {
    url = new URL(req.url);
  } catch (e) {
    return;
  }
  if (url.origin !== self.location.origin) return;

  if (req.mode === 'navigate') {
    const isHome = url.pathname === '/' || url.pathname === '/index.html';
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok && isHome) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put('./index.html', copy)).catch(() => {});
          }
          return res;
        })
        .catch(() => {
          // Only the timer shell is precached — do not serve it for about/privacy/etc.
          if (!isHome) return Response.error();
          return caches.match('./index.html').then((cached) => cached || caches.match('./'));
        })
    );
    return;
  }

  if (!isShellPath(url.pathname)) return;

  /* Versioned CSS/JS: cache-first by URL. Unversioned: network-first for freshness. */
  const isVersioned = url.searchParams.has('v');
  const isCssOrJs =
    url.pathname.startsWith('/css/') || url.pathname.startsWith('/js/');
  const networkFirst = isCssOrJs && !isVersioned;

  if (networkFirst) {
    event.respondWith(
      fetch(req)
        .then((res) => {
          if (res.ok) {
            const copy = res.clone();
            caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
          }
          return res;
        })
        .catch(() => caches.match(req).then((cached) => cached || Response.error()))
    );
    return;
  }

  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        if (!res.ok) return res;
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
        return res;
      });
    })
  );
});
