import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '5minOpenUrl';

/** Open an https URL in the system browser. Non-https schemes are rejected. */
export async function openExternalUrl(
  context: common.UIAbilityContext,
  url: string
): Promise<void> {
  const trimmed = url ? url.trim() : '';
  if (!trimmed.toLowerCase().startsWith('https://')) {
    hilog.warn(0x0000, TAG, 'openExternalUrl blocked non-https url');
    return;
  }
  try {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: trimmed
    };
    await context.startAbility(want);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `openExternalUrl: ${err.code} ${err.message}`);
  }
}
