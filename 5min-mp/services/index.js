/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 * Domain services facade — pages/components import from here.
 */

module.exports = {
  privacy: require('./privacy'),
  timer: require('./timer'),
  prefs: require('../utils/prefs'),
  i18n: require('../utils/i18n'),
  history: require('../utils/history'),
  cloudSync: require('../utils/cloudSync'),
  ambient: require('../utils/ambient'),
  catalog: require('../utils/catalog'),
  tabBar: require('../utils/tabBar'),
  legalDocs: require('../utils/legalDocs'),
  navMetrics: require('../utils/navMetrics'),
  p0: require('../utils/p0Features'),
  alert: require('../utils/alert'),
  stats: require('../utils/stats'),
};
