import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '5minNotify';
const FINISH_NOTIF_ID = 3001;
const BUNDLE = 'chat.5min.app';
const ABILITY = 'EntryAbility';
/** rawfile name — used as notification / reminder custom ringtone. */
const ALERT_RAW = 'alert.wav';

let scheduledReminderId: number = -1;
/** Avoid reopening banner settings on every Start in the same process. */
let bannerGuidedThisProcess: boolean = false;

/** Request system notification authorization (must run after UI loaded). */
export async function ensureNotificationPermission(context: common.UIAbilityContext): Promise<boolean> {
  try {
    let enabled = await notificationManager.isNotificationEnabled();
    if (!enabled) {
      await notificationManager.requestEnableNotification(context);
      enabled = await notificationManager.isNotificationEnabled();
    }
    if (!enabled) {
      return false;
    }
    // HarmonyOS: "Allow notifications" leaves banner OFF by default; apps cannot
    // force-enable it. Guide once so finish can show a system banner popup.
    await ensureBannerEnabled(context);
    return true;
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `ensureNotificationPermission: ${err.code} ${err.message}`);
    return false;
  }
}

async function ensureBannerEnabled(context: common.UIAbilityContext): Promise<void> {
  if (bannerGuidedThisProcess) {
    return;
  }
  try {
    const setting = await notificationManager.getNotificationSetting();
    if (setting.bannerEnabled === true) {
      return;
    }
    bannerGuidedThisProcess = true;
    hilog.info(0x0000, TAG, 'banner disabled — opening notification settings');
    await notificationManager.openNotificationSettingsWithResult(context);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `ensureBannerEnabled: ${err.code} ${err.message}`);
  }
}

async function buildWantAgent(): Promise<WantAgent | undefined> {
  try {
    const want: Want = {
      deviceId: '',
      bundleName: BUNDLE,
      abilityName: ABILITY
    };
    const info: wantAgent.WantAgentInfo = {
      wants: [want],
      operationType: wantAgent.OperationType.START_ABILITY,
      requestCode: FINISH_NOTIF_ID,
      wantAgentFlags: [wantAgent.WantAgentFlags.CONSTANT_FLAG]
    };
    return await wantAgent.getWantAgent(info);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `getWantAgent failed: ${err.code}`);
    return undefined;
  }
}

function buildRequest(
  title: string,
  body: string,
  agent: WantAgent | undefined,
  withSound: boolean
): notificationManager.NotificationRequest {
  const request: notificationManager.NotificationRequest = {
    id: FINISH_NOTIF_ID,
    notificationSlotType: notificationManager.SlotType.SERVICE_INFORMATION,
    content: {
      notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
      normal: {
        title: title,
        text: body
      }
    },
    wantAgent: agent,
    deliveryTime: Date.now(),
    tapDismissed: true,
    isAlertOnce: false
  };
  if (withSound) {
    request.sound = ALERT_RAW;
  }
  return request;
}

/** Immediate system notification when countdown ends (foreground / process alive). */
export async function showFinishNotification(title: string, body: string): Promise<void> {
  try {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    } catch (_) {
    }
    const agent = await buildWantAgent();
    try {
      await notificationManager.publish(buildRequest(title, body, agent, true));
      hilog.info(0x0000, TAG, 'publish ok (with sound)');
      return;
    } catch (e1) {
      const err1 = e1 as BusinessError;
      hilog.warn(0x0000, TAG, `publish+sound failed: ${err1.code} ${err1.message}`);
    }
    // Retry without custom sound — some devices reject invalid sound paths.
    await notificationManager.publish(buildRequest(title, body, agent, false));
    hilog.info(0x0000, TAG, 'publish ok (no custom sound)');
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `publish failed: ${err.code} ${err.message}`);
  }
}

/**
 * In-app finish popup. System banner is off by default on HarmonyOS and cannot
 * be force-enabled by the app; this guarantees a visible dialog at finish.
 */
export async function showFinishDialog(title: string, body: string, ack: string): Promise<void> {
  try {
    const buttons: promptAction.Button[] = [
      {
        text: ack,
        color: '#2F9A68'
      }
    ];
    await promptAction.showDialog({
      title: title,
      message: body,
      buttons: buttons
    });
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `showDialog failed: ${err.code} ${err.message}`);
  }
}

/**
 * Schedule an agent-powered timer reminder so the system can notify even if the
 * app is backgrounded / frozen. Requires ohos.permission.PUBLISH_AGENT_REMINDER
 * and notification authorization. Falls back silently if unavailable.
 */
export async function scheduleFinishReminder(
  seconds: number,
  title: string,
  body: string
): Promise<void> {
  await cancelFinishReminder();
  const secs = Math.max(1, Math.floor(seconds));
  try {
    const reminder: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: secs,
      title: title,
      content: body,
      expiredContent: body,
      notificationId: FINISH_NOTIF_ID,
      slotType: notificationManager.SlotType.SERVICE_INFORMATION,
      wantAgent: {
        pkgName: BUNDLE,
        abilityName: ABILITY
      },
      ringDuration: 5,
      customRingUri: ALERT_RAW,
      tapDismissed: true
    };
    scheduledReminderId = await reminderAgentManager.publishReminder(reminder);
    hilog.info(0x0000, TAG, `reminder scheduled id=${scheduledReminderId} in ${secs}s`);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `publishReminder failed: ${err.code} ${err.message}`);
    scheduledReminderId = -1;
  }
}

export async function cancelFinishReminder(): Promise<void> {
  if (scheduledReminderId < 0) {
    return;
  }
  const id = scheduledReminderId;
  scheduledReminderId = -1;
  try {
    await reminderAgentManager.cancelReminder(id);
  } catch (_) {
  }
}
