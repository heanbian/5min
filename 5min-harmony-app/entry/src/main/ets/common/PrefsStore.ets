import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE = '5min_prefs';

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

  private todayKey(): string {
    const d = new Date();
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    return `${d.getFullYear()}-${m}-${day}`;
  }

  async todayStats(): Promise<[number, number]> {
    const day = this.todayKey();
    const savedDay = String(await this.pref?.get('stats_day', '') ?? '');
    if (savedDay !== day) {
      return [0, 0];
    }
    const count = Number(await this.pref?.get('stats_count', 0) ?? 0);
    const ms = Number(await this.pref?.get('stats_ms', 0) ?? 0);
    return [count, ms];
  }

  async recordSession(elapsedMs: number): Promise<void> {
    const day = this.todayKey();
    const savedDay = String(await this.pref?.get('stats_day', '') ?? '');
    if (savedDay !== day) {
      await this.pref?.put('stats_day', day);
      await this.pref?.put('stats_count', 1);
      await this.pref?.put('stats_ms', Math.max(0, elapsedMs));
    } else {
      const count = Number(await this.pref?.get('stats_count', 0) ?? 0);
      const ms = Number(await this.pref?.get('stats_ms', 0) ?? 0);
      await this.pref?.put('stats_count', count + 1);
      await this.pref?.put('stats_ms', ms + Math.max(0, elapsedMs));
    }
    await this.pref?.flush();
  }
}
