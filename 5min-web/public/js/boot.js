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
 */

/* ES module 无法在 file:// 下跨文件 import；仅作协议提示 */
if (location.protocol === 'file:') {
  console.warn('[5min] ES modules require http(s). Run: npx --yes serve .');
}

/* Light PWA: register shell service worker (https / localhost only) */
(function registerShellWorker() {
  if (!('serviceWorker' in navigator)) return;
  const host = location.hostname;
  const ok =
    location.protocol === 'https:' ||
    host === 'localhost' ||
    host === '127.0.0.1' ||
    host === '[::1]';
  if (!ok) return;
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  });
})();
