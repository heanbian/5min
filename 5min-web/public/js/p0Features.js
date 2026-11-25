/**
 * Copyright 2026 学记宝 / xuejibao.com
 * Licensed under the Apache License, Version 2.0
 *
 * P0: overtime insight · stand-up ritual · alert profile
 * (localStorage port of 5min-mp/utils/p0Features.js)
 */

const OVERTIME_STATS_KEY = '5min.overtime_stats';
const OVERTIME_INSIGHT_KEY = '5min.overtime_insight';
const STAND_RITUAL_KEY = '5min.stand_ritual';
const ALERT_PROFILE_KEY = '5min.alert_profile';

export const RITUAL_OFF = 'off';
export const RITUAL_BASIC = 'basic';
export const PROFILE_NORMAL = 'normal';
export const PROFILE_QUIET = 'quiet';
export const PROFILE_SILENT = 'silent';

const lsGet = (key) => {
  try {
    return localStorage.getItem(key);
  } catch {
    return null;
  }
};

const lsSet = (key, value) => {
  try {
    localStorage.setItem(key, value);
  } catch {
    /* ignore */
  }
};

export const weekKey = (now = Date.now()) => {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${dd}`;
};

const emptyStats = () => ({ weekKey: weekKey(), count: 0, ms: 0 });

export const readOvertimeStats = () => {
  try {
    const raw = lsGet(OVERTIME_STATS_KEY);
    if (!raw) return emptyStats();
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return emptyStats();
    const key = String(parsed.weekKey || '');
    if (key !== weekKey()) return emptyStats();
    return {
      weekKey: key,
      count: Math.max(0, Math.floor(Number(parsed.count) || 0)),
      ms: Math.max(0, Math.floor(Number(parsed.ms) || 0)),
    };
  } catch {
    return emptyStats();
  }
};

const writeOvertimeStats = (stats) => {
  try {
    lsSet(OVERTIME_STATS_KEY, JSON.stringify(stats));
  } catch {
    /* ignore */
  }
};

/** Record one overtime burst (ms beyond planned). */
export const recordOvertime = (overtimeMs) => {
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
};

export const getShowOvertimeInsight = () => {
  const v = lsGet(OVERTIME_INSIGHT_KEY);
  if (v === null || v === '') return true;
  return v === '1' || v === 'true';
};

export const setShowOvertimeInsight = (on) => {
  lsSet(OVERTIME_INSIGHT_KEY, on ? '1' : '0');
};

export const getStandRitual = () => {
  const v = String(lsGet(STAND_RITUAL_KEY) || RITUAL_BASIC);
  return v === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF;
};

export const setStandRitual = (mode) => {
  lsSet(STAND_RITUAL_KEY, mode === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF);
};

export const getAlertProfile = () => {
  const v = String(lsGet(ALERT_PROFILE_KEY) || PROFILE_NORMAL);
  if (v === PROFILE_QUIET || v === PROFILE_SILENT) return v;
  return PROFILE_NORMAL;
};

export const setAlertProfile = (mode) => {
  const next =
    mode === PROFILE_QUIET || mode === PROFILE_SILENT ? mode : PROFILE_NORMAL;
  lsSet(ALERT_PROFILE_KEY, next);
};

/**
 * @param {{ getFinishTone: () => boolean, getFinishVibrate: () => boolean, getFinishNotify: () => boolean }} prefs
 * @returns {{ withTone: boolean, withVibrate: boolean, withNotify: boolean }}
 */
export const resolveFinishAlerts = (prefs) => {
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
};

export const insightMinutes = (ms) =>
  Math.max(1, Math.ceil(Math.max(0, ms) / 60_000));

/**
 * @returns {{ titleKey: string, stepKeys: string[] }}
 */
export const resolveRitualPack = (sceneId, sceneGroup) => {
  const group = String(sceneGroup || '').trim();
  const id = String(sceneId || '').trim();
  if (group === 'kitchen') {
    return {
      titleKey: 'standRitualTitleKitchen',
      stepKeys: [
        'standRitualStepKitchenStove',
        'standRitualStepKitchenFood',
        'standRitualStepKitchenSafe',
      ],
    };
  }
  if (group === 'care') {
    return {
      titleKey: 'standRitualTitleCare',
      stepKeys: [
        'standRitualStepCareRemove',
        'standRitualStepCareFinish',
        'standRitualStepCareDone',
      ],
    };
  }
  if (id === 'toilet' || group === 'daily') {
    return {
      titleKey: 'standRitualTitle',
      stepKeys: [
        'standRitualStepUp',
        'standRitualStepStretch',
        'standRitualStepLeave',
      ],
    };
  }
  return {
    titleKey: 'standRitualTitle',
    stepKeys: [
      'standRitualStepUp',
      'standRitualStepStretch',
      'standRitualStepLeave',
    ],
  };
};
