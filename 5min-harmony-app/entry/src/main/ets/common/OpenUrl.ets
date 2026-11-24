import { common, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppUpdate } from './AppUpdate';

const TAG = '5minOpenUrl';

/** Open an allowlisted https URL in the system browser. */
export async function openExternalUrl(
  context: common.UIAbilityContext,
  url: string
): Promise<void> {
  const target = AppUpdate.trustedHttpsUrl(url ? url.trim() : '');
  if (!target) {
    hilog.warn(0x0000, TAG, 'openExternalUrl blocked untrusted url');
    return;
  }
  try {
    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: target
    };
    await context.startAbility(want);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `openExternalUrl: ${err.code} ${err.message}`);
  }
}
