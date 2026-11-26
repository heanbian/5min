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

const store = new Map();
const navigations = [];
global.wx = {
  getStorageSync(key) {
    if (!store.has(key)) return '';
    return store.get(key);
  },
  setStorageSync(key, value) {
    store.set(key, value);
  },
  removeStorageSync(key) {
    store.delete(key);
  },
  showToast() {},
  navigateTo(opts) {
    navigations.push(opts && opts.url);
  },
  switchTab(opts) {
    navigations.push(`switchTab:${opts && opts.url}`);
  },
  reLaunch(opts) {
    navigations.push(`reLaunch:${opts && opts.url}`);
  },
  setClipboardData() {},
  showTabBar() {},
  hideTabBar() {},
  getAppBaseInfo() {
    return { language: 'zh_CN' };
  },
  getRandomValues(opts) {
    // WeChat API: { length, success({ randomValues }) }
    if (opts && typeof opts.length === 'number') {
      const buf = new Uint8Array(opts.length);
      for (let i = 0; i < opts.length; i += 1) buf[i] = (i * 17 + 3) & 0xff;
      if (typeof opts.success === 'function') {
        opts.success({ randomValues: buf.buffer });
      }
      return;
    }
    // Legacy TypedArray misuse must not silently succeed with zeros.
    if (opts && opts.length != null && typeof opts.success !== 'function') {
      for (let i = 0; i < opts.length; i += 1) opts[i] = (i * 17 + 3) & 0xff;
      return opts;
    }
  },
  request() {},
};
global.getApp = () => ({ globalData: { privacyAccepted: false } });

const { isAllowedHttps } = require('../utils/openUrl.js');
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
    'docNotFound',
    'widgetTodayCount',
    'widgetTapOpen',
    'customSceneMinLabel',
    'customSceneDeleteConfirm',
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
  assert.equal(isAllowedHttps('https://5min.chat/download.html'), true);
  assert.equal(isAllowedHttps('https://5min.chat/unknown.html'), false);
  assert.equal(isAllowedHttps('https://5min.chat/privacy.html?x=1'), true);
  assert.equal(isAllowedHttps('http://5min.chat/privacy.html'), false);
  assert.equal(isAllowedHttps('https://evil.com/?u=https://5min.chat'), false);
  assert.equal(isAllowedHttps('https://5min.chat.evil.com/'), false);
  assert.equal(isAllowedHttps('javascript:alert(1)'), false);
  assert.equal(isAllowedHttps(''), false);
});

check('in-app legal docs', () => {
  const { getLegalDoc } = require('../utils/legalDocs.js');
  for (const id of ['privacy', 'terms', 'about']) {
    const doc = getLegalDoc(id);
    assert.ok(doc, id);
    assert.ok(doc.title.length > 0, `${id}.title`);
    assert.ok(Array.isArray(doc.blocks) && doc.blocks.length > 3, `${id}.blocks`);
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
  assert.equal(app.tabBar.list[1].text, '主页');
});

check('project name', () => {
  const cfg = JSON.parse(
    fs.readFileSync(path.join(root, 'project.config.json'), 'utf8')
  );
  assert.equal(cfg.projectname, '如厕计时器');
});

check('base library pinned to latest stable 3.18.0', () => {
  // 3.18.0 ≈76% users (2026-11-24); 3.18.1 still gray (~0.16%) — keep stable.
  const cfg = JSON.parse(
    fs.readFileSync(path.join(root, 'project.config.json'), 'utf8'),
  );
  assert.equal(cfg.libVersion, '3.18.0');
  const priv = JSON.parse(
    fs.readFileSync(path.join(root, 'project.private.config.json'), 'utf8'),
  );
  assert.equal(priv.libVersion, '3.18.0');
  assert.equal(cfg.setting.swc, true);
  assert.equal(cfg.setting.disableSWC, false);
  assert.ok(
    !fs.existsSync(path.join(root, 'package.json')),
    'no npm UI kit to upgrade; native components only',
  );
});

check('standRitualLabel differs from section', () => {
  assert.notEqual(zhCN.standRitualSection, zhCN.standRitualLabel);
  assert.ok(zhCN.prefOvertimeInsight.length > 0);
});

check('no @font-face local urls in app.wxss', () => {
  const css = fs.readFileSync(path.join(root, 'app.wxss'), 'utf8');
  assert.ok(!/@font-face\s*\{[^}]*url\s*\(\s*["']?\/fonts\//.test(css));
  assert.ok(!css.includes('.privacy-card::before'), 'no decorative privacy green bar');
  const appJs = fs.readFileSync(path.join(root, 'app.js'), 'utf8');
  assert.ok(
    !/loadFontFace\s*\(\s*\{[\s\S]*\/fonts\//.test(appJs),
    'do not loadFontFace package-local /fonts (breaks DevTools hit layer)',
  );
});

check('no unsupported glassEaselWebview keys (DevTools rejects them)', () => {
  const app = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  assert.equal(app.lazyCodeLoading, 'requiredComponents');
  assert.ok(!('glassEaselWebview' in app));
  assert.ok(!('componentFramework' in app));
  for (const rel of [
    'pages/boot/boot.json',
    'pages/index/index.json',
    'pages/records/records.json',
    'pages/mine/mine.json',
    'pages/legal/legal.json',
    'pages/webview/webview.json',
  ]) {
    const page = JSON.parse(fs.readFileSync(path.join(root, rel), 'utf8'));
    assert.ok(!('glassEaselWebview' in page), rel);
    assert.ok(!('componentFramework' in page), rel);
  }
  const priv = JSON.parse(
    fs.readFileSync(path.join(root, 'project.private.config.json'), 'utf8'),
  );
  assert.equal(priv.setting.useGlassEaselForWxml, false);
});

check('no deprecated text selectable attribute', () => {
  const files = [];
  function walk(dir) {
    for (const name of fs.readdirSync(dir)) {
      const p = path.join(dir, name);
      const st = fs.statSync(p);
      if (st.isDirectory()) {
        if (name === 'node_modules' || name === 'scripts') continue;
        walk(p);
      } else if (name.endsWith('.wxml')) {
        files.push(p);
      }
    }
  }
  walk(root);
  for (const file of files) {
    const wxml = fs.readFileSync(file, 'utf8');
    assert.ok(
      !/\sselectable(\s|=|>)/.test(wxml),
      `${path.relative(root, file)}: use user-select instead of deprecated selectable`,
    );
  }
});

check('privacy service accept + boot routing', () => {
  store.clear();
  navigations.length = 0;
  global.getApp = () => ({ globalData: { privacyAccepted: false } });
  const privacy = require('../services/privacy.js');
  assert.equal(privacy.isAccepted(), false);
  assert.equal(privacy.bootOrEnter(), false);
  assert.ok(!navigations.some((u) => String(u).includes('switchTab')));

  privacy.accept();
  assert.equal(privacy.isAccepted(), true);
  navigations.length = 0;
  assert.equal(privacy.bootOrEnter(), true);
  assert.ok(navigations.some((u) => String(u).includes('switchTab:/pages/index/index')));

  store.clear();
  navigations.length = 0;
  global.getApp = () => ({ globalData: { privacyAccepted: false } });
  assert.equal(privacy.ensureAcceptedOrBoot(), false);
  assert.ok(navigations.some((u) => String(u).includes('reLaunch:/pages/boot/boot')));
});

check('mine sheets use root-portal and global sheet styles', () => {
  const wxml = fs.readFileSync(path.join(root, 'pages/mine/mine.wxml'), 'utf8');
  assert.ok(wxml.includes('<root-portal'), 'root-portal required for sheets');
  assert.ok(!/<scroll-view[^>]*\benhanced\b/.test(wxml), 'no enhanced scroll-view');
  assert.ok(wxml.includes('catchtap="onOpenLang"'), 'openers should use catchtap');
  const portalIdx = wxml.indexOf('<root-portal');
  const sheetIdx = wxml.indexOf('class="sheet-mask"');
  assert.ok(sheetIdx > portalIdx, 'sheet-mask inside root-portal');
  // root-portal ignores page wxss — sheet chrome must be in app.wxss
  const appCss = fs.readFileSync(path.join(root, 'app.wxss'), 'utf8');
  assert.ok(appCss.includes('.sheet-mask'), 'sheet-mask styles in app.wxss');
  assert.ok(appCss.includes('.sheet-item'), 'sheet-item styles in app.wxss');
  assert.ok(appCss.includes('background: #ffffff'), 'sheet solid background');
  const mineCss = fs.readFileSync(path.join(root, 'pages/mine/mine.wxss'), 'utf8');
  assert.ok(!mineCss.includes('.sheet-mask'), 'do not keep sheet-mask only in page wxss');
});

check('privacy consent is non-tabBar boot page (industry pattern)', () => {
  const appJson = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  assert.equal(appJson.pages[0], 'pages/boot/boot', 'boot must be entry');
  assert.ok(
    !appJson.tabBar.list.some((i) => i.pagePath === 'pages/boot/boot'),
    'boot must not be a tabBar page',
  );
  assert.ok(fs.existsSync(path.join(root, 'pages/boot/boot.js')));
  assert.ok(fs.existsSync(path.join(root, 'services/privacy.js')));
  assert.ok(fs.existsSync(path.join(root, 'behaviors/privacyGuard.js')));

  const bootWxml = fs.readFileSync(path.join(root, 'pages/boot/boot.wxml'), 'utf8');
  assert.ok(bootWxml.includes('bindtap="onToggleAgree"'), 'view checkbox toggle');
  assert.ok(bootWxml.includes('bindtap="onAccept"'));
  assert.ok(!bootWxml.includes('<button'), 'no native button on consent');
  assert.ok(!bootWxml.includes('<checkbox'), 'no native checkbox on consent');
  assert.ok(!bootWxml.includes('cover-view'));
  assert.ok(!bootWxml.includes('<consent-card'), 'consent is inline on Page');
  const bootJs = fs.readFileSync(path.join(root, 'pages/boot/boot.js'), 'utf8');
  assert.ok(bootJs.includes('onToggleAgree'));

  for (const rel of [
    'pages/index/index.wxml',
    'pages/records/records.wxml',
    'pages/mine/mine.wxml',
  ]) {
    const wxml = fs.readFileSync(path.join(root, rel), 'utf8');
    assert.ok(!wxml.includes('privacy-gate'), `${rel} must not overlay privacy`);
    assert.ok(!wxml.includes('privacy-mask'), `${rel} must not overlay privacy`);
    const pageJs = fs.readFileSync(path.join(root, rel.replace('.wxml', '.js')), 'utf8');
    assert.ok(
      pageJs.includes('behaviors/privacyGuard') || pageJs.includes("behaviors/privacyGuard"),
      `${rel} missing privacyGuard behavior`,
    );
  }
  const indexWxml = fs.readFileSync(path.join(root, 'pages/index/index.wxml'), 'utf8');
  assert.ok(indexWxml.includes('<canvas'));
  assert.ok(indexWxml.includes('<picker'));
});

check('parseRecoveryCode rejects malformed secrets', () => {
  store.clear();
  const prefs = require('../utils/prefs.js');
  const goodId = '550e8400-e29b-41d4-a716-446655440000';
  const goodSecret = 'a'.repeat(64);
  assert.ok(prefs.parseRecoveryCode(`${goodId}:${goodSecret}`));
  assert.ok(
    prefs.parseRecoveryCode(`  ${goodId} : ${goodSecret}  `),
    'strips whitespace',
  );
  assert.equal(prefs.parseRecoveryCode(''), null);
  assert.equal(prefs.parseRecoveryCode('nocolon'), null);
  assert.equal(prefs.parseRecoveryCode(`${goodId}:short`), null);
  assert.equal(
    prefs.parseRecoveryCode(`00000000-0000-0000-0000-000000000000:${goodSecret}`),
    null,
    'rejects nil UUID version',
  );
  assert.equal(
    prefs.parseRecoveryCode(
      `00000000-0000-4000-8000-000000000000:${'0'.repeat(64)}`,
    ),
    null,
    'rejects broken CSPRNG all-zero code',
  );
  assert.equal(
    prefs.parseRecoveryCode(`${goodId}:${'g'.repeat(64)}`),
    null,
    'rejects non-hex secret',
  );
});

check('ensureDeviceCredentials regenerates all-zero data codes', async () => {
  store.clear();
  global.getApp = () => ({ globalData: { privacyAccepted: true } });
  const prefs = require('../utils/prefs.js');
  const cloudSync = require('../utils/cloudSync.js');
  prefs.setDeviceCredentials(
    '00000000-0000-4000-8000-000000000000',
    '0'.repeat(64),
  );
  assert.ok(
    cloudSync.isWeakDeviceCredentials(
      prefs.getDeviceId(),
      prefs.getDeviceSecret(),
    ),
  );
  const creds = await cloudSync.ensureDeviceCredentials();
  assert.ok(creds.deviceId);
  assert.ok(creds.deviceSecret);
  assert.ok(!cloudSync.isWeakDeviceCredentials(creds.deviceId, creds.deviceSecret));
  assert.notEqual(creds.deviceId, '00000000-0000-4000-8000-000000000000');
  assert.ok(!/^0+$/.test(creds.deviceSecret));
  const code = prefs.formatRecoveryCode();
  assert.ok(code.includes(':'));
  assert.ok(!code.startsWith('00000000-0000-4000-8000'));
});

check('CSV escapes formula injection', () => {
  store.clear();
  const history = require('../utils/history.js');
  const cell = history.escapeCsvCell;
  assert.equal(cell('=1+1'), "'=1+1");
  assert.equal(cell('+cmd'), "'+cmd");
  assert.equal(cell('-2'), "'-2");
  assert.equal(cell('@SUM'), "'@SUM");
  assert.equal(cell('ok,quote"x'), '"ok,quote""x"');
  history.recordSession(120000, '=evil');
  const csv = history.exportHistoryCsv((row) => row.sceneId, 'Time,Scene,Planned,Actual');
  assert.ok(csv.includes("'=evil"), csv);
});

check('history getHistory skips rewrite when unchanged', () => {
  store.clear();
  const history = require('../utils/history.js');
  history.replaceAll([
    { id: 'a', at: Date.now(), minutes: 5, sceneId: 'toilet', elapsedMs: 300000 },
  ]);
  let writes = 0;
  const orig = wx.setStorageSync;
  wx.setStorageSync = (key, value) => {
    writes += 1;
    orig.call(wx, key, value);
  };
  history.getHistory();
  history.getHistory();
  wx.setStorageSync = orig;
  assert.equal(writes, 0, 'no rewrite when prune is noop');
});

check('cloudSync register body excludes credentials', () => {
  const src = fs.readFileSync(path.join(root, 'utils/cloudSync.js'), 'utf8');
  assert.ok(src.includes("request('POST', '/register', {})"));
  assert.ok(src.includes("'X-Device-Id'"));
  assert.ok(src.includes("'X-Device-Secret'"));
  assert.ok(!/register[\s\S]{0,120}deviceSecret\s*:/.test(src));
  assert.ok(src.includes('ensureDeviceCredentials'));
});

check('p0 ritual / alert / overtime packs', () => {
  store.clear();
  const p0 = require('../utils/p0Features.js');
  p0.setStandRitual(p0.RITUAL_OFF);
  assert.equal(p0.getStandRitual(), p0.RITUAL_OFF);
  p0.setStandRitual(p0.RITUAL_BASIC);
  assert.equal(p0.getStandRitual(), p0.RITUAL_BASIC);
  p0.setAlertProfile(p0.PROFILE_QUIET);
  assert.equal(p0.getAlertProfile(), p0.PROFILE_QUIET);
  p0.setShowOvertimeInsight(false);
  assert.equal(p0.getShowOvertimeInsight(), false);
  p0.setShowOvertimeInsight(true);
  assert.equal(p0.getShowOvertimeInsight(), true);
  const stats = p0.recordOvertime(90000);
  assert.ok(stats.count >= 1);
  assert.equal(p0.insightMinutes(90000), 2);
});

check('history export of 500 rows stays fast', () => {
  store.clear();
  const history = require('../utils/history.js');
  const now = Date.now();
  const rows = [];
  for (let i = 0; i < 500; i += 1) {
    rows.push({
      id: `row_${i}`,
      at: now - i * 1000,
      minutes: 5,
      sceneId: i % 2 === 0 ? 'toilet' : '=cmd',
      elapsedMs: 300000,
    });
  }
  history.replaceAll(rows);
  const t0 = Date.now();
  const csv = history.exportHistoryCsv((r) => r.sceneId, 'a,b,c,d');
  const elapsed = Date.now() - t0;
  assert.ok(csv.split('\n').length >= 500);
  assert.ok(elapsed < 250, `export took ${elapsed}ms`);
});

check('upload private key ignored by packOptions', () => {
  const cfg = JSON.parse(
    fs.readFileSync(path.join(root, 'project.config.json'), 'utf8'),
  );
  const ignore = (cfg.packOptions && cfg.packOptions.ignore) || [];
  assert.ok(
    ignore.some((p) => {
      const v = String((p && p.value) || p);
      return v.includes('private') || v.includes('.key');
    }),
    'packOptions should ignore upload key',
  );
});

if (failed) {
  console.error(`\n${failed} check(s) failed`);
  process.exit(1);
}
console.log('\nAll checks passed.');
