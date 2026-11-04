import { common } from '@kit.AbilityKit';
import { SharedCatalog, SceneItem, SceneGroup } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
import { TimerState, formatMs, phaseOf } from '../timer/TimerState';
import { FinishAlerter } from '../alert/FinishAlerter';
import { showFinishNotification } from '../notify/FinishNotifier';
import { i18n } from '@kit.LocalizationKit';

@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State locale: string = 'zh-CN';
  @State clock: string = '5:00';
  @State status: string = '';
  @State brandTitle: string = '';
  @State statsText: string = '';
  @State startLabel: string = '';
  @State sceneLabel: string = '';
  @State progress: number = 1;
  @State phaseColor: string = '#2F9A68';
  @State running: boolean = false;
  @State showScenes: boolean = false;
  @State showLang: boolean = false;
  @State presets: number[] = [3, 5, 10];
  @State groups: SceneGroup[] = [];
  @State scenes: SceneItem[] = [];
  @State localeCodes: string[] = [];
  @State footnote: string = '';

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

  refreshUi(): void {
    this.state.phase = phaseOf(this.state);
    this.progress = this.state.progress();
    this.clock = formatMs(this.state.remainMs);
    this.running = this.state.running;
    this.phaseColor = this.state.phase === 'warn' ? '#C9862D' :
      (this.state.phase === 'done' ? '#D2554A' : '#2F9A68');

    if (this.state.activeSceneId) {
      const scene = this.scenes.find((s) => s.id === this.state.activeSceneId);
      this.brandTitle = scene ? this.t(scene.titleKey) : this.t('brandTitle');
      this.sceneLabel = scene ? this.t(scene.labelKey) : this.t('scenePlaceholder');
    } else {
      this.brandTitle = this.t('brandTitle');
      this.sceneLabel = this.t('scenePlaceholder');
    }

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

    if (this.state.statsCount <= 0) {
      this.statsText = `${this.t('dailyStatsLabel')} · ${this.t('dailyStatsEmpty')}`;
    } else {
      const mins = Math.max(1, Math.ceil(this.state.statsMs / 60000));
      this.statsText =
        `${this.t('dailyStatsLabel')} · ${this.state.statsCount}${this.t('dailyStatsCountUnit')} · ${mins}${this.t('dailyStatsMinutesUnit')}`;
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

  toggleStart(): void {
    if (this.state.finished && !this.state.running) {
      this.state.remainMs = this.state.totalMs;
      this.state.finished = false;
      this.start();
      return;
    }
    if (this.state.running) {
      this.pause();
    } else {
      this.start();
    }
  }

  start(): void {
    if (this.state.remainMs <= 0) {
      return;
    }
    this.finishedHandled = false;
    this.state.endAt = Date.now() + this.state.remainMs;
    this.state.running = true;
    this.state.finished = false;
    this.startTicker();
    this.refreshUi();
  }

  pause(): void {
    if (!this.state.running) {
      return;
    }
    this.state.remainMs = Math.max(0, this.state.endAt - Date.now());
    this.state.running = false;
    this.stopTicker();
    this.refreshUi();
  }

  reset(): void {
    this.stopTicker();
    this.finishedHandled = false;
    this.state.remainMs = this.state.totalMs;
    this.state.running = false;
    this.state.finished = false;
    this.state.phase = 'idle';
    this.refreshUi();
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
    this.state.remainMs = 0;
    this.state.running = false;
    this.state.finished = true;
    await this.prefs.recordSession(this.state.totalMs);
    const stats = await this.prefs.todayStats();
    this.state.statsCount = stats[0];
    this.state.statsMs = stats[1];
    this.refreshUi();
    await showFinishNotification(this.t('notifyTitle'), this.t('notifyBody'));
    await FinishAlerter.play(this.catalog.alertDurationMs);
  }

  async setLocale(code: string): Promise<void> {
    this.locale = code;
    this.state.locale = code;
    await this.prefs.setLocale(code);
    this.showLang = false;
    this.refreshUi();
  }

  build() {
    Column() {
      if (!this.ready) {
        Text('…')
          .fontSize(18)
          .fontColor($r('app.color.muted'))
      } else {
        Row() {
          Text(this.brandTitle)
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button(this.t('langLabel'))
            .height(36)
            .fontSize(13)
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.muted'))
            .onClick(() => {
              this.showLang = !this.showLang;
            })
        }
        .width('100%')

        if (this.showLang) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.localeCodes, (code: string) => {
              Button(this.catalog.t(code, 'nativeName'))
                .height(36)
                .margin({ right: 8, bottom: 8 })
                .backgroundColor(code === this.locale ? $r('app.color.brand_soft') : Color.White)
                .fontColor($r('app.color.brand_strong'))
                .onClick(() => {
                  this.setLocale(code);
                })
            }, (code: string) => code)
          }
          .width('100%')
        }

        Text(this.statsText)
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .margin({ top: 8, bottom: 8 })

        Stack() {
          Progress({ value: this.progress * 100, total: 100, type: ProgressType.Ring })
            .width(240)
            .height(240)
            .color(this.phaseColor)
            .style({ strokeWidth: 14 })
          Text(this.clock)
            .fontSize(48)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.phaseColor)
        }
        .margin({ top: 12, bottom: 12 })

        Text(this.status)
          .fontSize(15)
          .fontColor($r('app.color.ink'))
          .textAlign(TextAlign.Center)
          .padding({ left: 8, right: 8 })

        Row({ space: 12 }) {
          Button(this.startLabel)
            .layoutWeight(1)
            .height(52)
            .backgroundColor($r('app.color.brand'))
            .onClick(() => this.toggleStart())
          Button(this.t('reset'))
            .layoutWeight(1)
            .height(52)
            .backgroundColor(Color.White)
            .fontColor($r('app.color.ink'))
            .enabled(this.running || this.state.remainMs < this.state.totalMs || this.state.finished)
            .onClick(() => this.reset())
        }
        .width('100%')
        .margin({ top: 16 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.presets, (min: number) => {
            Button(this.t('minutes', { 'n': `${min}` }))
              .height(40)
              .margin({ right: 8, top: 8 })
              .enabled(!this.running)
              .backgroundColor((!this.state.activeSceneId && this.state.totalMs === min * 60000) ?
                $r('app.color.brand_soft') : Color.White)
              .fontColor($r('app.color.brand_strong'))
              .onClick(() => this.setPreset(min, ''))
          }, (min: number) => `${min}`)
        }
        .width('100%')
        .margin({ top: 8 })

        Button(this.sceneLabel)
          .width('100%')
          .height(48)
          .margin({ top: 12 })
          .enabled(!this.running)
          .backgroundColor(Color.White)
          .fontColor($r('app.color.ink'))
          .onClick(() => {
            this.showScenes = !this.showScenes;
          })

        if (this.showScenes) {
          Scroll() {
            Column() {
              ForEach(this.groups, (group: SceneGroup) => {
                Column() {
                  Text(this.t(group.labelKey))
                    .fontSize(12)
                    .fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.brand_strong'))
                    .padding({ left: 10, right: 10, top: 8, bottom: 4 })
                    .width('100%')
                    .backgroundColor($r('app.color.brand_soft'))
                  ForEach(this.scenes.filter((s) => s.group === group.id), (scene: SceneItem) => {
                    Text(this.t(scene.labelKey))
                      .fontSize(14)
                      .fontColor(scene.id === this.state.activeSceneId ?
                        $r('app.color.brand_strong') : $r('app.color.muted'))
                      .padding({ left: 12, right: 12, top: 12, bottom: 12 })
                      .width('100%')
                      .onClick(() => this.selectScene(scene.id))
                  }, (scene: SceneItem) => scene.id)
                }
                .width('100%')
              }, (group: SceneGroup) => group.id)
            }
            .width('100%')
          }
          .height(320)
          .margin({ top: 8 })
          .backgroundColor(Color.White)
          .borderRadius(12)
        }

        Text(this.footnote)
          .fontSize(12)
          .fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center)
          .margin({ top: 20, bottom: 24 })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 24, bottom: 16 })
    .backgroundColor($r('app.color.bg'))
  }

}
