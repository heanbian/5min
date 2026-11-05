import { common } from '@kit.AbilityKit';
import { audio } from '@kit.AudioKit';
import { media } from '@kit.MediaKit';
import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '5minAlert';
/** Bundled finish cue (~5s), same pattern as web / iOS. */
const ALERT_RAW = 'alert.wav';

/**
 * Finish cue: alarm-stream WAV + vibration pulses.
 * Must not rely solely on system notification sound (often muted in foreground).
 */
export class FinishAlerter {
  private static player: media.AVPlayer | null = null;
  private static stopRequested: boolean = false;
  private static vibActive: boolean = false;

  static async play(context: common.UIAbilityContext, durationMs: number = 5000): Promise<void> {
    FinishAlerter.stopRequested = false;
    const soundP = FinishAlerter.playSound(context);
    const vibP = FinishAlerter.vibrate(durationMs);
    await Promise.all([soundP, vibP]);
  }

  /** Stop tone + vibration early (reset / leave page). */
  static async stop(): Promise<void> {
    FinishAlerter.stopRequested = true;
    FinishAlerter.vibActive = false;
    await FinishAlerter.releasePlayer();
    try {
      await vibrator.stopVibration();
    } catch (_) {
    }
  }

  private static async playSound(context: common.UIAbilityContext): Promise<void> {
    let openedRaw = false;
    try {
      await FinishAlerter.releasePlayer();
      const avPlayer = await media.createAVPlayer();
      FinishAlerter.player = avPlayer;

      await new Promise<void>((resolve) => {
        let settled = false;
        const done = (): void => {
          if (settled) {
            return;
          }
          settled = true;
          resolve();
        };

        avPlayer.on('stateChange', async (state: string) => {
          if (FinishAlerter.stopRequested) {
            done();
            return;
          }
          try {
            if (state === 'initialized') {
              avPlayer.audioRendererInfo = {
                usage: audio.StreamUsage.STREAM_USAGE_ALARM,
                rendererFlags: 0
              } as audio.AudioRendererInfo;
              await avPlayer.prepare();
            } else if (state === 'prepared') {
              await avPlayer.play();
            } else if (state === 'completed' || state === 'stopped' || state === 'error') {
              done();
            }
          } catch (e) {
            const err = e as BusinessError;
            hilog.warn(0x0000, TAG, `avPlayer state=${state}: ${err.code} ${err.message}`);
            done();
          }
        });
        avPlayer.on('error', (err: BusinessError) => {
          hilog.warn(0x0000, TAG, `avPlayer error: ${err.code} ${err.message}`);
          done();
        });

        context.resourceManager.getRawFd(ALERT_RAW).then((fd) => {
          openedRaw = true;
          if (FinishAlerter.stopRequested) {
            done();
            return;
          }
          avPlayer.fdSrc = {
            fd: fd.fd,
            offset: fd.offset,
            length: fd.length
          };
        }).catch((e: BusinessError) => {
          hilog.warn(0x0000, TAG, `getRawFd: ${e.code} ${e.message}`);
          done();
        });
      });
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0000, TAG, `playSound: ${err.code} ${err.message}`);
    } finally {
      await FinishAlerter.releasePlayer();
      if (openedRaw) {
        try {
          await context.resourceManager.closeRawFd(ALERT_RAW);
        } catch (_) {
        }
      }
    }
  }

  private static async releasePlayer(): Promise<void> {
    const p = FinishAlerter.player;
    FinishAlerter.player = null;
    if (!p) {
      return;
    }
    try {
      await p.stop();
    } catch (_) {
    }
    try {
      await p.release();
    } catch (_) {
    }
  }

  private static async vibrate(durationMs: number): Promise<void> {
    FinishAlerter.vibActive = true;
    const end = Date.now() + durationMs;
    while (FinishAlerter.vibActive && !FinishAlerter.stopRequested && Date.now() < end) {
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
    FinishAlerter.vibActive = false;
    try {
      await vibrator.stopVibration();
    } catch (_) {
    }
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}
