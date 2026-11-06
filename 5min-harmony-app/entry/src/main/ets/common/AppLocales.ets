/** App-supported UI languages (Harmony client). */
export const APP_LOCALES: string[] = ['zh-CN', 'zh-TW', 'en'];

export function isAppLocale(code: string): boolean {
  return APP_LOCALES.indexOf(code) >= 0;
}

export function normalizeAppLocale(code: string, fallback: string = 'zh-CN'): string {
  if (isAppLocale(code)) {
    return code;
  }
  if (!code) {
    return fallback;
  }
  const lower = code.trim().replace('_', '-');
  if (isAppLocale(lower)) {
    return lower;
  }
  const parts = lower.split('-');
  const base = parts[0].toLowerCase();
  const region = parts.length > 1 ? parts[1].toUpperCase() : '';
  if (base === 'zh') {
    if (region === 'TW' || region === 'HK' || region === 'MO' || lower.indexOf('hant') >= 0) {
      return 'zh-TW';
    }
    return 'zh-CN';
  }
  if (base === 'en') {
    return 'en';
  }
  return fallback;
}

export function filterAppLocales(codes: string[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < APP_LOCALES.length; i++) {
    const code = APP_LOCALES[i];
    if (codes.indexOf(code) >= 0) {
      out.push(code);
    }
  }
  return out.length > 0 ? out : APP_LOCALES.slice();
}
