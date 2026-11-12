/**
 * Local verification for 5min-mp (Node, no WeChat runtime).
 * Run: node scripts/verify.mjs
 */

import { createRequire } from 'module';
import assert from 'assert';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const require = createRequire(import.meta.url);

global.wx = {
  getStorageSync() {
    return '';
  },
  setStorageSync() {},
  showToast() {},
  navigateTo() {},
  setClipboardData() {},
  getAppBaseInfo() {
    return { language: 'zh_CN' };
  },
};

const { isAllowedHttps } = require('../utils/openUrl.js');
const { getLegalDoc } = require('../utils/legalDocs.js');
const { sceneById, PRESET_MINS, DEFAULT_MIN } = require('../utils/catalog.js');
const { t, initLocale, setLocale } = require('../utils/i18n.js');

const zhCN = require('../shared/locales/zh_CN.js');
const zhTW = require('../shared/locales/zh_TW.js');
const en = require('../shared/locales/en.js');

let failed = 0;
function check(name, fn) {
  try {
    fn();
    console.log('ok ', name);
  } catch (e) {
    failed += 1;
    console.error('FAIL', name, e.message);
  }
}

check('locale key parity', () => {
  const keys = Object.keys(zhCN).sort();
  assert.deepStrictEqual(Object.keys(zhTW).sort(), keys);
  assert.deepStrictEqual(Object.keys(en).sort(), keys);
});

check('json/js locale sync', () => {
  for (const [jsName, jsonName] of [
    ['zh_CN.js', 'zh-CN.json'],
    ['zh_TW.js', 'zh-TW.json'],
    ['en.js', 'en.json'],
  ]) {
    const js = require(`../shared/locales/${jsName}`);
    const json = JSON.parse(
      fs.readFileSync(path.join(root, 'shared/locales', jsonName), 'utf8')
    );
    assert.deepStrictEqual(js, json, jsName);
  }
});

check('required copy keys', () => {
  const need = [
    'brandTitle',
    'beianIcp',
    'sceneToilet',
    'invalidLink',
    'linkCopied',
    'feedbackBody',
    'feedbackEmail',
    'copyEmailLabel',
    'emailCopied',
    'privacyMessage',
    'tabHome',
    'tabMine',
  ];
  for (const k of need) {
    assert.equal(typeof zhCN[k], 'string', k);
    assert.ok(zhCN[k].length > 0, k);
  }
  assert.equal(zhCN.beianIcp, '蜀ICP备14028739号-5X');
  assert.equal(zhCN.sceneToilet, '如厕 · 5 分钟');
});

check('default toilet scene', () => {
  const toilet = sceneById('toilet');
  assert.ok(toilet);
  assert.equal(toilet.min, 5);
  assert.equal(DEFAULT_MIN, 5);
  assert.deepStrictEqual(PRESET_MINS, [3, 5, 10]);
});

check('https allowlist', () => {
  assert.equal(isAllowedHttps('https://5min.chat/privacy.html'), true);
  assert.equal(isAllowedHttps('https://www.5min.chat/about.html'), true);
  assert.equal(isAllowedHttps('http://5min.chat/privacy.html'), false);
  assert.equal(isAllowedHttps('https://evil.com/?u=https://5min.chat'), false);
  assert.equal(isAllowedHttps('https://5min.chat.evil.com/'), false);
  assert.equal(isAllowedHttps('javascript:alert(1)'), false);
  assert.equal(isAllowedHttps(''), false);
});

check('in-app legal docs', () => {
  for (const id of ['privacy', 'terms']) {
    const doc = getLegalDoc(id);
    assert.ok(doc, id);
    assert.ok(doc.title.length > 0, `${id}.title`);
    assert.ok(Array.isArray(doc.blocks) && doc.blocks.length > 5, `${id}.blocks`);
  }
  assert.equal(getLegalDoc('nope'), null);
  const app = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  assert.ok(app.pages.includes('pages/legal/legal'));
});

check('i18n interpolation', () => {
  initLocale();
  setLocale('zh-CN');
  assert.equal(t('minutes', { n: 5 }), '5 分钟');
  assert.ok(t('feedbackEmail').includes('@'));
  setLocale('en');
  assert.equal(t('tabHome'), 'Home');
});

check('dead beian page removed', () => {
  assert.equal(fs.existsSync(path.join(root, 'pages/beian')), false);
  const app = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  assert.ok(!app.pages.some((p) => p.includes('beian')));
  assert.equal(app.tabBar.list[1].text, '首页');
});

check('project name', () => {
  const cfg = JSON.parse(
    fs.readFileSync(path.join(root, 'project.config.json'), 'utf8')
  );
  assert.equal(cfg.projectname, '如厕计时器');
});

if (failed) {
  console.error(`\n${failed} check(s) failed`);
  process.exit(1);
}
console.log('\nAll checks passed.');
