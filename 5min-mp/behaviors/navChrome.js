/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Shared custom-navigation metrics for tab pages.
 */

const { readNavMetrics } = require('../utils/navMetrics');

module.exports = Behavior({
  data: {
    navPadTop: 47,
    navBarHeight: 44,
    navPadRight: 96,
  },

  methods: {
    applyNavChrome() {
      const next = readNavMetrics();
      const cur = this.data || {};
      if (
        cur.navPadTop === next.navPadTop &&
        cur.navBarHeight === next.navBarHeight &&
        cur.navPadRight === next.navPadRight
      ) {
        return;
      }
      this.setData(next);
    },
  },

  onLoad() {
    this.applyNavChrome();
  },

  onReady() {
    this.applyNavChrome();
  },

  onShow() {
    this.applyNavChrome();
  },
});
