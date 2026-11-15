/**
 * Copyright 2026 学记宝 / xuejibao.com
 * P0: overtime insight · stand-up ritual · alert profile
 */

const OVERTIME_STATS_KEY = '5min.overtime_stats';
const OVERTIME_INSIGHT_KEY = '5min.overtime_insight';
const STAND_RITUAL_KEY = '5min.stand_ritual';
const ALERT_PROFILE_KEY = '5min.alert_profile';

const RITUAL_OFF = 'off';
const RITUAL_BASIC = 'basic';
const PROFILE_NORMAL = 'normal';
const PROFILE_QUIET = 'quiet';
const PROFILE_SILENT = 'silent';

function weekKey(now = Date.now()) {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
}

function readOvertimeStats() {
  try {
    const raw = wx.getStorageSync(OVERTIME_STATS_KEY);
    if (!raw || typeof raw !== 'object') {
      return { weekKey: weekKey(), count: 0, ms: 0 };
    }
    const key = String(raw.weekKey || '');
    if (key !== weekKey()) {
      return { weekKey: weekKey(), count: 0, ms: 0 };
    }
    return {
      weekKey: key,
      count: Math.max(0, Math.floor(Number(raw.count) || 0)),
      ms: Math.max(0, Math.floor(Number(raw.ms) || 0)),
    };
  } catch (e) {
    return { weekKey: weekKey(), count: 0, ms: 0 };
  }
}

function writeOvertimeStats(stats) {
  try {
    wx.setStorageSync(OVERTIME_STATS_KEY, stats);
  } catch (e) {
    /* ignore */
  }
}

/** Record one overtime burst (ms beyond planned). */
function recordOvertime(overtimeMs) {
  const ms = Math.max(0, Math.floor(Number(overtimeMs) || 0));
  if (ms <= 0) return readOvertimeStats();
  const cur = readOvertimeStats();
  const next = {
    weekKey: weekKey(),
    count: cur.count + 1,
    ms: cur.ms + ms,
  };
  writeOvertimeStats(next);
  return next;
}

function getShowOvertimeInsight() {
  try {
    const v = wx.getStorageSync(OVERTIME_INSIGHT_KEY);
    if (v === '' || v == null) return true;
    return !!v;
  } catch (e) {
    return true;
  }
}

function setShowOvertimeInsight(on) {
  try {
    wx.setStorageSync(OVERTIME_INSIGHT_KEY, !!on);
  } catch (e) {
    /* ignore */
  }
}

function getStandRitual() {
  try {
    const v = String(wx.getStorageSync(STAND_RITUAL_KEY) || RITUAL_BASIC);
    return v === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF;
  } catch (e) {
    return RITUAL_BASIC;
  }
}

function setStandRitual(mode) {
  try {
    wx.setStorageSync(
      STAND_RITUAL_KEY,
      mode === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF
    );
  } catch (e) {
    /* ignore */
  }
}

function getAlertProfile() {
  try {
    const v = String(wx.getStorageSync(ALERT_PROFILE_KEY) || PROFILE_NORMAL);
    if (v === PROFILE_QUIET || v === PROFILE_SILENT) return v;
    return PROFILE_NORMAL;
  } catch (e) {
    return PROFILE_NORMAL;
  }
}

function setAlertProfile(mode) {
  const next =
    mode === PROFILE_QUIET || mode === PROFILE_SILENT ? mode : PROFILE_NORMAL;
  try {
    wx.setStorageSync(ALERT_PROFILE_KEY, next);
  } catch (e) {
    /* ignore */
  }
}

/**
 * Resolve effective finish alert flags from profile + user toggles.
 * @returns {{ withTone: boolean, withVibrate: boolean, withNotify: boolean }}
 */
function resolveFinishAlerts(prefs) {
  const profile = getAlertProfile();
  let withTone = !!prefs.getFinishTone();
  let withVibrate = !!prefs.getFinishVibrate();
  let withNotify = !!prefs.getFinishNotify();
  if (profile === PROFILE_QUIET) {
    withTone = false;
  } else if (profile === PROFILE_SILENT) {
    withTone = false;
    withVibrate = false;
  }
  return { withTone, withVibrate, withNotify };
}

function insightMinutes(ms) {
  return Math.max(1, Math.ceil(Math.max(0, ms) / 60000));
}

module.exports = {
  RITUAL_OFF,
  RITUAL_BASIC,
  PROFILE_NORMAL,
  PROFILE_QUIET,
  PROFILE_SILENT,
  weekKey,
  readOvertimeStats,
  recordOvertime,
  getShowOvertimeInsight,
  setShowOvertimeInsight,
  getStandRitual,
  setStandRitual,
  getAlertProfile,
  setAlertProfile,
  resolveFinishAlerts,
  insightMinutes,
};
