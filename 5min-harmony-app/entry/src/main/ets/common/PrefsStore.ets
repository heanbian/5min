import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE = '5min_prefs';

/** App settings only; session history lives in HistoryStore (RDB). */
export class PrefsStore {
  private pref: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.pref = await preferences.getPreferences(context, STORE);
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
    const n = Math.max(1, Math.min(120, Math.floor(min)));
    await this.pref?.put('custom_min', n);
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
