/**
 * Copyright 2026 学记宝 / xuejibao.com
 * P0: overtime insight · stand-up ritual · alert profile
 */

export const OVERTIME_STATS_KEY: string = '5min.overtime_stats';
export const OVERTIME_INSIGHT_KEY: string = '5min.overtime_insight';
export const STAND_RITUAL_KEY: string = '5min.stand_ritual';
export const ALERT_PROFILE_KEY: string = '5min.alert_profile';

export const RITUAL_OFF: string = 'off';
export const RITUAL_BASIC: string = 'basic';
export const PROFILE_NORMAL: string = 'normal';
export const PROFILE_QUIET: string = 'quiet';
export const PROFILE_SILENT: string = 'silent';

export class OvertimeStats {
  weekKey: string = '';
  count: number = 0;
  ms: number = 0;
}

export class FinishAlertFlags {
  withTone: boolean = true;
  withVibrate: boolean = true;
  withNotify: boolean = true;
}

/** Monday-start week key YYYY-MM-DD. */
export function weekKey(now?: number): string {
  const d = new Date(now !== undefined ? now : Date.now());
  d.setHours(0, 0, 0, 0);
  const day = d.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setDate(d.getDate() + diff);
  const y = d.getFullYear();
  const m = (d.getMonth() + 1).toString().padStart(2, '0');
  const dd = d.getDate().toString().padStart(2, '0');
  return `${y}-${m}-${dd}`;
}

export function emptyOvertimeStats(now?: number): OvertimeStats {
  const s = new OvertimeStats();
  s.weekKey = weekKey(now);
  s.count = 0;
  s.ms = 0;
  return s;
}

export function insightMinutes(ms: number): number {
  return Math.max(1, Math.ceil(Math.max(0, ms) / 60000));
}

export function normalizeStandRitual(mode: string): string {
  return mode === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF;
}

export function normalizeAlertProfile(mode: string): string {
  if (mode === PROFILE_QUIET || mode === PROFILE_SILENT) {
    return mode;
  }
  return PROFILE_NORMAL;
}

/**
 * Resolve effective finish alert flags from profile + user toggles.
 */
export function resolveFinishAlerts(
  profile: string,
  finishTone: boolean,
  finishVibrate: boolean,
  finishNotify: boolean
): FinishAlertFlags {
  const flags = new FinishAlertFlags();
  flags.withTone = finishTone;
  flags.withVibrate = finishVibrate;
  flags.withNotify = finishNotify;
  if (profile === PROFILE_QUIET) {
    flags.withTone = false;
  } else if (profile === PROFILE_SILENT) {
    flags.withTone = false;
    flags.withVibrate = false;
  }
  return flags;
}

export class RitualPack {
  titleKey: string = 'standRitualTitle';
  stepKeys: string[] = [
    'standRitualStepUp',
    'standRitualStepStretch',
    'standRitualStepLeave',
  ];
}

/** Scene ritual pack: kitchen / care / default (toilet & others). */
export function resolveRitualPack(sceneId?: string, sceneGroup?: string): RitualPack {
  const group = (sceneGroup || '').trim();
  const pack = new RitualPack();
  if (group === 'kitchen') {
    pack.titleKey = 'standRitualTitleKitchen';
    pack.stepKeys = [
      'standRitualStepKitchenStove',
      'standRitualStepKitchenFood',
      'standRitualStepKitchenSafe',
    ];
    return pack;
  }
  if (group === 'care') {
    pack.titleKey = 'standRitualTitleCare';
    pack.stepKeys = [
      'standRitualStepCareRemove',
      'standRitualStepCareFinish',
      'standRitualStepCareDone',
    ];
    return pack;
  }
  return pack;
}
