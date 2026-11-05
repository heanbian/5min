import { common, Want, wantAgent, WantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = '5minNotify';
const FINISH_NOTIF_ID = 3001;
const BUNDLE = 'chat.5min.app';
const ABILITY = 'EntryAbility';

let scheduledReminderId: number = -1;

/** Request system notification authorization (must run after UI loaded). */
export async function ensureNotificationPermission(context: common.UIAbilityContext): Promise<boolean> {
  try {
    const enabled = await notificationManager.isNotificationEnabled();
    if (enabled) {
      return true;
    }
    await notificationManager.requestEnableNotification(context);
    return await notificationManager.isNotificationEnabled();
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `ensureNotificationPermission: ${err.code} ${err.message}`);
    return false;
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

/** Immediate system notification when countdown ends (foreground / process alive). */
export async function showFinishNotification(title: string, body: string): Promise<void> {
  try {
    try {
      await notificationManager.addSlot(notificationManager.SlotType.SERVICE_INFORMATION);
    } catch (_) {
    }
    const agent = await buildWantAgent();
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
    await notificationManager.publish(request);
  } catch (e) {
    const err = e as BusinessError;
    hilog.warn(0x0000, TAG, `publish failed: ${err.code} ${err.message}`);
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
