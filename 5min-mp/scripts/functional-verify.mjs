/**
 * Functional verification for 5min-mp (Node, no WeChat runtime).
 * Covers privacy gate, mine sheets, prefs/cloud/history/p0, and WXML contracts.
 * Run: node scripts/functional-verify.mjs
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
const requests = [];

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
  showTabBar() {},
  hideTabBar() {},
  showModal() {},
  navigateTo(opts) {
    navigations.push(opts && opts.url);
  },
  switchTab(opts) {
    navigations.push(`switchTab:${opts && opts.url}`);
  },
  reLaunch(opts) {
    navigations.push(`reLaunch:${opts && opts.url}`);
  },
  setClipboardData(opts) {
    if (opts && typeof opts.success === 'function') opts.success();
  },
  getAppBaseInfo() {
    return { language: 'zh_CN' };
  },
  getRandomValues(opts) {
    if (opts && typeof opts.length === 'number') {
      const buf = new Uint8Array(opts.length);
      for (let i = 0; i < opts.length; i += 1) buf[i] = (i * 17 + 3) & 0xff;
      if (typeof opts.success === 'function') {
        opts.success({ randomValues: buf.buffer });
      }
      return;
    }
  },
  request(opts) {
    requests.push({
      url: opts.url,
      method: opts.method,
      header: opts.header,
      data: opts.data,
    });
    const res = {
      statusCode: 200,
      data: { success: true, data: { ok: true } },
    };
    if (typeof opts.success === 'function') opts.success(res);
  },
};

global.getApp = () => ({
  globalData: {
    privacyAccepted: false,
    pendingSceneId: null,
  },
});

let failed = 0;
function check(name, fn) {
  try {
    const ret = fn();
    if (ret && typeof ret.then === 'function') {
      return ret
        .then(() => console.log('ok ', name))
        .catch((e) => {
          failed += 1;
          console.error('FAIL', name, e && e.message ? e.message : e);
        });
    }
    console.log('ok ', name);
    return Promise.resolve();
  } catch (e) {
    failed += 1;
    console.error('FAIL', name, e && e.message ? e.message : e);
    return Promise.resolve();
  }
}

function makePageHarness() {
  return {
    data: {
      dialog: '',
      dialogTitle: '',
      maskClosable: true,
      privacyAccepted: true,
      locale: 'zh-CN',
      ambient: 'off',
      localeOptions: [],
      soundOptions: [],
    },
    _sheetOpenedAt: 0,
    _maskUnlockTimer: 0,
    setData(partial) {
      Object.assign(this.data, partial);
    },
    openSheet(dialog, extra) {
      const name = String(dialog || '');
      if (!name) return;
      this._sheetOpenedAt = Date.now();
      this.data.maskClosable = false;
      this.data.dialog = name;
      this.setData(
        Object.assign({ dialog: name, maskClosable: false }, extra || {}),
      );
      if (this._maskUnlockTimer) clearTimeout(this._maskUnlockTimer);
      this._maskUnlockTimer = setTimeout(() => {
        this._maskUnlockTimer = 0;
        if (this.data.dialog === name) {
          this.data.maskClosable = true;
          this.setData({ maskClosable: true });
        }
      }, 20);
    },
    onMaskClose() {
      if (!this.data.dialog) return;
      if (!this.data.maskClosable) return;
      if (Date.now() - (this._sheetOpenedAt || 0) < 20) return;
      this.onCloseDialog();
    },
    onCloseDialog() {
      if (this._maskUnlockTimer) {
        clearTimeout(this._maskUnlockTimer);
        this._maskUnlockTimer = 0;
      }
      this.setData({ dialog: '', maskClosable: true });
    },
    onOpenLang() {
      this.openSheet('lang', {
        dialogTitle: '语言',
        localeOptions: [{ code: 'zh-CN', label: '简体中文' }],
      });
    },
    onOpenSound() {
      this.openSheet('sound', {
        dialogTitle: '环境音',
        soundOptions: [{ id: 'off', label: '关闭' }],
      });
    },
    onOpenStorage() {
      this.openSheet('storage', {
        dialogTitle: '存储方式',
        storageOptions: [
          { id: 'local', label: '本机' },
          { id: 'cloud', label: '云端' },
        ],
      });
    },
    onPickLocale() {
      this.setData({ dialog: '', locale: 'en' });
    },
  };
}

await check('mine WXML uses root-portal and non-enhanced scroll-view', () => {
  const wxml = fs.readFileSync(path.join(root, 'pages/mine/mine.wxml'), 'utf8');
  assert.ok(wxml.includes('<root-portal'), 'missing root-portal');
  assert.ok(wxml.includes('</root-portal>'), 'missing root-portal close');
  assert.ok(
    !/<scroll-view[^>]*\benhanced\b/.test(wxml),
    'mine scroll-view must not use enhanced (blocks fixed overlays)',
  );
  const portalIdx = wxml.indexOf('<root-portal');
  const sheetIdx = wxml.indexOf('class="sheet-mask"');
  assert.ok(portalIdx > 0 && sheetIdx > portalIdx, 'sheet-mask must be inside root-portal');
  assert.ok(wxml.includes('catchtap="onOpenLang"'));
  assert.ok(wxml.includes('catchtap="onOpenStorage"'));
  assert.ok(wxml.includes('catchtap="onOpenRitual"'));
  assert.ok(wxml.includes('catchtap="onShowRecoveryCode"'));
  const appCss = fs.readFileSync(path.join(root, 'app.wxss'), 'utf8');
  assert.ok(appCss.includes('.sheet-mask') && appCss.includes('.sheet-item'));
});

await check('mine sheet open / tap-through guard / pick close', async () => {
  const page = makePageHarness();
  page.onOpenLang();
  assert.equal(page.data.dialog, 'lang');
  assert.equal(page.data.maskClosable, false);
  assert.equal(page.data.dialogTitle, '语言');
  assert.ok(page.data.localeOptions.length >= 1);

  page.onMaskClose();
  assert.equal(page.data.dialog, 'lang', 'tap-through must not close sheet');

  await new Promise((r) => setTimeout(r, 30));
  assert.equal(page.data.maskClosable, true);

  page.onPickLocale();
  assert.equal(page.data.dialog, '');
  assert.equal(page.data.locale, 'en');

  page.onOpenSound();
  assert.equal(page.data.dialog, 'sound');
  await new Promise((r) => setTimeout(r, 30));
  page.onMaskClose();
  assert.equal(page.data.dialog, '');

  page.onOpenStorage();
  assert.equal(page.data.dialog, 'storage');
  assert.ok(page.data.storageOptions.length === 2);
});

await check('privacy boot routing + consent accept', () => {
  store.clear();
  navigations.length = 0;
  global.getApp = () => ({ globalData: { privacyAccepted: false } });
  const privacy = require('../services/privacy.js');
  const { openLegal } = require('../utils/legalDocs.js');

  assert.equal(privacy.isAccepted(), false);
  assert.equal(privacy.ensureAcceptedOrBoot(), false);
  assert.ok(navigations.some((u) => String(u).includes('reLaunch:/pages/boot/boot')));

  navigations.length = 0;
  privacy.accept();
  privacy.enterApp();
  assert.equal(privacy.isAccepted(), true);
  assert.ok(navigations.some((u) => String(u).includes('switchTab:/pages/index/index')));

  openLegal('privacy');
  assert.ok(navigations.some((u) => String(u).includes('legal?doc=privacy')));
  navigations.length = 0;
  openLegal('about');
  assert.ok(navigations.some((u) => String(u).includes('legal?doc=about')));
});

await check('tab pages use privacyGuard; consent is boot-only', () => {
  const appJson = JSON.parse(fs.readFileSync(path.join(root, 'app.json'), 'utf8'));
  assert.equal(appJson.pages[0], 'pages/boot/boot');
  const bootWxml = fs.readFileSync(path.join(root, 'pages/boot/boot.wxml'), 'utf8');
  assert.ok(bootWxml.includes('bindtap="onToggleAgree"'));
  assert.ok(!bootWxml.includes('<button'));
  assert.ok(!bootWxml.includes('<checkbox'));
  assert.ok(!bootWxml.includes('cover-view'));
  const bootJs = fs.readFileSync(path.join(root, 'pages/boot/boot.js'), 'utf8');
  assert.ok(bootJs.includes('onToggleAgree'));
  assert.ok(bootJs.includes('onAccept'));
  for (const rel of [
    'pages/index/index.js',
    'pages/records/records.js',
    'pages/mine/mine.js',
  ]) {
    const js = fs.readFileSync(path.join(root, rel), 'utf8');
    assert.ok(js.includes('privacyGuard'), `${rel} needs privacyGuard`);
    const wxml = fs.readFileSync(path.join(root, rel.replace('.js', '.wxml')), 'utf8');
    assert.ok(!wxml.includes('privacy-gate'), `${rel} must not mount privacy overlay`);
  }
  const indexWxml = fs.readFileSync(path.join(root, 'pages/index/index.wxml'), 'utf8');
  assert.ok(indexWxml.includes('<canvas'));
  assert.ok(indexWxml.includes('<picker'));
});

await check('cloudSync register keeps credentials in headers only', async () => {
  store.clear();
  requests.length = 0;
  const cloudSync = require('../utils/cloudSync.js');
  const prefs = require('../utils/prefs.js');
  prefs.setStorageMode('cloud');
  prefs.setDeviceCredentials(
    '550e8400-e29b-41d4-a716-446655440000',
    'ab'.repeat(32),
  );
  await cloudSync.pushPrefsOnly();
  const reg = requests.find((r) => String(r.url).includes('/register'));
  assert.ok(reg, 'register request missing');
  assert.deepStrictEqual(reg.data, {});
  assert.ok(reg.header['X-Device-Id']);
  assert.ok(reg.header['X-Device-Secret']);
});

await check('recovery code parse + format', () => {
  store.clear();
  const prefs = require('../utils/prefs.js');
  const goodId = '550e8400-e29b-41d4-a716-446655440000';
  const goodSecret = 'ab'.repeat(32);
  assert.ok(prefs.parseRecoveryCode(`${goodId}:${goodSecret}`));
  assert.ok(prefs.parseRecoveryCode(` ${goodId} : ${goodSecret} `));
  assert.equal(prefs.parseRecoveryCode('bad'), null);
  assert.equal(prefs.parseRecoveryCode(`${goodId}:zz`), null);
  prefs.setDeviceCredentials(goodId, goodSecret);
  assert.equal(prefs.formatRecoveryCode(), `${goodId}:${goodSecret}`);
});

await check('history CSV formula escape + prune write skip', () => {
  store.clear();
  const history = require('../utils/history.js');
  assert.equal(history.escapeCsvCell('=cmd'), "'=cmd");
  history.replaceAll([
    {
      id: 'r1',
      at: Date.now(),
      minutes: 5,
      sceneId: '+inject',
      elapsedMs: 300000,
    },
  ]);
  let writes = 0;
  const orig = wx.setStorageSync;
  wx.setStorageSync = (k, v) => {
    writes += 1;
    orig.call(wx, k, v);
  };
  history.getHistory();
  wx.setStorageSync = orig;
  assert.equal(writes, 0);
  const csv = history.exportHistoryCsv((r) => r.sceneId, 'a,b,c,d');
  assert.ok(csv.includes("'+inject"));
});

await check('p0 prefs round-trip', () => {
  store.clear();
  const p0 = require('../utils/p0Features.js');
  p0.setStandRitual(p0.RITUAL_OFF);
  assert.equal(p0.getStandRitual(), p0.RITUAL_OFF);
  p0.setAlertProfile(p0.PROFILE_SILENT);
  assert.equal(p0.getAlertProfile(), p0.PROFILE_SILENT);
  p0.setShowOvertimeInsight(false);
  assert.equal(p0.getShowOvertimeInsight(), false);
  const stats = p0.recordOvertime(120000);
  assert.ok(stats.count >= 1);
});

await check('app.wxss has no local @font-face urls', () => {
  const css = fs.readFileSync(path.join(root, 'app.wxss'), 'utf8');
  assert.ok(!/@font-face[\s\S]*url\s*\(\s*['"]?\/fonts\//.test(css));
});

await check('https allowlist still rejects open redirects', () => {
  const { isAllowedHttps } = require('../utils/openUrl.js');
  assert.equal(isAllowedHttps('https://5min.chat/privacy.html'), true);
  assert.equal(isAllowedHttps('https://evil.com/?u=https://5min.chat'), false);
});

await check('mine.js defines openSheet and sheet openers', () => {
  const js = fs.readFileSync(path.join(root, 'pages/mine/mine.js'), 'utf8');
  assert.ok(js.includes('openSheet(dialog, extra)'));
  assert.ok(js.includes("openSheet('lang'"));
  assert.ok(js.includes("openSheet('sound'"));
  assert.ok(js.includes("openSheet('storage'"));
  assert.ok(js.includes("openSheet('ritual'"));
  assert.ok(js.includes("openSheet('alertProfile'"));
  assert.ok(js.includes("openSheet('backup'"));
  assert.ok(js.includes("openSheet('feedback'"));
  assert.ok(js.includes('privacyGuard'));
  assert.ok(js.includes('navChrome'));
  assert.ok(js.includes('onOpenPrivacy'));
  assert.ok(js.includes('onOpenTerms'));
  assert.ok(js.includes('onOpenAbout'));
  assert.ok(js.includes("openLegal('privacy')"));
  assert.ok(js.includes("openLegal('terms')"));
  assert.ok(js.includes("openLegal('about')"));
});

if (failed) {
  console.error(`\n${failed} functional check(s) failed`);
  process.exit(1);
}
console.log('\nAll functional checks passed.');
