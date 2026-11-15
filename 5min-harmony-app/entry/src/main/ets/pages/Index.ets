import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { SharedCatalog, SceneItem, SceneGroup } from '../common/SharedCatalog';
import { PrefsStore, CustomScene } from '../common/PrefsStore';
import { HistoryStore } from '../common/HistoryStore';
import { CloudSync } from '../common/CloudSync';
import { SceneRanker, SessionRef } from '../common/SceneRanker';
import { resolveLocale } from '../common/I18n';
import { normalizeAppLocale } from '../common/AppLocales';
import { openExternalUrl } from '../common/OpenUrl';
import { TimerState, formatMs, phaseOf } from '../timer/TimerState';
import { FinishAlerter } from '../alert/FinishAlerter';
import {
  ensureNotificationPermission,
  showFinishNotification,
  showFinishDialog,
  scheduleFinishReminder,
  cancelFinishReminder
} from '../notify/FinishNotifier';
import { DigitalWatchTime } from '../ui/DigitalWatch';
import { RecordsTab } from '../ui/RecordsTab';
import { MineTab } from '../ui/MineTab';
import { i18n } from '@kit.LocalizationKit';

const PRIVACY_URL = 'https://5min.chat/privacy.html';
const TERMS_URL = 'https://5min.chat/terms.html';

@Component
struct DialRing {
  @Prop progress: number = 1;
  @Prop ringColor: string = '#2F9A68';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @Watch('onChange') @Prop syncKey: string = '';

  onChange(): void {
    this.draw();
  }

  draw(): void {
    const w = this.ctx.width;
    const h = this.ctx.height;
    if (w <= 0 || h <= 0) {
      return;
    }
    const size = Math.min(w, h);
    const stroke = size * (8.5 / 120);
    const cx = w / 2;
    const cy = h / 2;
    const r = size / 2 - stroke / 2;
    this.ctx.clearRect(0, 0, w, h);

    this.ctx.lineWidth = stroke;
    this.ctx.lineCap = 'round';

    this.ctx.strokeStyle = '#CFE0D6';
    this.ctx.beginPath();
    this.ctx.arc(cx, cy, r, 0, Math.PI * 2);
    this.ctx.stroke();

    const sweep = Math.max(0, Math.min(1, this.progress)) * Math.PI * 2;
    if (sweep > 0.001) {
      this.ctx.strokeStyle = this.ringColor;
      this.ctx.beginPath();
      // Canvas arc: 0 is 3 o'clock; Android starts at -90° (12 o'clock)
      this.ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + sweep, false);
      this.ctx.stroke();
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.draw();
      })
  }
}

@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State locale: string = 'zh-CN';
  @State localeLabel: string = '';
  @State clock: string = '05:00';
  @State status: string = '';
  @State brandTitle: string = '';
  @State statsText: string = '';
  @State statsEmpty: boolean = true;
  @State startLabel: string = '';
  @State sceneLabel: string = '';
  @State scenePlaceholder: boolean = true;
  @State progress: number = 1;
  @State ringColor: string = '#2F9A68';
  @State timeColor: string = '#1F2A24';
  @State statusColor: string = '#5F6F66';
  @State bgColor: string = '#EEF6F1';
  @State running: boolean = false;
  @State resetEnabled: boolean = false;
  @State setupEnabled: boolean = true;
  @State showScenes: boolean = false;
  @StorageLink('appAmbient') @Watch('onAmbientLink') ambient: string = 'off';
  @StorageLink('appFinishTone') finishTone: boolean = true;
  @StorageLink('appFinishVibrate') finishVibrate: boolean = true;
  @StorageLink('appFinishNotify') finishNotify: boolean = true;
  @StorageLink('appLocale') @Watch('onLocaleLink') linkedLocale: string = 'zh-CN';
  @State groups: SceneGroup[] = [];
  @State scenes: SceneItem[] = [];
  @State customScenes: CustomScene[] = [];
  @State suggestedSceneIds: string[] = [];
  @State chipSceneIds: string[] = [];
  @State localeCodes: string[] = [];
  @State dialKey: string = '1';
  @State privacyAccepted: boolean = false;
  @State privacyReady: boolean = false;
  @State privacyChecked: boolean = false;
  @State currentTab: number = 1;
  @State recordsEpoch: number = 0;
  @State localeTick: number = 0;
  @State showIgnore: boolean = false;
  @State ignoreLabel: string = '';

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private history: HistoryStore = new HistoryStore();
  private cloud: CloudSync | null = null;
  private state: TimerState = new TimerState();
  private tickId: number = -1;
  private finishedHandled: boolean = false;
  private lastRecordedSessionId: number = 0;
  private inOvertime: boolean = false;
  private overtimeMs: number = 0;
  private overtimeAt: number = 0;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.bootstrap();
  }

  onPageShow(): void {
    this.reloadCustomScenes().then(() => {
      this.consumePendingScene();
      this.refreshTodayStats();
      this.refreshSuggested();
    });
  }

  aboutToDisappear(): void {
    this.stopTicker();
    this.setKeepScreenOn(false);
    FinishAlerter.stop();
  }

  /** Only keep the screen on while countdown is running (battery / thermal). */
  private setKeepScreenOn(on: boolean): void {
    if (!this.context) {
      return;
    }
    window.getLastWindow(this.context).then((win: window.Window) => {
      win.setWindowKeepScreenOn(on);
    }).catch(() => {
    });
  }

  async bootstrap(): Promise<void> {
    if (!this.context) {
      return;
    }
    await this.prefs.init(this.context);
    await this.history.init(this.context);
    this.cloud = new CloudSync(this.prefs, this.history);
    this.catalog = await SharedCatalog.load(this.context);
    this.scenes = this.catalog.scenes;
    this.localeCodes = this.catalog.localeCodes;

    const saved = await this.prefs.getLocale();
    const systemTags: string[] = [];
    try {
      systemTags.push(i18n.System.getSystemLanguage());
    } catch (_) {
    }
    this.locale = normalizeAppLocale(resolveLocale(this.catalog, saved, systemTags), 'zh-CN');
    if (!saved || saved !== this.locale) {
      await this.prefs.setLocale(this.locale);
    }
    this.state.locale = this.locale;
    this.state.ambient = await this.prefs.getAmbient();
    this.ambient = this.state.ambient;
    AppStorage.setOrCreate('appLocale', this.locale);
    AppStorage.setOrCreate('appAmbient', this.ambient);
    this.finishTone = await this.prefs.getFinishTone();
    this.finishVibrate = await this.prefs.getFinishVibrate();
    this.finishNotify = await this.prefs.getFinishNotify();
    AppStorage.setOrCreate('appFinishTone', this.finishTone);
    AppStorage.setOrCreate('appFinishVibrate', this.finishVibrate);
    AppStorage.setOrCreate('appFinishNotify', this.finishNotify);
    this.linkedLocale = this.locale;
    this.localeTick = this.localeTick + 1;
    const custom = await this.prefs.getCustomMin(this.catalog.defaultMin);
    await this.reloadCustomScenes();
    await this.migrateLegacyCustomMinIfNeeded();
    await this.reloadCustomScenes();
    const toilet = this.scenes.find((s) => s.id === 'toilet');
    const customMatch = this.customScenes.find((s) => s.min === custom);
    if (toilet && custom === toilet.min) {
      this.setPreset(toilet.min, 'toilet');
    } else if (customMatch) {
      this.setPreset(customMatch.min, customMatch.id);
    } else {
      this.setPreset(custom, '');
    }
    await this.refreshTodayStats();
    await this.refreshSuggested();
    this.privacyAccepted = await this.prefs.isPrivacyAccepted();
    this.privacyReady = true;
    this.ready = true;
    this.refreshUi();
    await this.syncCloudOnLaunchIfNeeded();
  }

  /** Pull/push cloud snapshot when storageMode is cloud (matches Android app start). */
  private async syncCloudOnLaunchIfNeeded(): Promise<void> {
    if (!this.cloud || !(await this.cloud.isCloud())) {
      return;
    }
    CloudSync.runAsync(async () => {
      if (!this.cloud) {
        return;
      }
      await this.cloud.syncNow();
      const nextLocale = normalizeAppLocale(await this.prefs.getLocale(), 'zh-CN');
      if (nextLocale !== this.locale) {
        this.locale = nextLocale;
        this.state.locale = nextLocale;
        this.linkedLocale = nextLocale;
        AppStorage.setOrCreate('appLocale', nextLocale);
        this.localeTick = this.localeTick + 1;
      }
      const amb = await this.prefs.getAmbient();
      this.ambient = amb;
      this.state.ambient = amb;
      AppStorage.setOrCreate('appAmbient', amb);
      this.finishTone = await this.prefs.getFinishTone();
      this.finishVibrate = await this.prefs.getFinishVibrate();
      this.finishNotify = await this.prefs.getFinishNotify();
      AppStorage.setOrCreate('appFinishTone', this.finishTone);
      AppStorage.setOrCreate('appFinishVibrate', this.finishVibrate);
      AppStorage.setOrCreate('appFinishNotify', this.finishNotify);
      await this.reloadCustomScenes();
      await this.refreshTodayStats();
      await this.refreshSuggested();
      this.recordsEpoch = this.recordsEpoch + 1;
      this.refreshUi();
    });
  }

  private async reloadCustomScenes(): Promise<void> {
    this.customScenes = await this.prefs.getCustomScenes();
    await this.refreshSuggested();
    if (this.ready) {
      this.refreshUi();
    }
  }

  private async refreshSuggested(): Promise<void> {
    const known: string[] = [];
    for (let i = 0; i < this.scenes.length; i++) {
      known.push(this.scenes[i].id);
    }
    for (let i = 0; i < this.customScenes.length; i++) {
      known.push(this.customScenes[i].id);
    }
    const history = await this.history.getHistory();
    const sessions: SessionRef[] = [];
    for (let i = 0; i < history.length; i++) {
      sessions.push(new SessionRef(history[i].sceneId, history[i].at));
    }
    this.suggestedSceneIds = SceneRanker.rank(sessions, known);
    this.chipSceneIds = this.suggestedSceneIds.slice(0, SceneRanker.CHIP_N);
    this.refreshPickerGroups();
  }

  private refreshPickerGroups(): void {
    const groups: SceneGroup[] = [];
    if (this.suggestedSceneIds.length > 0) {
      const suggestedGroup: SceneGroup = {
        id: SceneRanker.GROUP_ID,
        labelKey: SceneRanker.LABEL_KEY
      };
      groups.push(suggestedGroup);
    }
    if (this.customScenes.length > 0) {
      const customGroup: SceneGroup = {
        id: CustomScene.GROUP_ID,
        labelKey: 'sceneGroupCustom'
      };
      groups.push(customGroup);
    }
    this.groups = groups.concat(this.catalog.groups);
  }

  /** One-shot: turn the old single custom duration into a named scene. */
  private async migrateLegacyCustomMinIfNeeded(): Promise<void> {
    if (await this.prefs.isCustomScenesMigrated()) {
      return;
    }
    try {
      if (this.customScenes.length > 0) {
        return;
      }
      const legacy = await this.prefs.getCustomMin(this.catalog.defaultMin);
      if (legacy === this.catalog.defaultMin) {
        return;
      }
      const scene = new CustomScene(
        CustomScene.makeId(),
        this.t('customSceneMigratedName'),
        legacy
      );
      await this.prefs.setCustomScenes([scene]);
    } finally {
      await this.prefs.markCustomScenesMigrated();
    }
  }

  onLocaleLink(): void {
    if (!this.ready) {
      return;
    }
    const next = normalizeAppLocale(this.linkedLocale, 'zh-CN');
    if (this.locale !== next) {
      this.locale = next;
      this.state.locale = next;
      this.linkedLocale = next;
      this.localeTick = this.localeTick + 1;
      this.refreshUi();
    }
  }

  onAmbientLink(): void {
    this.state.ambient = this.ambient;
  }

  onTabChange(index: number): void {
    this.currentTab = index;
    if (index === 0) {
      this.recordsEpoch = this.recordsEpoch + 1;
    } else if (index === 1) {
      this.prefs.getFinishTone().then((v) => {
        this.finishTone = v;
      });
      this.prefs.getFinishVibrate().then((v) => {
        this.finishVibrate = v;
      });
      this.prefs.getFinishNotify().then((v) => {
        this.finishNotify = v;
      });
      this.reloadCustomScenes().then(() => {
        this.consumePendingScene();
        this.refreshTodayStats();
        this.refreshSuggested();
      });
    }
  }

  private formatOvertime(ms: number): string {
    const totalSec = Math.max(0, Math.floor(ms / 1000));
    const m = Math.floor(totalSec / 60);
    const s = totalSec % 60;
    const ss = s < 10 ? `0${s}` : `${s}`;
    if (m > 0) {
      return `${m}:${ss}`;
    }
    return `0:${ss}`;
  }

  private async commitOvertimeToHistoryIfNeeded(): Promise<void> {
    if (!this.inOvertime || this.overtimeMs <= 0 || this.lastRecordedSessionId <= 0) {
      return;
    }
    const elapsed = this.state.totalMs + this.overtimeMs;
    await this.history.updateSessionElapsed(this.lastRecordedSessionId, elapsed);
    if (this.cloud) {
      this.cloud.schedulePushSessions();
    }
    this.recordsEpoch = this.recordsEpoch + 1;
    await this.refreshTodayStats();
    await this.refreshSuggested();
  }

  private clearOvertimeState(): void {
    this.inOvertime = false;
    this.overtimeMs = 0;
    this.overtimeAt = 0;
  }

  async ignoreLastSession(): Promise<void> {
    if (this.lastRecordedSessionId <= 0) {
      return;
    }
    const clientId = await this.history.deleteSession(this.lastRecordedSessionId);
    if (this.cloud && clientId) {
      this.cloud.scheduleDeleteSession(clientId);
    }
    this.lastRecordedSessionId = 0;
    this.recordsEpoch = this.recordsEpoch + 1;
    await this.refreshTodayStats();
    await this.refreshSuggested();
    await this.resetToIdleAfterFinish();
  }

  private async resetToIdleAfterFinish(): Promise<void> {
    this.stopTicker();
    this.setKeepScreenOn(false);
    await FinishAlerter.stop();
    await cancelFinishReminder();
    this.finishedHandled = false;
    this.clearOvertimeState();
    this.state.remainMs = this.state.totalMs;
    this.state.running = false;
    this.state.finished = false;
    this.state.phase = 'idle';
    this.refreshUi();
  }

  private async refreshTodayStats(): Promise<void> {
    const stats = await this.history.todayStats();
    this.state.statsCount = stats[0];
    this.state.statsMs = stats[1];
    if (this.ready) {
      this.refreshUi();
    }
  }

  /** Apply custom scene chosen in Me when returning to home. */
  private consumePendingScene(): void {
    if (!this.ready || this.state.running) {
      return;
    }
    const pending = AppStorage.get<string>('pendingSceneId');
    if (pending === undefined || pending === null || pending.length === 0) {
      return;
    }
    AppStorage.delete('pendingSceneId');
    this.selectScene(pending);
  }

  private scenesInGroup(groupId: string): SceneItem[] {
    if (groupId === SceneRanker.GROUP_ID) {
      const out: SceneItem[] = [];
      for (let i = 0; i < this.suggestedSceneIds.length; i++) {
        const item = this.sceneItemForId(this.suggestedSceneIds[i], SceneRanker.GROUP_ID);
        if (item) {
          out.push(item);
        }
      }
      return out;
    }
    if (groupId === CustomScene.GROUP_ID) {
      const out: SceneItem[] = [];
      for (let i = 0; i < this.customScenes.length; i++) {
        const custom = this.customScenes[i];
        const item: SceneItem = {
          id: custom.id,
          min: custom.min,
          group: CustomScene.GROUP_ID,
          labelKey: custom.id,
          titleKey: custom.id
        };
        out.push(item);
      }
      return out;
    }
    return this.scenes.filter((s) => s.group === groupId);
  }

  private sceneItemForId(id: string, group: string): SceneItem | null {
    const custom = this.customScenes.find((s) => s.id === id);
    if (custom) {
      const item: SceneItem = {
        id: custom.id,
        min: custom.min,
        group: group,
        labelKey: custom.id,
        titleKey: custom.id
      };
      return item;
    }
    const scene = this.scenes.find((s) => s.id === id);
    if (!scene) {
      return null;
    }
    const item: SceneItem = {
      id: scene.id,
      min: scene.min,
      group: group,
      labelKey: scene.labelKey,
      titleKey: scene.titleKey
    };
    return item;
  }

  private sceneTitle(id: string): string {
    if (!id) {
      return '';
    }
    const custom = this.customScenes.find((s) => s.id === id);
    if (custom) {
      return custom.name;
    }
    const scene = this.scenes.find((s) => s.id === id);
    return scene ? this.t(scene.titleKey) : '';
  }

  private sceneLabelText(id: string): string {
    if (!id) {
      return '';
    }
    const custom = this.customScenes.find((s) => s.id === id);
    if (custom) {
      return `${custom.name} · ${custom.min} ${this.t('customUnit')}`;
    }
    const scene = this.scenes.find((s) => s.id === id);
    return scene ? this.t(scene.labelKey) : '';
  }

  private pickerSceneLabel(scene: SceneItem): string {
    if (scene.group === CustomScene.GROUP_ID) {
      return this.sceneLabelText(scene.id);
    }
    return this.t(scene.labelKey);
  }

  async acceptPrivacy(): Promise<void> {
    await this.prefs.setPrivacyAccepted(true);
    this.privacyAccepted = true;
  }

  async declinePrivacy(): Promise<void> {
    if (this.context) {
      this.context.terminateSelf();
    }
  }

  async openPrivacy(): Promise<void> {
    if (this.context) {
      await openExternalUrl(this.context, PRIVACY_URL);
    }
  }

  async openTerms(): Promise<void> {
    if (this.context) {
      await openExternalUrl(this.context, TERMS_URL);
    }
  }


  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  /** ArkTS forbids untyped object literals; build i18n vars via typed Record. */
  private varsNotify(n: string, scene: string): Record<string, string> {
    const vars: Record<string, string> = {};
    vars['n'] = n;
    vars['scene'] = scene;
    return vars;
  }

  /** Scene title for finish notify; default system scene is toilet (如厕). */
  private notifySceneName(): string {
    if (this.state.activeSceneId) {
      const title = this.sceneTitle(this.state.activeSceneId);
      if (title) {
        return title;
      }
    }
    return this.t('sceneToiletTitle');
  }

  refreshUi(): void {
    this.state.phase = phaseOf(this.state);
    if (this.inOvertime) {
      this.progress = 0;
      this.clock = `+${this.formatOvertime(this.overtimeMs)}`;
    } else {
      this.progress = this.state.progress();
      this.clock = formatMs(this.state.remainMs);
    }
    this.running = this.state.running;
    this.setupEnabled = !this.state.running;
    this.resetEnabled = this.state.running || this.state.remainMs < this.state.totalMs || this.state.finished;
    this.dialKey = `${this.progress.toFixed(4)}|${this.state.phase}`;

    if (this.state.phase === 'warn') {
      this.ringColor = '#C9862D';
      this.timeColor = '#C9862D';
      this.statusColor = '#C9862D';
      this.bgColor = '#FFF6E8';
    } else if (this.state.phase === 'done') {
      this.ringColor = '#D2554A';
      this.timeColor = '#D2554A';
      this.statusColor = '#D2554A';
      this.bgColor = '#FFEFED';
    } else {
      this.ringColor = '#2F9A68';
      this.timeColor = '#1F2A24';
      this.statusColor = '#5F6F66';
      this.bgColor = '#EEF6F1';
    }

    if (this.state.activeSceneId) {
      const title = this.sceneTitle(this.state.activeSceneId);
      const label = this.sceneLabelText(this.state.activeSceneId);
      this.brandTitle = title.length > 0 ? title : this.t('brandTitle');
      this.sceneLabel = label.length > 0 ? label : this.t('scenePlaceholder');
      this.scenePlaceholder = label.length === 0;
    } else {
      this.brandTitle = this.t('brandTitle');
      this.sceneLabel = this.t('scenePlaceholder');
      this.scenePlaceholder = true;
    }

    this.localeLabel = this.catalog.t(this.locale, 'nativeName');

    if (this.inOvertime) {
      const otVars: Record<string, string> = {};
      otVars['n'] = this.formatOvertime(this.overtimeMs);
      this.status = this.t('statusOvertime', otVars);
    } else if (this.state.phase === 'done') {
      this.status = this.t('statusDone');
    } else if (this.state.phase === 'warn') {
      this.status = this.t('statusWarn');
    } else if (this.state.phase === 'running') {
      this.status = this.t('statusRunning');
    } else if (this.state.phase === 'paused') {
      this.status = this.t('statusPaused');
    } else {
      this.status = this.t('statusIdle');
    }

    if (this.state.finished && !this.state.running) {
      this.startLabel = this.t('again');
    } else if (this.state.running) {
      this.startLabel = this.t('pause');
    } else if (this.state.remainMs < this.state.totalMs && this.state.remainMs > 0) {
      this.startLabel = this.t('resume');
    } else {
      this.startLabel = this.t('start');
    }

    this.statsEmpty = this.state.statsCount <= 0;
    if (this.statsEmpty) {
      this.statsText = `${this.t('dailyStatsLabel')} · ${this.t('dailyStatsEmpty')}`;
    } else {
      const mins = Math.max(1, Math.ceil(this.state.statsMs / 60000));
      this.statsText =
        `${this.state.statsCount}${this.t('dailyStatsCountUnit')} · ${mins}${this.t('dailyStatsMinutesUnit')}`;
    }

    this.showIgnore = this.state.phase === 'done' && this.lastRecordedSessionId > 0;
    this.ignoreLabel = this.t('finishIgnore');
  }

  setPreset(min: number, sceneId: string): void {
    if (this.state.running) {
      return;
    }
  this.commitOvertimeToHistoryIfNeeded();
    this.clearOvertimeState();
    this.lastRecordedSessionId = 0;
    this.finishedHandled = false;
    this.state.totalMs = Math.max(1, min) * 60 * 1000;
    this.state.remainMs = this.state.totalMs;
    this.state.finished = false;
    this.state.activeSceneId = sceneId;
    this.state.phase = 'idle';
    this.refreshUi();
  }

  selectScene(id: string): void {
    const custom = this.customScenes.find((s) => s.id === id);
    if (custom) {
      this.prefs.setCustomMin(custom.min);
      this.setPreset(custom.min, custom.id);
      this.showScenes = false;
      return;
    }
    const scene = this.scenes.find((s) => s.id === id);
    if (!scene) {
      return;
    }
    this.prefs.setCustomMin(scene.min);
    this.setPreset(scene.min, scene.id);
    this.showScenes = false;
  }

  async toggleStart(): Promise<void> {
    if (this.state.finished && !this.state.running) {
      await this.commitOvertimeToHistoryIfNeeded();
      this.clearOvertimeState();
      this.lastRecordedSessionId = 0;
      await FinishAlerter.stop();
      this.state.remainMs = this.state.totalMs;
      this.state.finished = false;
      this.finishedHandled = false;
      await this.start();
      return;
    }
    if (this.state.running) {
      await this.pause();
    } else {
      await this.start();
    }
  }

  async start(): Promise<void> {
    if (this.state.remainMs <= 0) {
      return;
    }
    await FinishAlerter.stop();
    const ctx = getContext(this) as common.UIAbilityContext;
    await ensureNotificationPermission(ctx);
    this.finishedHandled = false;
    this.state.endAt = Date.now() + this.state.remainMs;
    this.state.running = true;
    this.state.finished = false;
    const secs = Math.max(1, Math.ceil(this.state.remainMs / 1000));
    const notifyVars = this.varsNotify(String(this.sessionMinutes()), this.notifySceneName());
    if (this.finishNotify) {
      await scheduleFinishReminder(
        secs,
        this.t('notifyTitle', notifyVars),
        this.t('notifyBody', notifyVars),
        this.finishTone
      );
    }
    this.startTicker();
    this.setKeepScreenOn(true);
    this.refreshUi();
  }

  async pause(): Promise<void> {
    if (!this.state.running) {
      return;
    }
    this.state.remainMs = Math.max(0, this.state.endAt - Date.now());
    this.state.running = false;
    this.stopTicker();
    this.setKeepScreenOn(false);
    await cancelFinishReminder();
    this.refreshUi();
  }

  async reset(): Promise<void> {
    await this.commitOvertimeToHistoryIfNeeded();
    this.stopTicker();
    this.setKeepScreenOn(false);
    await FinishAlerter.stop();
    await cancelFinishReminder();
    this.finishedHandled = false;
    this.clearOvertimeState();
    this.lastRecordedSessionId = 0;
    this.state.remainMs = this.state.totalMs;
    this.state.running = false;
    this.state.finished = false;
    this.state.phase = 'idle';
    this.refreshUi();
  }

  /** Re-fire finish cue from a tap (same gesture path as iOS / web). */
  async realert(): Promise<void> {
    if (!this.state.finished || !this.context) {
      return;
    }
    await FinishAlerter.stop();
    await FinishAlerter.play(
      this.context,
      this.catalog.alertDurationMs,
      this.finishTone,
      this.finishVibrate
    );
  }

  startTicker(): void {
    this.stopTicker();
    this.tickId = setInterval(() => {
      if (this.inOvertime) {
        this.overtimeMs = Math.max(0, Date.now() - this.overtimeAt);
        this.refreshUi();
        return;
      }
      if (!this.state.running) {
        return;
      }
      const remain = Math.max(0, this.state.endAt - Date.now());
      this.state.remainMs = remain;
      if (remain <= 0) {
        this.handleFinish();
        return;
      }
      this.refreshUi();
    }, 250);
  }

  stopTicker(): void {
    if (this.tickId >= 0) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
  }

  async handleFinish(): Promise<void> {
    if (this.finishedHandled) {
      return;
    }
    this.finishedHandled = true;
    this.stopTicker();
    this.setKeepScreenOn(false);
    await cancelFinishReminder();
    this.state.remainMs = 0;
    this.state.running = false;
    this.state.finished = true;
    this.lastRecordedSessionId =
      await this.history.recordSession(this.state.totalMs, this.state.activeSceneId);
    if (this.cloud) {
      this.cloud.schedulePushSessions();
    }
    this.recordsEpoch = this.recordsEpoch + 1;
    await this.refreshTodayStats();
    await this.refreshSuggested();
    this.inOvertime = true;
    this.overtimeAt = Date.now();
    this.overtimeMs = 0;
    if (this.tickId < 0) {
      this.startTicker();
    }
    const notifyVars = this.varsNotify(String(this.sessionMinutes()), this.notifySceneName());
    const title = this.t('notifyTitle', notifyVars);
    const body = this.t('notifyBody', notifyVars);
    const ack = this.t('notifyAck');
    if (this.finishNotify) {
      await showFinishNotification(title, body, this.finishTone);
    }
    const soundP = this.context
      ? FinishAlerter.play(this.context, this.catalog.alertDurationMs, this.finishTone, this.finishVibrate)
      : Promise.resolve();
    const dialogP = this.finishNotify ? this.ackFinishDialog(title, body, ack) : Promise.resolve();
    await Promise.all([soundP, dialogP]);
    this.refreshUi();
  }

  private async ackFinishDialog(title: string, body: string, ack: string): Promise<void> {
    await showFinishDialog(title, body, ack);
    await FinishAlerter.stop();
  }

  sessionMinutes(): number {
    return Math.max(1, Math.round(this.state.totalMs / 60000));
  }

  build() {
    Column() {
      if (!this.privacyReady) {
        Text('…')
          .fontSize(18)
          .fontColor($r('app.color.muted'))
      } else if (!this.privacyAccepted) {
        // First-launch privacy consent (AppGallery 7.5)
        Column() {
          Scroll() {
            Column({ space: 16 }) {
              Text(this.t('privacyTitle'))
                .fontSize(22)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .width('100%')
                .margin({ top: 8 })

              Text(this.t('privacyMessage'))
                .fontSize(14)
                .fontColor($r('app.color.ink'))
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .padding({ left: 24, right: 24, top: 28, bottom: 16 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)

          Column({ space: 16 }) {
            Row({ space: 8 }) {
              Stack({ alignContent: Alignment.Center }) {
                Column()
                  .width(18)
                  .height(18)
                  .borderRadius(4)
                  .backgroundColor(this.privacyChecked ? $r('app.color.brand') : Color.Transparent)
                  .border({
                    width: 1.5,
                    color: this.privacyChecked ? $r('app.color.brand') : '#8A9A90'
                  })
                if (this.privacyChecked) {
                  Text('✓')
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
              }
              .width(18)
              .height(18)
              .flexShrink(0)
              .onClick(() => {
                this.privacyChecked = !this.privacyChecked;
              })

              Flex({
                wrap: FlexWrap.Wrap,
                alignItems: ItemAlign.Center
              }) {
                Text(this.t('privacyCheckLabel'))
                  .fontSize(14)
                  .fontColor($r('app.color.ink'))
                  .lineHeight(20)
                  .margin({ right: 2 })
                  .onClick(() => {
                    this.privacyChecked = !this.privacyChecked;
                  })
                Text(this.t('privacyLink'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_strong'))
                  .lineHeight(20)
                  .onClick(() => this.openPrivacy())
                Text(this.t('termsLink'))
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_strong'))
                  .lineHeight(20)
                  .onClick(() => this.openTerms())
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.t('privacyAgree'))
              .width('100%')
              .height(50)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.privacyChecked ? $r('app.color.brand') : '#A8C4B4')
              .borderRadius(14)
              .opacity(this.privacyChecked ? 1 : 0.7)
              .onClick(() => {
                if (this.privacyChecked) {
                  this.acceptPrivacy();
                }
              })
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 8, bottom: 28 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      } else if (!this.ready) {
        Text('…')
          .fontSize(18)
          .fontColor($r('app.color.muted'))
      } else {
        Tabs({ barPosition: BarPosition.End, index: this.currentTab }) {
          TabContent() {
            RecordsTab({ epoch: this.recordsEpoch })
          }
          .tabBar(this.TabBarItem(0, $r('app.media.ic_tab_records'), 'tabRecords'))
          .align(Alignment.TopStart)

          TabContent() {
            this.HomePane()
          }
          .tabBar(this.TabBarItem(1, $r('app.media.ic_tab_home'), 'tabHome'))
          .align(Alignment.TopStart)

          TabContent() {
            MineTab()
          }
          .tabBar(this.TabBarItem(2, $r('app.media.ic_tab_mine'), 'tabMine'))
          .align(Alignment.TopStart)
        }
        .width('100%')
        .height('100%')
        .barHeight(58)
        .barBackgroundColor($r('app.color.surface'))
        .onChange((i: number) => this.onTabChange(i))
        .animationDuration(200)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.privacyAccepted && this.ready ? this.bgColor : $r('app.color.bg'))
  }

  @Builder
  TabBarItem(index: number, icon: Resource, labelKey: string) {
    Column({ space: 2 }) {
      Image(icon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
        .fillColor(this.currentTab === index ? '#248556' : '#5F6F66')
      Text(this.t(labelKey))
        .fontSize(11)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.currentTab === index ? $r('app.color.brand_strong') : $r('app.color.muted'))
        .key(`tab-label-${labelKey}-${this.localeTick}`)
    }
    .width('100%')
    .height(58)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  HomePane() {
    Scroll() {
      Column({ space: 20 }) {
        Row() {
          Row({ space: 10 }) {
            Image($r('app.media.logo'))
              .height(22)
              .objectFit(ImageFit.Contain)
            Text(this.brandTitle)
              .fontSize(19)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .height(36)
          .alignItems(VerticalAlign.Center)

          Image(this.ambient === 'off' ? $r('app.media.ic_volume_mute') : $r('app.media.ic_volume'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
            .fillColor(this.ambient === 'off' ? '#9AA89F' : '#5F6F66')
            .opacity(this.ambient === 'off' ? 0.85 : 0.55)
            .onClick(() => {
              this.currentTab = 2;
            })
        }
        .width('100%')
        .height(36)
        .alignItems(VerticalAlign.Center)

        Column({ space: 18 }) {
          Stack({ alignContent: Alignment.Center }) {
            DialRing({
              progress: this.progress,
              ringColor: this.ringColor,
              syncKey: this.dialKey
            })
              .width(260)
              .height(260)
            DigitalWatchTime({ text: this.clock, color: this.timeColor })
              .width(166)
              .height(55)
          }
          .width(260)
          .height(260)
          .alignSelf(ItemAlign.Center)
          .onClick(() => {
            if (this.state.finished) {
              this.realert();
            }
          })

          Column({ space: 6 }) {
            Text(this.status)
              .fontSize(14)
              .fontWeight(this.state.phase === 'done' ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.statusColor)
              .textAlign(TextAlign.Center)
              .lineHeight(21)
              .width('90%')
            if (this.statsEmpty) {
              Text(this.statsText)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.muted'))
                .textAlign(TextAlign.Center)
            } else {
              Row({ space: 6 }) {
                Text(this.t('dailyStatsLabel'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                Text('·')
                  .fontSize(12)
                  .fontColor($r('app.color.muted'))
                Text(this.statsText)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Text(this.startLabel)
              .layoutWeight(1)
              .height(52)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand'))
              .borderRadius(14)
              .onClick(() => this.toggleStart())
            Text(this.t('reset'))
              .layoutWeight(1)
              .height(52)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ghost_ink'))
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.ghost_bg'))
              .border({ width: 1, color: $r('app.color.ghost_line') })
              .borderRadius(14)
              .opacity(this.resetEnabled ? 1 : 0.4)
              .onClick(() => {
                if (this.resetEnabled) {
                  this.reset();
                }
              })
          }
          .width('100%')

          if (this.showIgnore) {
            Text(this.ignoreLabel)
              .width('100%')
              .height(44)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.muted'))
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.ghost_bg'))
              .border({ width: 1, color: $r('app.color.ghost_line') })
              .borderRadius(14)
              .onClick(() => this.ignoreLastSession())
          }

          Row() {
            Text(this.sceneLabel)
              .layoutWeight(1)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.scenePlaceholder ? $r('app.color.muted') : $r('app.color.ink'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text('▾')
              .fontSize(12)
              .fontColor(this.showScenes ? $r('app.color.brand_strong') : $r('app.color.muted'))
          }
          .width('100%')
          .height(40)
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.surface'))
          .border({
            width: 1,
            color: this.showScenes ? $r('app.color.brand') : $r('app.color.line')
          })
          .borderRadius(14)
          .opacity(this.setupEnabled ? 1 : 0.4)
          .onClick(() => {
            if (this.setupEnabled) {
              if (!this.showScenes) {
                this.reloadCustomScenes();
              }
              this.showScenes = !this.showScenes;
            }
          })

          if (this.showScenes) {
            Scroll() {
              Column({ space: 10 }) {
                ForEach(this.groups, (group: SceneGroup) => {
                  Column({ space: 2 }) {
                    Row({ space: 8 }) {
                      Column()
                        .width(3)
                        .height(12)
                        .borderRadius(2)
                        .backgroundColor($r('app.color.brand'))
                      Text(this.t(group.labelKey))
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r('app.color.brand_strong'))
                        .letterSpacing(0.8)
                    }
                    .width('100%')
                    .padding({ left: 10, right: 10, top: 7, bottom: 7 })
                    .backgroundColor($r('app.color.brand_soft'))
                    .border({ width: 1, color: $r('app.color.brand') })
                    .borderRadius(8)
                    .opacity(0.85)

                    ForEach(this.scenesInGroup(group.id), (scene: SceneItem) => {
                      Text(this.pickerSceneLabel(scene))
                        .width('100%')
                        .height(40)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(scene.id === this.state.activeSceneId ?
                          $r('app.color.brand_strong') : $r('app.color.muted'))
                        .padding({ left: 12, right: 12 })
                        .borderRadius(12)
                        .backgroundColor(scene.id === this.state.activeSceneId ?
                          $r('app.color.brand_soft') : Color.Transparent)
                        .onClick(() => this.selectScene(scene.id))
                    }, (scene: SceneItem) => scene.id)
                  }
                  .width('100%')
                }, (group: SceneGroup) => group.id)
              }
              .width('100%')
              .padding(10)
            }
            .height(280)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(14)
          }

          if (this.chipSceneIds.length > 0) {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.chipSceneIds, (id: string) => {
                  Text(this.sceneTitle(id) || id)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(id === this.state.activeSceneId ?
                      $r('app.color.brand_strong') : $r('app.color.muted'))
                    .height(40)
                    .padding({ left: 12, right: 12 })
                    .textAlign(TextAlign.Center)
                    .backgroundColor(id === this.state.activeSceneId ?
                      $r('app.color.brand_soft') : $r('app.color.surface'))
                    .border({
                      width: 1,
                      color: id === this.state.activeSceneId ? $r('app.color.brand') : $r('app.color.line')
                    })
                    .borderRadius(14)
                    .opacity(this.setupEnabled ? 1 : 0.4)
                    .onClick(() => {
                      if (this.setupEnabled) {
                        this.selectScene(id);
                      }
                    })
                }, (id: string) => id)
              }
            }
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)
            .width('100%')
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }
}
