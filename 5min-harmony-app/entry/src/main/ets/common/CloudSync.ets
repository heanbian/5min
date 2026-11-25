/**
 * Device-bound cloud sync against https://5min.chat/api/v1/storage
 */
import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { PrefsStore, CustomScene, STORAGE_MODE_CLOUD, STORAGE_MODE_LOCAL } from './PrefsStore';
import { HistoryStore, SyncSession } from './HistoryStore';

const API_BASE = 'https://5min.chat/api/v1/storage';
const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'CloudSync';

export class CloudSync {
  private prefs: PrefsStore;
  private history: HistoryStore;

  constructor(prefs: PrefsStore, history: HistoryStore) {
    this.prefs = prefs;
    this.history = history;
  }

  async isCloud(): Promise<boolean> {
    return (await this.prefs.getStorageMode()) === STORAGE_MODE_CLOUD;
  }

  async ensureCredentials(): Promise<[string, string]> {
    let deviceId = await this.prefs.getDeviceId();
    let deviceSecret = await this.prefs.getDeviceSecret();
    if (!deviceId || !deviceSecret) {
      deviceId = util.generateRandomUUID().toLowerCase();
      deviceSecret =
        util.generateRandomUUID().replace(/-/g, '') +
        util.generateRandomUUID().replace(/-/g, '');
      await this.prefs.setDeviceCredentials(deviceId, deviceSecret);
    }
    return [deviceId, deviceSecret];
  }

  schedulePushPrefs(): void {
    CloudSync.runAsync(async () => {
      await this.pushPrefsOnly();
    });
  }

  schedulePushSessions(): void {
    CloudSync.runAsync(async () => {
      await this.pushSessionsOnly();
    });
  }

  scheduleDeleteSession(clientId: string): void {
    CloudSync.runAsync(async () => {
      await this.deleteRemoteSession(clientId);
    });
  }

  scheduleClearSessions(): void {
    CloudSync.runAsync(async () => {
      await this.clearRemoteSessions();
    });
  }

  async enableCloud(): Promise<boolean> {
    await this.prefs.setStorageMode(STORAGE_MODE_CLOUD);
    try {
      await this.syncNow();
      return true;
    } catch (e) {
      await this.prefs.setStorageMode(STORAGE_MODE_LOCAL);
      await this.prefs.clearDeviceCredentials();
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'enableCloud failed %{public}s', JSON.stringify(e));
      return false;
    }
  }

  async disableCloud(): Promise<void> {
    await this.prefs.setStorageMode(STORAGE_MODE_LOCAL);
    await this.prefs.clearDeviceCredentials();
  }

  /**
   * Restore from user-held recovery code, then sync.
   * @returns null on success, 'invalid' / 'fail' on error.
   */
  async restoreWithCode(code: string): Promise<string | null> {
    const parsed = this.prefs.parseRecoveryCode(code);
    if (!parsed) {
      return 'invalid';
    }
    await this.prefs.setDeviceCredentials(parsed.deviceId, parsed.deviceSecret);
    await this.prefs.setStorageMode(STORAGE_MODE_CLOUD);
    try {
      await this.syncNow();
      return null;
    } catch (_) {
      await this.prefs.setStorageMode(STORAGE_MODE_LOCAL);
      await this.prefs.clearDeviceCredentials();
      return 'fail';
    }
  }

  async syncNow(): Promise<void> {
    await this.register();
    await this.request('PUT', '/snapshot', await this.snapshotBody());
    const snap = await this.request('GET', '/snapshot', null);
    await this.applyRemotePrefs(this.asObject(snap['prefs']));
    await this.applyRemoteSessions(snap['sessions']);
  }

  async pushPrefsOnly(): Promise<void> {
    if (!(await this.isCloud())) {
      return;
    }
    await this.register();
    const body: Record<string, Object> = {};
    body['prefs'] = await this.prefsPayload();
    await this.request('PUT', '/prefs', body);
  }

  async pushSessionsOnly(): Promise<void> {
    if (!(await this.isCloud())) {
      return;
    }
    await this.register();
    const body: Record<string, Object> = {};
    body['sessions'] = await this.sessionsPayload();
    await this.request('PUT', '/sessions', body);
  }

  async deleteRemoteSession(clientId: string): Promise<void> {
    if (!(await this.isCloud()) || !clientId) {
      return;
    }
    await this.register();
    await this.request('DELETE', `/sessions/${encodeURIComponent(clientId)}`, null);
  }

  async clearRemoteSessions(): Promise<void> {
    if (!(await this.isCloud())) {
      return;
    }
    await this.register();
    const body: Record<string, Object> = {};
    await this.request('POST', '/sessions/clear', body);
  }

  private async register(): Promise<void> {
    await this.ensureCredentials();
    // Auth via X-Device-Id / X-Device-Secret headers only (no secret in JSON body).
    const body: Record<string, Object> = {};
    await this.request('POST', '/register', body);
  }

  private async snapshotBody(): Promise<Record<string, Object>> {
    const body: Record<string, Object> = {};
    body['prefs'] = await this.prefsPayload();
    body['sessions'] = await this.sessionsPayload();
    return body;
  }

  private async prefsPayload(): Promise<Record<string, Object>> {
    const scenes = await this.prefs.getCustomScenes();
    const scenesArr: Record<string, string | number>[] = [];
    for (let i = 0; i < scenes.length; i++) {
      const row: Record<string, string | number> = {};
      row['id'] = scenes[i].id;
      row['name'] = scenes[i].name;
      row['min'] = scenes[i].min;
      scenesArr.push(row);
    }
    const raw: Record<string, string | number | boolean | Object> = {};
    raw['locale'] = await this.prefs.getLocale();
    raw['ambient'] = await this.prefs.getAmbient();
    raw['storageMode'] = await this.prefs.getStorageMode();
    raw['finishTone'] = await this.prefs.getFinishTone();
    raw['finishVibrate'] = await this.prefs.getFinishVibrate();
    raw['finishNotify'] = await this.prefs.getFinishNotify();
    raw['standRitual'] = await this.prefs.getStandRitual();
    raw['alertProfile'] = await this.prefs.getAlertProfile();
    raw['overtimeInsight'] = await this.prefs.getShowOvertimeInsight();
    raw['customMin'] = await this.prefs.getCustomMin(5);
    raw['customScenes'] = scenesArr;
    return JSON.parse(JSON.stringify(raw)) as Record<string, Object>;
  }

  private async sessionsPayload(): Promise<Object> {
    const rows = await this.history.exportForSync();
    const arr: Record<string, string | number>[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row: Record<string, string | number> = {};
      row['clientId'] = rows[i].clientId;
      row['at'] = rows[i].at;
      row['minutes'] = rows[i].minutes;
      row['sceneId'] = rows[i].sceneId;
      row['elapsedMs'] = rows[i].elapsedMs;
      arr.push(row);
    }
    return JSON.parse(JSON.stringify(arr)) as Object;
  }

  private async applyRemotePrefs(remote: Record<string, Object> | null): Promise<void> {
    if (!remote) {
      return;
    }
    const locale = String(remote['locale'] ?? '');
    if (locale.length > 0) {
      await this.prefs.setLocale(locale);
    }
    const ambient = String(remote['ambient'] ?? '');
    if (ambient.length > 0) {
      await this.prefs.setAmbient(ambient);
    }
    if (remote['finishTone'] !== undefined && remote['finishTone'] !== null) {
      await this.prefs.setFinishTone(Boolean(remote['finishTone']));
    }
    if (remote['finishVibrate'] !== undefined && remote['finishVibrate'] !== null) {
      await this.prefs.setFinishVibrate(Boolean(remote['finishVibrate']));
    }
    if (remote['finishNotify'] !== undefined && remote['finishNotify'] !== null) {
      await this.prefs.setFinishNotify(Boolean(remote['finishNotify']));
    }
    const ritual = String(remote['standRitual'] ?? '');
    if (ritual === 'off' || ritual === 'basic') {
      await this.prefs.setStandRitual(ritual);
    }
    const profile = String(remote['alertProfile'] ?? '');
    if (profile === 'normal' || profile === 'quiet' || profile === 'silent') {
      await this.prefs.setAlertProfile(profile);
    }
    if (remote['overtimeInsight'] !== undefined && remote['overtimeInsight'] !== null) {
      await this.prefs.setShowOvertimeInsight(Boolean(remote['overtimeInsight']));
    }
    if (remote['customMin'] !== undefined && remote['customMin'] !== null) {
      await this.prefs.setCustomMin(Number(remote['customMin']));
    }
    const scenesRaw = remote['customScenes'];
    if (!Array.isArray(scenesRaw)) {
      return;
    }
    const list = scenesRaw as Record<string, Object>[];
    const scenes: CustomScene[] = [];
    for (let i = 0; i < list.length && scenes.length < CustomScene.MAX_COUNT; i++) {
      const item = list[i];
      if (!item) {
        continue;
      }
      const name = CustomScene.normalizedName(String(item['name'] ?? ''));
      if (!name) {
        continue;
      }
      const idRaw = String(item['id'] ?? '');
      scenes.push(new CustomScene(
        idRaw.length > 0 ? idRaw : CustomScene.makeId(),
        name,
        CustomScene.clampMinutes(Number(item['min'] ?? 5))
      ));
    }
    await this.prefs.setCustomScenes(scenes);
    // Keep local storageMode as source of truth for this device setting.
  }

  /** Cap remote session merge to avoid DoS / RDB blow-up (≈ HISTORY_DAYS × busy day). */
  private static readonly MAX_REMOTE_SESSIONS: number = 500;
  private static readonly MAX_CLIENT_ID_LEN: number = 64;
  private static readonly MAX_SCENE_ID_LEN: number = 64;

  private async applyRemoteSessions(raw: Object | null | undefined): Promise<void> {
    if (!raw || !Array.isArray(raw)) {
      return;
    }
    const list = raw as Record<string, Object>[];
    const rows: SyncSession[] = [];
    const limit = Math.min(list.length, CloudSync.MAX_REMOTE_SESSIONS);
    for (let i = 0; i < limit; i++) {
      const o = list[i];
      if (!o) {
        continue;
      }
      let clientId = String(o['clientId'] ?? '');
      if (!clientId) {
        clientId = String(o['id'] ?? '');
      }
      if (clientId.length > CloudSync.MAX_CLIENT_ID_LEN) {
        clientId = clientId.substring(0, CloudSync.MAX_CLIENT_ID_LEN);
      }
      const at = Math.floor(Number(o['at'] ?? 0));
      const minutes = Math.floor(Number(o['minutes'] ?? 0));
      if (!clientId || at <= 0 || minutes <= 0) {
        continue;
      }
      let sceneId = String(o['sceneId'] ?? '');
      if (sceneId.length > CloudSync.MAX_SCENE_ID_LEN) {
        sceneId = sceneId.substring(0, CloudSync.MAX_SCENE_ID_LEN);
      }
      rows.push(new SyncSession(
        clientId,
        at,
        minutes,
        sceneId,
        Math.max(0, Math.floor(Number(o['elapsedMs'] ?? 0)))
      ));
    }
    await this.history.mergeFromCloud(rows);
  }

  private asObject(value: Object | null | undefined): Record<string, Object> | null {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return null;
    }
    return value as Record<string, Object>;
  }

  private async request(
    method: string,
    path: string,
    body: Record<string, Object> | null
  ): Promise<Record<string, Object>> {
    const creds = await this.ensureCredentials();
    const client = http.createHttp();
    try {
      const options: http.HttpRequestOptions = {
        method: CloudSync.httpMethod(method),
        header: {
          'Content-Type': 'application/json',
          'X-Device-Id': creds[0],
          'X-Device-Secret': creds[1]
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 12000,
        readTimeout: 15000
      };
      if (body !== null && method !== 'GET' && method !== 'DELETE') {
        options.extraData = JSON.stringify(body);
      }
      const response = await client.request(API_BASE + path, options);
      const code = response.responseCode;
      const text = typeof response.result === 'string' ? response.result as string : '';
      let parsed: Record<string, Object> = {};
      if (text.length > 0) {
        parsed = JSON.parse(text) as Record<string, Object>;
      }
      const success = Boolean(parsed['success']);
      if (code < 200 || code >= 300 || !success) {
        const message = String(parsed['message'] ?? `HTTP ${code}`);
        throw new Error(message);
      }
      const data = parsed['data'];
      if (data && typeof data === 'object' && !Array.isArray(data)) {
        return data as Record<string, Object>;
      }
      const empty: Record<string, Object> = {};
      return empty;
    } finally {
      client.destroy();
    }
  }

  private static httpMethod(method: string): http.RequestMethod {
    if (method === 'POST') {
      return http.RequestMethod.POST;
    }
    if (method === 'PUT') {
      return http.RequestMethod.PUT;
    }
    if (method === 'DELETE') {
      return http.RequestMethod.DELETE;
    }
    return http.RequestMethod.GET;
  }

  static runAsync(block: () => Promise<void>): void {
    block().catch((e: Error) => {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'async failed %{public}s', JSON.stringify(e));
    });
  }
}
