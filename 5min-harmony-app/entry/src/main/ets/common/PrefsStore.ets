import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const STORE = '5min_prefs';

export class CustomScene {
  id: string = '';
  name: string = '';
  min: number = 5;

  static readonly GROUP_ID: string = 'custom';
  static readonly ID_PREFIX: string = 'custom_';
  static readonly MAX_COUNT: number = 30;
  static readonly MAX_NAME_LENGTH: number = 24;

  constructor(id: string, name: string, min: number) {
    this.id = id;
    this.name = name;
    this.min = min;
  }

  static makeId(): string {
    return `${CustomScene.ID_PREFIX}${util.generateRandomUUID().toLowerCase()}`;
  }

  static clampMinutes(value: number): number {
    if (isNaN(value)) {
      return 1;
    }
    return Math.max(1, Math.min(120, Math.floor(value)));
  }

  static normalizedName(raw: string): string {
    const trimmed = raw.trim();
    if (trimmed.length <= CustomScene.MAX_NAME_LENGTH) {
      return trimmed;
    }
    return trimmed.substring(0, CustomScene.MAX_NAME_LENGTH);
  }
}

/** App settings only; session history lives in HistoryStore (RDB). */
export class PrefsStore {
  private pref: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.pref = await preferences.getPreferences(context, STORE);
    await this.migrateFinishAlertPrefsIfNeeded();
  }

  private async migrateFinishAlertPrefsIfNeeded(): Promise<void> {
    const hasTone = await this.pref?.has('finish_tone');
    if (hasTone) {
      return;
    }
    const ambient = String(await this.pref?.get('ambient', 'off') ?? 'off');
    const legacyTone = ambient !== 'off';
    await this.pref?.put('finish_tone', legacyTone);
    await this.pref?.put('finish_vibrate', true);
    await this.pref?.put('finish_notify', true);
    await this.pref?.flush();
  }

  async getFinishTone(): Promise<boolean> {
    if (!(await this.pref?.has('finish_tone'))) {
      await this.migrateFinishAlertPrefsIfNeeded();
    }
    return Boolean(await this.pref?.get('finish_tone', true) ?? true);
  }

  async setFinishTone(on: boolean): Promise<void> {
    await this.pref?.put('finish_tone', on);
    await this.pref?.flush();
  }

  async getFinishVibrate(): Promise<boolean> {
    if (!(await this.pref?.has('finish_vibrate'))) {
      await this.migrateFinishAlertPrefsIfNeeded();
    }
    return Boolean(await this.pref?.get('finish_vibrate', true) ?? true);
  }

  async setFinishVibrate(on: boolean): Promise<void> {
    await this.pref?.put('finish_vibrate', on);
    await this.pref?.flush();
  }

  async getFinishNotify(): Promise<boolean> {
    if (!(await this.pref?.has('finish_notify'))) {
      await this.migrateFinishAlertPrefsIfNeeded();
    }
    return Boolean(await this.pref?.get('finish_notify', true) ?? true);
  }

  async setFinishNotify(on: boolean): Promise<void> {
    await this.pref?.put('finish_notify', on);
    await this.pref?.flush();
  }

  async getLocale(): Promise<string> {
    return String(await this.pref?.get('locale', '') ?? '');
  }

  async setLocale(code: string): Promise<void> {
    await this.pref?.put('locale', code);
    await this.pref?.flush();
  }

  async getAmbient(): Promise<string> {
    return String(await this.pref?.get('ambient', 'off') ?? 'off');
  }

  async setAmbient(mode: string): Promise<void> {
    await this.pref?.put('ambient', mode);
    await this.pref?.flush();
  }

  async getCustomMin(fallback: number = 5): Promise<number> {
    const n = Number(await this.pref?.get('custom_min', fallback) ?? fallback);
    if (isNaN(n) || n < 1) {
      return fallback;
    }
    return Math.min(120, Math.floor(n));
  }

  async setCustomMin(min: number): Promise<void> {
    const n = CustomScene.clampMinutes(min);
    await this.pref?.put('custom_min', n);
    await this.pref?.flush();
  }

  async getCustomScenes(): Promise<CustomScene[]> {
    const raw = String(await this.pref?.get('custom_scenes', '') ?? '');
    if (!raw) {
      return [];
    }
    try {
      const parsed: Object = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      const list = parsed as Record<string, Object>[];
      const out: CustomScene[] = [];
      for (let i = 0; i < list.length && out.length < CustomScene.MAX_COUNT; i++) {
        const item = list[i];
        if (!item) {
          continue;
        }
        const idRaw = String(item['id'] ?? '');
        const name = CustomScene.normalizedName(String(item['name'] ?? ''));
        const min = CustomScene.clampMinutes(Number(item['min'] ?? 5));
        if (!name) {
          continue;
        }
        out.push(new CustomScene(idRaw.length > 0 ? idRaw : CustomScene.makeId(), name, min));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  async setCustomScenes(scenes: CustomScene[]): Promise<void> {
    const cleaned: CustomScene[] = [];
    for (let i = 0; i < scenes.length && cleaned.length < CustomScene.MAX_COUNT; i++) {
      const scene = scenes[i];
      const name = CustomScene.normalizedName(scene.name);
      if (!name) {
        continue;
      }
      const id = scene.id && scene.id.length > 0 ? scene.id : CustomScene.makeId();
      cleaned.push(new CustomScene(id, name, CustomScene.clampMinutes(scene.min)));
    }
    const payload: Record<string, Object>[] = [];
    for (let i = 0; i < cleaned.length; i++) {
      const row: Record<string, Object> = {};
      row['id'] = cleaned[i].id;
      row['name'] = cleaned[i].name;
      row['min'] = cleaned[i].min;
      payload.push(row);
    }
    await this.pref?.put('custom_scenes', JSON.stringify(payload));
    await this.pref?.put('custom_scenes_migrated', true);
    await this.pref?.flush();
  }

  async isCustomScenesMigrated(): Promise<boolean> {
    return Boolean(await this.pref?.get('custom_scenes_migrated', false) ?? false);
  }

  async markCustomScenesMigrated(): Promise<void> {
    await this.pref?.put('custom_scenes_migrated', true);
    await this.pref?.flush();
  }

  async isPrivacyAccepted(): Promise<boolean> {
    return Boolean(await this.pref?.get('privacy_accepted', false) ?? false);
  }

  async setPrivacyAccepted(ok: boolean): Promise<void> {
    await this.pref?.put('privacy_accepted', ok);
    await this.pref?.flush();
  }
}
