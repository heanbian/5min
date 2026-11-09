import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { SharedCatalog } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
import { APP_LOCALES, normalizeAppLocale } from '../common/AppLocales';
import { openExternalUrl } from '../common/OpenUrl';
import { FinishAlerter } from '../alert/FinishAlerter';
import { i18n } from '@kit.LocalizationKit';

const PRIVACY_URL = 'https://5min.chat/privacy.html';
const TERMS_URL = 'https://5min.chat/terms.html';
const FEEDBACK_URL = 'https://5min.chat/about.html';
const ABOUT_URL = 'https://5min.chat/about.html';
const QUICK_MINS: number[] = [3, 5, 10, 15, 25];
const SOUND_IDS: string[] = ['off', 'rain', 'waves', 'clock'];

@Component
export struct MineTab {
  @StorageLink('appLocale') locale: string = 'zh-CN';
  @StorageLink('appAmbient') ambient: string = 'off';
  @State ready: boolean = false;
  @State localeCodes: string[] = [];
  @State customMinText: string = '5';
  @State customMin: number = 5;
  /** '' | lang | sound | duration */
  @State dialog: string = '';
  /** Force full Mine UI refresh after locale/ambient change. */
  @State uiTick: number = 0;
  @State localeName: string = '';
  @State ambientName: string = '';

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    this.bootstrap();
  }

  async bootstrap(): Promise<void> {
    if (!this.context) {
      return;
    }
    await this.prefs.init(this.context);
    this.catalog = await SharedCatalog.load(this.context);
    this.localeCodes = APP_LOCALES.slice();
    const saved = await this.prefs.getLocale();
    const systemTags: string[] = [];
    try {
      systemTags.push(i18n.System.getSystemLanguage());
    } catch (_) {
    }
    const resolved = normalizeAppLocale(
      this.locale ? this.locale : resolveLocale(this.catalog, saved, systemTags),
      'zh-CN'
    );
    this.locale = resolved;
    if (saved !== resolved) {
      await this.prefs.setLocale(resolved);
    }
    AppStorage.setOrCreate('appLocale', resolved);
    const amb = await this.prefs.getAmbient();
    this.ambient = amb;
    AppStorage.setOrCreate('appAmbient', amb);
    const custom = await this.prefs.getCustomMin(this.catalog.defaultMin);
    this.customMin = custom;
    this.customMinText = `${custom}`;
    this.refreshLabels();
    this.ready = true;
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  private ambientKeyOf(id: string): string {
    if (id === 'rain') {
      return 'ambientRain';
    }
    if (id === 'waves') {
      return 'ambientWaves';
    }
    if (id === 'clock') {
      return 'ambientClock';
    }
    return 'ambientOff';
  }

  ambientLabelOf(id: string): string {
    return this.catalog.t(this.locale, this.ambientKeyOf(id));
  }

  private refreshLabels(): void {
    // Read against the current locale code explicitly so values never stick to the old pack.
    this.localeName = this.catalog.t(this.locale, 'nativeName');
    this.ambientName = this.catalog.t(this.locale, this.ambientKeyOf(this.ambient));
    this.uiTick = this.uiTick + 1;
  }

  closeDialog(): void {
    this.dialog = '';
  }

  openDialog(kind: string): void {
    if (kind === 'duration') {
      this.customMinText = `${this.customMin}`;
    }
    this.dialog = kind;
  }

  async setLocale(code: string): Promise<void> {
    const next = normalizeAppLocale(code, 'zh-CN');
    this.closeDialog();
    this.locale = next;
    AppStorage.setOrCreate('appLocale', next);
    await this.prefs.setLocale(next);
    // Assign display strings after locale is committed.
    this.localeName = this.catalog.t(next, 'nativeName');
    this.ambientName = this.catalog.t(next, this.ambientKeyOf(this.ambient));
    this.uiTick = this.uiTick + 1;
  }

  async setAmbient(mode: string): Promise<void> {
    this.closeDialog();
    this.ambient = mode;
    AppStorage.setOrCreate('appAmbient', mode);
    await this.prefs.setAmbient(mode);
    if (mode === 'off') {
      await FinishAlerter.stop();
    }
    this.ambientName = this.catalog.t(this.locale, this.ambientKeyOf(mode));
    this.uiTick = this.uiTick + 1;
  }

  private clampMin(raw: number): number {
    if (isNaN(raw)) {
      return this.customMin;
    }
    return Math.max(1, Math.min(120, Math.floor(raw)));
  }

  nudge(delta: number): void {
    const next = this.clampMin(this.clampMin(Number(this.customMinText)) + delta);
    this.customMinText = `${next}`;
  }

  async applyCustomMinutes(): Promise<void> {
    const min = this.clampMin(Number(this.customMinText));
    this.customMin = min;
    this.customMinText = `${min}`;
    await this.prefs.setCustomMin(min);
    AppStorage.setOrCreate<number>('pendingCustomMin', min);
    this.closeDialog();
    try {
      promptAction.showToast({ message: this.t('customApplied'), duration: 2000 });
    } catch (_) {
    }
  }

  async pickQuick(min: number): Promise<void> {
    this.customMinText = `${min}`;
    await this.applyCustomMinutes();
  }

  async openFeedback(): Promise<void> {
    if (this.context) {
      await openExternalUrl(this.context, FEEDBACK_URL);
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

  async openAbout(): Promise<void> {
    if (this.context) {
      await openExternalUrl(this.context, ABOUT_URL);
    }
  }

  openBeian(): void {
    router.pushUrl({ url: 'pages/Beian' });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Text(this.ready ? this.t('tabMine') : '…')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .key(`mine-title-${this.uiTick}`)
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor($r('app.color.surface'))
        .border({ width: { bottom: 1 }, color: $r('app.color.line') })

        if (!this.ready) {
          Text('…')
            .fontColor($r('app.color.muted'))
            .margin({ top: 24 })
            .width('100%')
            .textAlign(TextAlign.Center)
        } else {
          Scroll() {
            Column({ space: 18 }) {
              Column({ space: 8 }) {
                Text(this.t('mineSectionPrefs'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4 })

                Column({ space: 0 }) {
                  // Bind values from @State fields directly (avoid @Builder param cache).
                  Row() {
                    Text(this.t('langLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.localeName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .maxLines(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openDialog('lang'))

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('ambientLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.ambientName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .maxLines(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openDialog('sound'))

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('durationSettingsLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(`${this.customMin} ${this.t('customUnit')}`)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .maxLines(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openDialog('duration'))
                }
                .width('100%')
                .backgroundColor($r('app.color.surface'))
                .borderRadius(14)
                .clip(true)
              }
              .width('100%')

              Column({ space: 8 }) {
                Text(this.t('mineSectionSupport'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4 })

                Column({ space: 0 }) {
                  Row() {
                    Text(this.t('feedbackLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openFeedback())

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('privacyLink'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openPrivacy())

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('termsLink'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openTerms())

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('aboutLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openAbout())

                  Divider().color($r('app.color.line')).margin({ left: 16 })

                  Row() {
                    Text(this.t('beianEntry'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text('›')
                      .fontSize(18)
                      .fontColor($r('app.color.muted'))
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.openBeian())
                }
                .width('100%')
                .backgroundColor($r('app.color.surface'))
                .borderRadius(14)
                .clip(true)
              }
              .width('100%')
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 28 })
            .alignItems(HorizontalAlign.Start)
            .key(`mine-${this.uiTick}`)
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.TopStart)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor('#F2F5F3')

      if (this.dialog !== '') {
        this.DialogLayer()
      }
    }
    .width('100%')
    .height('100%')
    .key(`mine-root-${this.uiTick}`)
  }

  @Builder
  DialogLayer() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#00000066')
        .onClick(() => this.closeDialog())

      Column({ space: 0 }) {
        Row() {
          Text(this.dialogTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          Text('✕')
            .fontSize(18)
            .fontColor($r('app.color.muted'))
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => this.closeDialog())
        }
        .width('100%')
        .padding({ left: 20, right: 12, top: 16, bottom: 8 })

        if (this.dialog === 'lang') {
          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.localeCodes, (code: string) => {
                Stack({ alignContent: Alignment.Center }) {
                  Text(this.catalog.t(code, 'nativeName'))
                    .width('100%')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(code === this.locale ? $r('app.color.brand_strong') : $r('app.color.ink'))
                    .textAlign(TextAlign.Center)
                    .direction(Direction.Ltr)
                  if (code === this.locale) {
                    Text('✓')
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.brand_strong'))
                      .position({ right: 14 })
                  }
                }
                .width('100%')
                .height(48)
                .padding({ left: 14, right: 14 })
                .backgroundColor(code === this.locale ? $r('app.color.brand_soft') : Color.Transparent)
                .borderRadius(10)
                .direction(Direction.Ltr)
                .onClick(() => this.setLocale(code))
              }, (code: string) => `lang-${code}-${this.uiTick}`)
            }
            .width('100%')
            .padding({ left: 12, right: 12, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
            .direction(Direction.Ltr)
          }
          .width('100%')
          .constraintSize({ maxHeight: 360 })
          .scrollBar(BarState.Off)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'sound') {
          Column({ space: 4 }) {
            ForEach(SOUND_IDS, (id: string) => {
              Stack({ alignContent: Alignment.Center }) {
                Text(this.ambientLabelOf(id))
                  .width('100%')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(id === this.ambient ? $r('app.color.brand_strong') : $r('app.color.ink'))
                  .textAlign(TextAlign.Center)
                  .direction(Direction.Ltr)
                if (id === this.ambient) {
                  Text('✓')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand_strong'))
                    .position({ right: 14 })
                }
              }
              .width('100%')
              .height(48)
              .padding({ left: 14, right: 14 })
              .backgroundColor(id === this.ambient ? $r('app.color.brand_soft') : Color.Transparent)
              .borderRadius(10)
              .direction(Direction.Ltr)
              .onClick(() => this.setAmbient(id))
            }, (id: string) => `snd-${id}-${this.uiTick}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 28 })
          .alignItems(HorizontalAlign.Center)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'duration') {
          Column({ space: 18 }) {
            // value card
            Column({ space: 10 }) {
              Row() {
                Text('−')
                  .width(48)
                  .height(48)
                  .fontSize(26)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_strong'))
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Color.White)
                  .borderRadius(24)
                  .onClick(() => this.nudge(-1))

                Column({ space: 2 }) {
                  TextInput({ text: this.customMinText })
                    .width(96)
                    .height(48)
                    .fontSize(32)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ink'))
                    .textAlign(TextAlign.Center)
                    .type(InputType.Number)
                    .backgroundColor(Color.Transparent)
                    .onChange((v: string) => {
                      this.customMinText = v;
                    })
                  Text(this.t('customUnit'))
                    .fontSize(13)
                    .fontColor($r('app.color.muted'))
                }
                .alignItems(HorizontalAlign.Center)
                .layoutWeight(1)

                Text('+')
                  .width(48)
                  .height(48)
                  .fontSize(26)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.brand_strong'))
                  .textAlign(TextAlign.Center)
                  .backgroundColor(Color.White)
                  .borderRadius(24)
                  .onClick(() => this.nudge(1))
              }
              .width('100%')
              .height(56)
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.SpaceBetween)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 18, bottom: 16 })
            .backgroundColor($r('app.color.brand_soft'))
            .borderRadius(16)

            Column({ space: 10 }) {
              Text(this.t('customMinutesHint'))
                .fontSize(12)
                .fontColor($r('app.color.muted'))
                .width('100%')

              Row({ space: 8 }) {
                ForEach(QUICK_MINS, (min: number) => {
                  Text(`${min}`)
                    .layoutWeight(1)
                    .height(40)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Number(this.customMinText) === min ? Color.White : $r('app.color.brand_strong'))
                    .textAlign(TextAlign.Center)
                    .backgroundColor(Number(this.customMinText) === min ? $r('app.color.brand') : $r('app.color.brand_soft'))
                    .borderRadius(12)
                    .onClick(() => this.pickQuick(min))
                }, (min: number) => `d-${min}`)
              }
              .width('100%')
            }
            .width('100%')

            Text(this.t('customApply'))
              .width('100%')
              .height(50)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand'))
              .borderRadius(14)
              .onClick(() => this.applyCustomMinutes())
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 28, top: 8 })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius({ topLeft: 18, topRight: 18 })
    }
    .width('100%')
    .height('100%')
  }

  private dialogTitle(): string {
    if (this.dialog === 'lang') {
      return this.t('langLabel');
    }
    if (this.dialog === 'sound') {
      return this.t('ambientLabel');
    }
    if (this.dialog === 'duration') {
      return this.t('durationSettingsLabel');
    }
    return '';
  }
}
