import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { SharedCatalog, SceneItem, SceneGroup } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { HistoryStore } from '../common/HistoryStore';
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
  @StorageLink('appLocale') @Watch('onLocaleLink') linkedLocale: string = 'zh-CN';
  @State groups: SceneGroup[] = [];
  @State scenes: SceneItem[] = [];
  @State localeCodes: string[] = [];
  @State dialKey: string = '1';
  @State privacyAccepted: boolean = false;
  @State privacyReady: boolean = false;
  @State privacyChecked: boolean = false;
  @State currentTab: number = 1;
  @State recordsEpoch: number = 0;
  @State localeTick: number = 0;

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private history: HistoryStore = new HistoryStore();
  private state: TimerState = new TimerState();
  private tickId: number = -1;
  private finishedHandled: boolean = false;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.bootstrap();
  }

  onPageShow(): void {
    this.consumePendingCustomMin();
    this.refreshTodayStats();
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

  /** Finish alert ringtone enabled unless user chose 关闭 / mute. */
  private alertSoundOn(): boolean {
    return this.ambient !== 'off';
  }

  async bootstrap(): Promise<void> {
    if (!this.context) {
      return;
    }
    await this.prefs.init(this.context);
    await this.history.init(this.context);
    this.catalog = await SharedCatalog.load(this.context);
    this.groups = this.catalog.groups;
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
    this.linkedLocale = this.locale;
    this.localeTick = this.localeTick + 1;
    const custom = await this.prefs.getCustomMin(this.catalog.defaultMin);
    const toilet = this.scenes.find((s) => s.id === 'toilet');
    if (toilet && custom === toilet.min) {
      this.setPreset(toilet.min, 'toilet');
    } else {
      this.setPreset(custom, '');
    }
    await this.refreshTodayStats();
    this.privacyAccepted = await this.prefs.isPrivacyAccepted();
    this.privacyReady = true;
    this.ready = true;
    this.refreshUi();
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
    if (this.ambient === 'off') {
      FinishAlerter.stop();
    }
  }

  onTabChange(index: number): void {
    this.currentTab = index;
    if (index === 0) {
      this.recordsEpoch = this.recordsEpoch + 1;
    } else if (index === 1) {
      this.consumePendingCustomMin();
      this.refreshTodayStats();
    }
  }

  private async refreshTodayStats(): Promise<void> {
    const stats = await this.history.todayStats();
    this.state.statsCount = stats[0];
    this.state.statsMs = stats[1];
    if (this.ready) {
      this.refreshUi();
    }
  }

  /** Apply custom minutes chosen on Settings when returning to home. */
  private consumePendingCustomMin(): void {
    if (!this.ready || this.state.running) {
      return;
    }
    const pending = AppStorage.get<number>('pendingCustomMin');
    if (pending === undefined || pending === null || pending < 1) {
      return;
    }
    AppStorage.delete('pendingCustomMin');
    this.setPreset(pending, '');
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
      const scene = this.scenes.find((s) => s.id === this.state.activeSceneId);
      if (scene) {
        return this.t(scene.titleKey);
      }
    }
    return this.t('sceneToiletTitle');
  }

  refreshUi(): void {
    this.state.phase = phaseOf(this.state);
    this.progress = this.state.progress();
    this.clock = formatMs(this.state.remainMs);
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
      const scene = this.scenes.find((s) => s.id === this.state.activeSceneId);
      this.brandTitle = scene ? this.t(scene.titleKey) : this.t('brandTitle');
      this.sceneLabel = scene ? this.t(scene.labelKey) : this.t('scenePlaceholder');
      this.scenePlaceholder = false;
    } else {
      this.brandTitle = this.t('brandTitle');
      this.sceneLabel = this.t('scenePlaceholder');
      this.scenePlaceholder = true;
    }

    this.localeLabel = this.catalog.t(this.locale, 'nativeName');

    if (this.state.phase === 'done') {
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
  }

  setPreset(min: number, sceneId: string): void {
    if (this.state.running) {
      return;
    }
    this.finishedHandled = false;
    this.state.totalMs = Math.max(1, min) * 60 * 1000;
    this.state.remainMs = this.state.totalMs;
    this.state.finished = false;
    this.state.activeSceneId = sceneId;
    this.state.phase = 'idle';
    this.refreshUi();
  }

  selectScene(id: string): void {
    const scene = this.scenes.find((s) => s.id === id);
    if (!scene) {
      return;
    }
    this.setPreset(scene.min, scene.id);
    this.showScenes = false;
  }

  async toggleStart(): Promise<void> {
    if (this.state.finished && !this.state.running) {
      await FinishAlerter.stop();
      this.state.remainMs = this.state.totalMs;
      this.state.finished = false;
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
    await scheduleFinishReminder(
      secs,
      this.t('notifyTitle', notifyVars),
      this.t('notifyBody', notifyVars),
      this.alertSoundOn()
    );
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
    this.stopTicker();
    this.setKeepScreenOn(false);
    await FinishAlerter.stop();
    await cancelFinishReminder();
    this.finishedHandled = false;
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
    await FinishAlerter.play(this.context, this.catalog.alertDurationMs, this.alertSoundOn());
  }

  startTicker(): void {
    this.stopTicker();
    this.tickId = setInterval(() => {
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
    await this.history.recordSession(this.state.totalMs, this.state.activeSceneId);
    await this.refreshTodayStats();
    const notifyVars = this.varsNotify(String(this.sessionMinutes()), this.notifySceneName());
    const title = this.t('notifyTitle', notifyVars);
    const body = this.t('notifyBody', notifyVars);
    const ack = this.t('notifyAck');
    const withSound = this.alertSoundOn();
    // System shade/banner notification (respect mute: no custom ringtone when off).
    await showFinishNotification(title, body, withSound);
    // Guaranteed visible popup + optional alarm sound (stop tone when user acknowledges).
    const soundP = this.context
      ? FinishAlerter.play(this.context, this.catalog.alertDurationMs, withSound)
      : Promise.resolve();
    const dialogP = this.ackFinishDialog(title, body, ack);
    await Promise.all([soundP, dialogP]);
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
              this.showScenes = !this.showScenes;
            }
          })

          if (this.showScenes) {
            Scroll() {
              Column({ space: 4 }) {
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
                    .backgroundColor('#E5F5ECB8')
                    .border({ width: 1, color: '#2F9A6824' })
                    .borderRadius(8)

                    ForEach(this.scenes.filter((s) => s.group === group.id), (scene: SceneItem) => {
                      Text(this.t(scene.labelKey))
                        .width('100%')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(scene.id === this.state.activeSceneId ?
                          $r('app.color.brand_strong') : $r('app.color.muted'))
                        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                        .borderRadius(11)
                        .backgroundColor(scene.id === this.state.activeSceneId ?
                          $r('app.color.brand_soft') : Color.Transparent)
                        .onClick(() => this.selectScene(scene.id))
                    }, (scene: SceneItem) => scene.id)
                  }
                  .width('100%')
                }, (group: SceneGroup) => group.id)
              }
              .width('100%')
              .padding(6)
            }
            .height(280)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(14)
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
