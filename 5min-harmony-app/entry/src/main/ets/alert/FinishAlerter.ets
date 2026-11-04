import { vibrator } from '@kit.SensorServiceKit';

/** ~5s vibration + short haptic pulses (sound via system notification channel). */
export class FinishAlerter {
  static async play(durationMs: number = 5000): Promise<void> {
    const end = Date.now() + durationMs;
    while (Date.now() < end) {
      try {
        await vibrator.startVibration({
          type: 'time',
          duration: 450
        }, {
          id: 0,
          usage: 'alarm'
        });
      } catch (_) {
      }
      await FinishAlerter.sleep(150);
      try {
        await vibrator.stopVibration();
      } catch (_) {
      }
      await FinishAlerter.sleep(150);
    }
    try {
      await vibrator.stopVibration();
    } catch (_) {
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
