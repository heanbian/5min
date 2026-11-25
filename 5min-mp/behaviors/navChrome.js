/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Shared custom-navigation metrics for tab pages.
 */

const { readNavMetrics } = require('../utils/navMetrics');

module.exports = Behavior({
  data: {
    navBarHeight: 44,
    navPadTop: 44,
    navPadRight: 96,
  },

  methods: {
    applyNavChrome() {
      this.setData(readNavMetrics());
    },
  },

  onLoad() {
    this.applyNavChrome();
  },
});
