/**
 * Publishes today-count / timer remain into Preferences for the service widget,
 * and pushes FormBindingData to registered formIds.
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const STORE = '5min_widget';
const FORM_IDS_KEY = 'form_ids';
const TODAY_COUNT_KEY = 'today_count';
const REMAIN_TEXT_KEY = 'remain_text';
const RUNNING_KEY = 'timer_running';
const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'WidgetGlance';

export class WidgetGlanceData {
  todayCount: number = 0;
  remainText: string = '';
  running: boolean = false;
}

export class WidgetGlance {
  static async publish(
    context: common.Context,
    todayCount: number,
    remainText: string,
    running: boolean
  ): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, STORE);
      await pref.put(TODAY_COUNT_KEY, Math.max(0, Math.floor(todayCount)));
      await pref.put(REMAIN_TEXT_KEY, remainText ? remainText : '');
      await pref.put(RUNNING_KEY, !!running);
      await pref.flush();
      const ids = await WidgetGlance.readFormIds(pref);
      for (let i = 0; i < ids.length; i++) {
        await WidgetGlance.pushForm(ids[i], todayCount, remainText, running);
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'publish failed %{public}s', JSON.stringify(e));
    }
  }

  static async registerForm(context: common.Context, formId: string): Promise<void> {
    if (!formId) {
      return;
    }
    try {
      const pref = await preferences.getPreferences(context, STORE);
      const ids = await WidgetGlance.readFormIds(pref);
      if (ids.indexOf(formId) < 0) {
        ids.push(formId);
        await pref.put(FORM_IDS_KEY, JSON.stringify(ids));
        await pref.flush();
      }
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'registerForm failed %{public}s', JSON.stringify(e));
    }
  }

  static async unregisterForm(context: common.Context, formId: string): Promise<void> {
    if (!formId) {
      return;
    }
    try {
      const pref = await preferences.getPreferences(context, STORE);
      const ids = await WidgetGlance.readFormIds(pref);
      const next = ids.filter((id: string) => id !== formId);
      await pref.put(FORM_IDS_KEY, JSON.stringify(next));
      await pref.flush();
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'unregisterForm failed %{public}s', JSON.stringify(e));
    }
  }

  static async read(context: common.Context): Promise<WidgetGlanceData> {
    const data = new WidgetGlanceData();
    try {
      const pref = await preferences.getPreferences(context, STORE);
      data.todayCount = Math.max(0, Math.floor(Number(await pref.get(TODAY_COUNT_KEY, 0) ?? 0)));
      data.remainText = String(await pref.get(REMAIN_TEXT_KEY, '') ?? '');
      data.running = Boolean(await pref.get(RUNNING_KEY, false) ?? false);
    } catch (_) {
    }
    return data;
  }

  /** Sync snapshot for FormExtensionAbility.onAddForm (must return immediately). */
  static readSync(context: common.Context): WidgetGlanceData {
    const data = new WidgetGlanceData();
    try {
      const pref = preferences.getPreferencesSync(context, { name: STORE });
      data.todayCount = Math.max(0, Math.floor(Number(pref.getSync(TODAY_COUNT_KEY, 0) ?? 0)));
      data.remainText = String(pref.getSync(REMAIN_TEXT_KEY, '') ?? '');
      data.running = Boolean(pref.getSync(RUNNING_KEY, false) ?? false);
    } catch (_) {
    }
    return data;
  }

  static bindingPayload(data: WidgetGlanceData): Record<string, Object> {
    const payload: Record<string, Object> = {};
    payload['todayCount'] = data.todayCount;
    payload['remainText'] = data.remainText;
    payload['running'] = data.running;
    payload['countLine'] = `今日 ${data.todayCount} 次`;
    payload['remainLine'] = data.running && data.remainText.length > 0
      ? `剩余 ${data.remainText}`
      : '';
    return payload;
  }

  static async pushForm(
    formId: string,
    todayCount: number,
    remainText: string,
    running: boolean
  ): Promise<void> {
    if (!formId) {
      return;
    }
    const data = new WidgetGlanceData();
    data.todayCount = Math.max(0, Math.floor(todayCount));
    data.remainText = remainText ? remainText : '';
    data.running = !!running;
    try {
      const binding = formBindingData.createFormBindingData(WidgetGlance.bindingPayload(data));
      await formProvider.updateForm(formId, binding);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'updateForm %{public}s failed %{public}s', formId, JSON.stringify(e));
    }
  }

  private static async readFormIds(pref: preferences.Preferences): Promise<string[]> {
    const raw = String(await pref.get(FORM_IDS_KEY, '[]') ?? '[]');
    try {
      const parsed: Object = JSON.parse(raw) as Object;
      if (!Array.isArray(parsed)) {
        return [];
      }
      const list = parsed as Object[];
      const out: string[] = [];
      for (let i = 0; i < list.length; i++) {
        const id = String(list[i] ?? '');
        if (id.length > 0 && out.indexOf(id) < 0) {
          out.push(id);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
