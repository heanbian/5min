import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData, formInfo } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WidgetGlance } from '../common/WidgetGlance';

const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'EntryFormAbility';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = EntryFormAbility.formIdOf(want);
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onAddForm %{public}s', formId);
    if (formId) {
      WidgetGlance.registerForm(this.context, formId).catch(() => {
      });
    }
    const initial = WidgetGlance.readSync(this.context);
    return formBindingData.createFormBindingData(WidgetGlance.bindingPayload(initial));
  }

  onUpdateForm(formId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onUpdateForm %{public}s', formId);
    WidgetGlance.read(this.context).then((data) => {
      return WidgetGlance.pushForm(formId, data.todayCount, data.remainText, data.running);
    }).catch((e: Error) => {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'onUpdateForm failed %{public}s', JSON.stringify(e));
    });
  }

  onRemoveForm(formId: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onRemoveForm %{public}s', formId);
    WidgetGlance.unregisterForm(this.context, formId).catch(() => {
    });
  }

  onFormEvent(formId: string, message: string): void {
    hilog.info(LOG_DOMAIN, LOG_TAG, 'onFormEvent %{public}s %{public}s', formId, message);
  }

  private static formIdOf(want: Want): string {
    try {
      const params = want.parameters;
      if (!params) {
        return '';
      }
      const raw = params[formInfo.FormParam.IDENTITY_KEY];
      return raw !== undefined && raw !== null ? `${raw}` : '';
    } catch (_) {
      return '';
    }
  }
}
