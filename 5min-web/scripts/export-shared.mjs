#!/usr/bin/env node
/**
 * Export scenes + locales for Android / Harmony / iOS / WeChat mini program.
 */
import { writeFileSync, mkdirSync, cpSync, existsSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import { LOCALES, LOCALE_CODES } from '../js/i18n/locales.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const exportDir = join(root, 'shared-export');
const scenesPath = join(exportDir, 'scenes.json');
if (!existsSync(scenesPath)) {
  console.error('missing shared-export/scenes.json');
  process.exit(1);
}
const scenesRoot = JSON.parse(readFileSync(scenesPath, 'utf8'));
scenesRoot.localeCodes = LOCALE_CODES;
mkdirSync(join(exportDir, 'locales'), { recursive: true });
writeFileSync(scenesPath, JSON.stringify(scenesRoot, null, 2));
for (const code of LOCALE_CODES) {
  writeFileSync(join(exportDir, 'locales', `${code}.json`), JSON.stringify(LOCALES[code], null, 2));
}
writeFileSync(join(exportDir, 'locales', 'index.json'), JSON.stringify({ codes: LOCALE_CODES, defaultLocale: 'zh-CN' }, null, 2));

const targets = [
  join(root, '..', '5min-android-app', 'app', 'src', 'main', 'assets', 'shared'),
  join(root, '..', '5min-harmony-app', 'entry', 'src', 'main', 'resources', 'rawfile', 'shared'),
  join(root, '..', '5min-ios-app', 'FiveMin', 'Resources', 'shared'),
];
for (const t of targets) {
  if (!existsSync(dirname(t))) {
    console.warn('skip', t);
    continue;
  }
  mkdirSync(join(t, 'locales'), { recursive: true });
  cpSync(scenesPath, join(t, 'scenes.json'));
  for (const code of LOCALE_CODES) {
    cpSync(join(exportDir, 'locales', `${code}.json`), join(t, 'locales', `${code}.json`));
  }
  cpSync(join(exportDir, 'locales', 'index.json'), join(t, 'locales', 'index.json'));
  console.log('synced', t);
}

const mpShared = join(root, '..', '5min-mp', 'shared');
if (existsSync(dirname(mpShared))) {
  mkdirSync(join(mpShared, 'locales'), { recursive: true });
  cpSync(scenesPath, join(mpShared, 'scenes.json'));
  for (const code of LOCALE_CODES) {
    cpSync(join(exportDir, 'locales', `${code}.json`), join(mpShared, 'locales', `${code}.json`));
  }
  writeFileSync(
    join(mpShared, 'scenes.js'),
    `module.exports = ${readFileSync(join(mpShared, 'scenes.json'), 'utf8').trim()};\n`,
  );
  const mpLocaleMap = [
    ['zh-CN.json', 'zh_CN.js'],
    ['zh-TW.json', 'zh_TW.js'],
    ['en.json', 'en.js'],
  ];
  for (const [src, dest] of mpLocaleMap) {
    writeFileSync(
      join(mpShared, 'locales', dest),
      `module.exports = ${readFileSync(join(mpShared, 'locales', src), 'utf8').trim()};\n`,
    );
  }
  console.log('synced', mpShared);
}
