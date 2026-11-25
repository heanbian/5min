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
const BRAND_KEY = 'brand_title';
const COUNT_LINE_KEY = 'count_line';
const REMAIN_LINE_KEY = 'remain_line';
const TAP_OPEN_KEY = 'tap_open';
const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'WidgetGlance';

export class WidgetGlanceData {
  todayCount: number = 0;
  remainText: string = '';
  running: boolean = false;
  brandTitle: string = '如厕计时器';
  countLine: string = '';
  remainLine: string = '';
  tapOpen: string = '轻触打开';
}

export class WidgetGlance {
  static async publish(
    context: common.Context,
    todayCount: number,
    remainText: string,
    running: boolean,
    brandTitle: string = '',
    countLine: string = '',
    remainLine: string = '',
    tapOpen: string = ''
  ): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, STORE);
      const count = Math.max(0, Math.floor(todayCount));
      const remain = remainText ? remainText : '';
      const isRunning = !!running;
      const brand = brandTitle.length > 0 ? brandTitle : '如厕计时器';
      const countL = countLine.length > 0 ? countLine : `今日 ${count} 次`;
      const remainL = remainLine.length > 0
        ? remainLine
        : (isRunning && remain.length > 0 ? `剩余 ${remain}` : '');
      const tap = tapOpen.length > 0 ? tapOpen : '轻触打开';
      await pref.put(TODAY_COUNT_KEY, count);
      await pref.put(REMAIN_TEXT_KEY, remain);
      await pref.put(RUNNING_KEY, isRunning);
      await pref.put(BRAND_KEY, brand);
      await pref.put(COUNT_LINE_KEY, countL);
      await pref.put(REMAIN_LINE_KEY, remainL);
      await pref.put(TAP_OPEN_KEY, tap);
      await pref.flush();
      const ids = await WidgetGlance.readFormIds(pref);
      const data = new WidgetGlanceData();
      data.todayCount = count;
      data.remainText = remain;
      data.running = isRunning;
      data.brandTitle = brand;
      data.countLine = countL;
      data.remainLine = remainL;
      data.tapOpen = tap;
      for (let i = 0; i < ids.length; i++) {
        await WidgetGlance.pushFormData(ids[i], data);
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
      await WidgetGlance.fillFromPrefAsync(data, pref);
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
      data.brandTitle = String(pref.getSync(BRAND_KEY, '如厕计时器') ?? '如厕计时器');
      data.countLine = String(pref.getSync(COUNT_LINE_KEY, '') ?? '');
      data.remainLine = String(pref.getSync(REMAIN_LINE_KEY, '') ?? '');
      data.tapOpen = String(pref.getSync(TAP_OPEN_KEY, '轻触打开') ?? '轻触打开');
    } catch (_) {
    }
    return data;
  }

  static bindingPayload(data: WidgetGlanceData): Record<string, Object> {
    const payload: Record<string, Object> = {};
    payload['todayCount'] = data.todayCount;
    payload['remainText'] = data.remainText;
    payload['running'] = data.running;
    payload['brandTitle'] = data.brandTitle.length > 0 ? data.brandTitle : '如厕计时器';
    payload['countLine'] = data.countLine.length > 0
      ? data.countLine
      : `今日 ${data.todayCount} 次`;
    payload['remainLine'] = data.remainLine.length > 0
      ? data.remainLine
      : (data.running && data.remainText.length > 0 ? `剩余 ${data.remainText}` : '');
    payload['tapOpen'] = data.tapOpen.length > 0 ? data.tapOpen : '轻触打开';
    return payload;
  }

  static async pushForm(
    formId: string,
    todayCount: number,
    remainText: string,
    running: boolean
  ): Promise<void> {
    const data = new WidgetGlanceData();
    data.todayCount = Math.max(0, Math.floor(todayCount));
    data.remainText = remainText ? remainText : '';
    data.running = !!running;
    data.countLine = `今日 ${data.todayCount} 次`;
    data.remainLine = data.running && data.remainText.length > 0
      ? `剩余 ${data.remainText}`
      : '';
    await WidgetGlance.pushFormData(formId, data);
  }

  static async pushFormData(formId: string, data: WidgetGlanceData): Promise<void> {
    if (!formId) {
      return;
    }
    try {
      const binding = formBindingData.createFormBindingData(WidgetGlance.bindingPayload(data));
      await formProvider.updateForm(formId, binding);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'updateForm %{public}s failed %{public}s', formId, JSON.stringify(e));
    }
  }

  private static async fillFromPrefAsync(
    data: WidgetGlanceData,
    pref: preferences.Preferences
  ): Promise<void> {
    data.todayCount = Math.max(0, Math.floor(Number(await pref.get(TODAY_COUNT_KEY, 0) ?? 0)));
    data.remainText = String(await pref.get(REMAIN_TEXT_KEY, '') ?? '');
    data.running = Boolean(await pref.get(RUNNING_KEY, false) ?? false);
    data.brandTitle = String(await pref.get(BRAND_KEY, '如厕计时器') ?? '如厕计时器');
    data.countLine = String(await pref.get(COUNT_LINE_KEY, '') ?? '');
    data.remainLine = String(await pref.get(REMAIN_LINE_KEY, '') ?? '');
    data.tapOpen = String(await pref.get(TAP_OPEN_KEY, '轻触打开') ?? '轻触打开');
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
