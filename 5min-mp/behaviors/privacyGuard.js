/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Attach to every tabBar page. Unconsented users are reLaunched to boot.
 */

const privacy = require('../services/privacy');
const { updateTabBarLabels } = require('../utils/tabBar');

module.exports = Behavior({
  data: {
    privacyReady: false,
  },

  methods: {
    /** @returns {boolean} true when UI may render */
    guardPrivacy() {
      const ok = privacy.ensureAcceptedOrBoot();
      if (ok) {
        this.setData({ privacyReady: true });
        try {
          updateTabBarLabels();
        } catch (e) {
          /* ignore */
        }
      }
      return ok;
    },
  },

  onShow() {
    this.guardPrivacy();
  },
});
