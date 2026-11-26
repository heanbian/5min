/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * Custom navigation metrics aligned to the WeChat capsule.
 * Layout: statusBar padding + nav row height whose vertical center
 * matches the capsule (menu.top - statusBar) * 2 + menu.height.
 */

function readWindowSize() {
  let statusBarHeight = 0;
  let windowWidth = 375;
  try {
    if (typeof wx.getWindowInfo === 'function') {
      const win = wx.getWindowInfo();
      statusBarHeight = Number(win && win.statusBarHeight) || 0;
      windowWidth = Number(win && win.windowWidth) || windowWidth;
      if (!statusBarHeight && win && win.safeArea) {
        statusBarHeight = Number(win.safeArea.top) || 0;
      }
    }
  } catch (e) {
    /* ignore */
  }
  if (!statusBarHeight || !windowWidth) {
    try {
      const sys = wx.getSystemInfoSync();
      if (!statusBarHeight) {
        statusBarHeight = Number(sys && sys.statusBarHeight) || 0;
      }
      if (!statusBarHeight && sys && sys.safeArea) {
        statusBarHeight = Number(sys.safeArea.top) || 0;
      }
      if (sys && sys.windowWidth) {
        windowWidth = Number(sys.windowWidth) || windowWidth;
      }
    } catch (e) {
      /* ignore */
    }
  }
  if (!statusBarHeight) statusBarHeight = 47;
  return { statusBarHeight, windowWidth };
}

function readMenuRect() {
  try {
    if (typeof wx.getMenuButtonBoundingClientRect !== 'function') return null;
    const menu = wx.getMenuButtonBoundingClientRect();
    if (!menu || !(menu.width > 0) || !(menu.height > 0)) return null;
    const top = Number(menu.top) || 0;
    let height = Number(menu.height) || 0;
    if ((!height || height < 20) && menu.bottom > menu.top) {
      height = Number(menu.bottom) - top;
    }
    const left = Number(menu.left) || 0;
    if (!(top > 0) || !(height > 0)) return null;
    return { top, height, left };
  } catch (e) {
    return null;
  }
}

function readNavMetrics() {
  const { statusBarHeight, windowWidth } = readWindowSize();
  const menu = readMenuRect();

  let menuTop = menu ? menu.top : statusBarHeight + 6;
  let menuHeight = menu ? menu.height : 32;
  // Capsule must sit at/below the status bar; reject impossible early readings.
  if (menuTop + 1 < statusBarHeight) {
    menuTop = statusBarHeight + 6;
  }

  const gap = Math.max(4, Math.round(menuTop - statusBarHeight));
  const navPadTop = statusBarHeight;
  const navBarHeight = Math.round(menuHeight + gap * 2);
  const navPadRight = menu && menu.left > 0
    ? Math.max(8, Math.round(windowWidth - menu.left + 8))
    : 96;

  return { navPadTop, navBarHeight, navPadRight };
}

module.exports = { readNavMetrics };
