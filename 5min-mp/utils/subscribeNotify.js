/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * WeChat Mini Program has no OS-level local notifications. Subscribe-message
 * templates can be used for *future* server pushes after user grant — but this
 * app's finish cue is a local timer with no server push path.
 *
 * Product must fill real template IDs from WeChat MP Admin
 * (订阅消息 → 我的模板). Keep TMPL_IDS empty until then; the helper no-ops.
 */

/**
 * Placeholder — replace with up to 3 template IDs from WeChat MP admin.
 * @type {string[]}
 */
const TMPL_IDS = Object.freeze([]);

/**
 * Request subscribe-message authorization (must run in a user gesture).
 * Resolves whether granted, denied, or skipped (empty TMPL_IDS / API missing).
 * @returns {Promise<{ skipped?: boolean, granted?: boolean, result?: object, err?: object }>}
 */
function requestFinishSubscribe() {
  return new Promise((resolve) => {
    const ids = TMPL_IDS.filter((id) => typeof id === 'string' && id.trim());
    if (!ids.length) {
      resolve({ skipped: true });
      return;
    }
    if (typeof wx.requestSubscribeMessage !== 'function') {
      resolve({ skipped: true });
      return;
    }
    try {
      wx.requestSubscribeMessage({
        tmplIds: ids.slice(0, 3),
        success(res) {
          const granted = ids.some((id) => res && res[id] === 'accept');
          resolve({ granted, result: res });
        },
        fail(err) {
          resolve({ granted: false, err: err || {} });
        },
      });
    } catch (e) {
      resolve({ granted: false, err: e || {} });
    }
  });
}

module.exports = {
  TMPL_IDS,
  requestFinishSubscribe,
};
