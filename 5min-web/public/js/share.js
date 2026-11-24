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

/**
 * Share habit summary — Web Share API with clipboard fallback;
 * optional canvas PNG when navigator.share supports files.
 */

/**
 * @param {{ title: string, text: string, brand?: string }} opts
 * @returns {Promise<'shared'|'copied'|'failed'>}
 */
export const shareSummary = async ({ title, text, brand = '5min.chat' }) => {
  const safeTitle = String(title || '').slice(0, 120);
  const safeText = String(text || '').slice(0, 2000);

  if (typeof navigator !== 'undefined' && typeof navigator.share === 'function') {
    try {
      const file = await buildShareImage({ title: safeTitle, text: safeText, brand });
      if (file && navigator.canShare?.({ files: [file] })) {
        await navigator.share({ title: safeTitle, text: safeText, files: [file] });
        return 'shared';
      }
      await navigator.share({ title: safeTitle, text: safeText });
      return 'shared';
    } catch (err) {
      if (err && /** @type {{name?:string}} */ (err).name === 'AbortError') return 'failed';
      /* fall through to clipboard */
    }
  }

  try {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(safeText);
      return 'copied';
    }
  } catch {
    /* ignore */
  }

  try {
    const ta = document.createElement('textarea');
    ta.value = safeText;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(ta);
    return ok ? 'copied' : 'failed';
  } catch {
    return 'failed';
  }
};

/**
 * @param {{ title: string, text: string, brand: string }} opts
 * @returns {Promise<File|null>}
 */
const buildShareImage = async ({ title, text, brand }) => {
  try {
    const canvas = document.createElement('canvas');
    canvas.width = 720;
    canvas.height = 420;
    const ctx = canvas.getContext('2d');
    if (!ctx) return null;

    const grad = ctx.createLinearGradient(0, 0, 720, 420);
    grad.addColorStop(0, '#eef6f1');
    grad.addColorStop(1, '#dff0e6');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 720, 420);

    ctx.fillStyle = '#1f2a24';
    ctx.font = '600 36px "Plus Jakarta Sans", system-ui, sans-serif';
    ctx.fillText(String(title).slice(0, 36), 48, 80);

    ctx.fillStyle = '#5f6f66';
    ctx.font = '500 22px "Plus Jakarta Sans", system-ui, sans-serif';
    const lines = String(text).split('\n').slice(0, 6);
    let y = 140;
    for (const line of lines) {
      ctx.fillText(line.slice(0, 48), 48, y);
      y += 36;
    }

    ctx.fillStyle = '#2f9a68';
    ctx.font = '600 20px "Plus Jakarta Sans", system-ui, sans-serif';
    ctx.fillText(String(brand).slice(0, 40), 48, 380);

    const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
    if (!blob) return null;
    return new File([blob], '5min-share.png', { type: 'image/png' });
  } catch {
    return null;
  }
};
