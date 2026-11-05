import { common } from '@kit.AbilityKit';
import { SharedCatalog, SceneItem, SceneGroup } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
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
import { i18n } from '@kit.LocalizationKit';

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
  @State showLang: boolean = false;
  @State showAmbient: boolean = false;
  @State ambient: string = 'off';
  @State presets: number[] = [3, 5, 10];
  @State groups: SceneGroup[] = [];
  @State scenes: SceneItem[] = [];
  @State localeCodes: string[] = [];
  @State footnote: string = '';
  @State dialKey: string = '1';

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private state: TimerState = new TimerState();
  private tickId: number = -1;
  private finishedHandled: boolean = false;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.bootstrap();
  }

  aboutToDisappear(): void {
    this.stopTicker();
    FinishAlerter.stop();
  }

  async bootstrap(): Promise<void> {
    if (!this.context) {
      return;
    }
    await this.prefs.init(this.context);
    this.catalog = await SharedCatalog.load(this.context);
    this.presets = this.catalog.presetsMin;
    this.groups = this.catalog.groups;
    this.scenes = this.catalog.scenes;
    this.localeCodes = this.catalog.localeCodes;

    const saved = await this.prefs.getLocale();
    const systemTags: string[] = [];
    try {
      systemTags.push(i18n.System.getSystemLanguage());
    } catch (_) {
    }
    this.locale = resolveLocale(this.catalog, saved, systemTags);
    if (!saved) {
      await this.prefs.setLocale(this.locale);
    }
    this.state.locale = this.locale;
    this.state.ambient = await this.prefs.getAmbient();
    this.ambient = this.state.ambient;
    const total = this.catalog.defaultMin * 60 * 1000;
    this.state.totalMs = total;
    this.state.remainMs = total;
    const stats = await this.prefs.todayStats();
    this.state.statsCount = stats[0];
    this.state.statsMs = stats[1];
    this.ready = true;
    this.refreshUi();
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  /** ArkTS forbids untyped object literals; build i18n vars via typed Record. */
  private varsN(n: string): Record<string, string> {
    const vars: Record<string, string> = {};
    vars['n'] = n;
    return vars;
  }

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
    this.footnote = this.t('footnote');
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
      this.t('notifyBody', notifyVars)
    );
    this.startTicker();
    this.refreshUi();
  }

  async pause(): Promise<void> {
    if (!this.state.running) {
      return;
    }
    this.state.remainMs = Math.max(0, this.state.endAt - Date.now());
    this.state.running = false;
    this.stopTicker();
    await cancelFinishReminder();
    this.refreshUi();
  }

  async reset(): Promise<void> {
    this.stopTicker();
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
    await FinishAlerter.play(this.context, this.catalog.alertDurationMs);
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
    await cancelFinishReminder();
    this.state.remainMs = 0;
    this.state.running = false;
    this.state.finished = true;
    await this.prefs.recordSession(this.state.totalMs);
    const stats = await this.prefs.todayStats();
    this.state.statsCount = stats[0];
    this.state.statsMs = stats[1];
    this.refreshUi();
    const notifyVars = this.varsNotify(String(this.sessionMinutes()), this.notifySceneName());
    const title = this.t('notifyTitle', notifyVars);
    const body = this.t('notifyBody', notifyVars);
    const ack = this.t('notifyAck');
    // System shade/banner notification (banner needs user toggle; often off by default).
    await showFinishNotification(title, body);
    // Guaranteed visible popup + alarm sound (do not await dialog before sound).
    const soundP = this.context
      ? FinishAlerter.play(this.context, this.catalog.alertDurationMs)
      : Promise.resolve();
    const dialogP = showFinishDialog(title, body, ack);
    await Promise.all([soundP, dialogP]);
  }

  sessionMinutes(): number {
    return Math.max(1, Math.round(this.state.totalMs / 60000));
  }

  async setLocale(code: string): Promise<void> {
    this.locale = code;
    this.state.locale = code;
    await this.prefs.setLocale(code);
    this.showLang = false;
    this.refreshUi();
  }

  async setAmbient(mode: string): Promise<void> {
    this.ambient = mode;
    this.state.ambient = mode;
    await this.prefs.setAmbient(mode);
    this.showAmbient = false;
  }

  presetActive(min: number): boolean {
    return !this.state.activeSceneId && this.state.totalMs === min * 60000;
  }

  ambientLabelOf(id: string): string {
    if (id === 'rain') {
      return this.t('ambientRain');
    }
    if (id === 'waves') {
      return this.t('ambientWaves');
    }
    if (id === 'clock') {
      return this.t('ambientClock');
    }
    return this.t('ambientOff');
  }

  build() {
    Column() {
      if (!this.ready) {
        Text('…')
          .fontSize(18)
          .fontColor($r('app.color.muted'))
      } else {
        Scroll() {
          Column({ space: 20 }) {
            // —— topbar ——
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

              Row({ space: 4 }) {
                // Ambient — match Android VolumeUp 20dp in 36dp hit area
                Row() {
                  Image($r('app.media.ic_volume'))
                    .width(20)
                    .height(20)
                    .objectFit(ImageFit.Contain)
                    .fillColor(this.showAmbient ? '#248556' : '#5F6F66')
                }
                .width(36)
                .height(36)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.showAmbient = !this.showAmbient;
                  this.showLang = false;
                })

                // Language — match Android: native name + expand caret
                Row({ space: 6 }) {
                  Text(this.localeLabel)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.showLang ? $r('app.color.brand_strong') : $r('app.color.muted'))
                    .maxLines(1)
                  Image($r('app.media.ic_expand'))
                    .width(12)
                    .height(12)
                    .objectFit(ImageFit.Contain)
                    .fillColor(this.showLang ? '#248556' : '#5F6F66')
                }
                .height(36)
                .padding({ left: 6, right: 2 })
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  this.showLang = !this.showLang;
                  this.showAmbient = false;
                })
              }
              .height(36)
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .height(36)

            if (this.showAmbient) {
              Column({ space: 2 }) {
                ForEach(['off', 'rain', 'waves', 'clock'], (id: string) => {
                  Text(this.ambientLabelOf(id))
                    .width('100%')
                    .height(36)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(id === this.ambient ? $r('app.color.brand_strong') : $r('app.color.muted'))
                    .backgroundColor(id === this.ambient ? $r('app.color.brand_soft') : Color.Transparent)
                    .borderRadius(8)
                    .padding({ left: 10, right: 10 })
                    .textAlign(TextAlign.Start)
                    .onClick(() => {
                      this.setAmbient(id);
                    })
                }, (id: string) => id)
              }
              .width('100%')
              .padding(4)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.line') })
              .borderRadius(12)
            }

            if (this.showLang) {
              Column({ space: 2 }) {
                ForEach(this.localeCodes, (code: string) => {
                  Text(this.catalog.t(code, 'nativeName'))
                    .width('100%')
                    .height(36)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(code === this.locale ? $r('app.color.brand_strong') : $r('app.color.muted'))
                    .backgroundColor(code === this.locale ? $r('app.color.brand_soft') : Color.Transparent)
                    .borderRadius(8)
                    .padding({ left: 10, right: 10 })
                    .textAlign(TextAlign.Start)
                    .onClick(() => {
                      this.setLocale(code);
                    })
                }, (code: string) => code)
              }
              .width('100%')
              .padding(4)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.line') })
              .borderRadius(12)
            }

            // —— stage: dial + cue ——
            Column({ space: 18 }) {
              Stack({ alignContent: Alignment.Center }) {
                DialRing({
                  progress: this.progress,
                  ringColor: this.ringColor,
                  syncKey: this.dialKey
                })
                  .width(260)
                  .height(260)
                // Android: dial 260，时间宽 64% → 166×55（viewBox 144×48）
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

            // —— actions ——
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

              // segmented presets
              Row() {
                ForEach(this.presets, (min: number) => {
                  Text(this.t('minutes', this.varsN(`${min}`)))
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.presetActive(min) ? $r('app.color.brand_strong') : $r('app.color.muted'))
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.presetActive(min) ? $r('app.color.brand_soft') : $r('app.color.surface'))
                    .opacity(this.setupEnabled ? 1 : 0.4)
                    .onClick(() => {
                      if (this.setupEnabled) {
                        this.setPreset(min, '');
                      }
                    })
                }, (min: number) => `${min}`)
              }
              .width('100%')
              .height(40)
              .border({ width: 1, color: $r('app.color.line') })
              .borderRadius(14)
              .clip(true)
              .backgroundColor($r('app.color.surface'))

              // scene trigger
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
                        .padding({
                          left: 10,
                          right: 10,
                          top: 7,
                          bottom: 7
                        })
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
                .height(320)
                .backgroundColor($r('app.color.surface'))
                .border({ width: 1, color: $r('app.color.line') })
                .borderRadius(14)
              }
            }
            .width('100%')

            Text(this.footnote)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.muted'))
              .textAlign(TextAlign.Center)
              .lineHeight(20)
              .width('100%')
              .margin({ top: 4, bottom: 8 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 18, bottom: 16 })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }
}
