import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { font, window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, '5min', 'Ability onCreate');
    // Store marketing: hdc shell aa start -a EntryAbility -b chat.5min.app
    //   --ps FIVEMIN_SCREENSHOT home|running|done
    const shot = want?.parameters?.['FIVEMIN_SCREENSHOT'];
    if (typeof shot === 'string' && shot.length > 0) {
      AppStorage.setOrCreate('FIVEMIN_SCREENSHOT', shot);
    }
    // Plus Jakarta Sans — Latin UI；缺字回退系统中日韩字体
    try {
      font.registerFont({
        familyName: 'PlusJakartaSans',
        familySrc: $rawfile('fonts/PlusJakartaSans.ttf')
      });
      font.registerFont({
        familyName: 'PlusJakartaSans-Regular',
        familySrc: $rawfile('fonts/PlusJakartaSans-Regular.ttf')
      });
      font.registerFont({
        familyName: 'PlusJakartaSans-Medium',
        familySrc: $rawfile('fonts/PlusJakartaSans-Medium.ttf')
      });
      font.registerFont({
        familyName: 'PlusJakartaSans-SemiBold',
        familySrc: $rawfile('fonts/PlusJakartaSans-SemiBold.ttf')
      });
      font.registerFont({
        familyName: 'PlusJakartaSans-Bold',
        familySrc: $rawfile('fonts/PlusJakartaSans-Bold.ttf')
      });
    } catch (e) {
      hilog.warn(0x0000, '5min', 'registerFont failed %{public}s', JSON.stringify(e));
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, '5min', 'loadContent failed %{public}s', JSON.stringify(err));
        return;
      }
      // Keep-screen-on is toggled from Index only while the timer is running (battery/perf).
    });
  }
}
