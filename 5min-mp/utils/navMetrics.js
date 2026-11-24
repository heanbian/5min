/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 */

function readNavMetrics() {
  try {
    const win =
      typeof wx.getWindowInfo === 'function' ? wx.getWindowInfo() : {};
    const menu =
      typeof wx.getMenuButtonBoundingClientRect === 'function'
        ? wx.getMenuButtonBoundingClientRect()
        : null;
    const statusBarHeight = (win && win.statusBarHeight) || 20;
    const windowWidth = (win && win.windowWidth) || 375;
    const menuHeight = (menu && menu.height) || 32;
    const menuTop = (menu && menu.top) || statusBarHeight + 6;
    const navBarHeight = menuHeight + (menuTop - statusBarHeight) * 2;
    const navPadTop = statusBarHeight;
    const navPadRight = menu
      ? Math.max(8, windowWidth - menu.left + 8)
      : 96;
    return { navBarHeight, navPadTop, navPadRight };
  } catch (e) {
    return { navBarHeight: 44, navPadTop: 44, navPadRight: 96 };
  }
}

module.exports = { readNavMetrics };
