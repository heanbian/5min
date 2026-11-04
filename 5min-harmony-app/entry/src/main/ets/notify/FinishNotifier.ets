import { notificationManager } from '@kit.NotificationKit';

export async function showFinishNotification(title: string, body: string): Promise<void> {
  try {
    const request: notificationManager.NotificationRequest = {
      id: 3001,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body
        }
      }
    };
    await notificationManager.publish(request);
  } catch (_) {
  }
}
