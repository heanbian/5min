import { SharedCatalog } from './SharedCatalog';
import { normalizeAppLocale } from './AppLocales';

export function resolveLocale(catalog: SharedCatalog, tag: string, systemTags: string[]): string {
  const direct = matchTag(catalog, tag);
  if (direct) {
    return normalizeAppLocale(direct, catalog.defaultLocale);
  }
  for (let i = 0; i < systemTags.length; i++) {
    const hit = matchTag(catalog, systemTags[i]);
    if (hit) {
      return normalizeAppLocale(hit, catalog.defaultLocale);
    }
  }
  return normalizeAppLocale(catalog.defaultLocale, 'zh-CN');
}

function matchTag(catalog: SharedCatalog, tag: string): string | null {
  if (!tag) {
    return null;
  }
  const lower = tag.trim().replace('_', '-');
  if (catalog.localeCodes.indexOf(lower) >= 0) {
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
  if (catalog.localeCodes.indexOf(base) >= 0) {
    return base;
  }
  return null;
}
