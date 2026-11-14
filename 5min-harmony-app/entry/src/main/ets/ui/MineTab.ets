import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import pasteboard from '@ohos.pasteboard';
import { SharedCatalog } from '../common/SharedCatalog';
import { PrefsStore, CustomScene } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
import { APP_LOCALES, normalizeAppLocale } from '../common/AppLocales';
import { openExternalUrl } from '../common/OpenUrl';
import { FinishAlerter } from '../alert/FinishAlerter';
import { i18n } from '@kit.LocalizationKit';

const PRIVACY_URL = 'https://5min.chat/privacy.html';
const TERMS_URL = 'https://5min.chat/terms.html';
const ABOUT_URL = 'https://5min.chat/about.html';
const QUICK_MINS: number[] = [3, 5, 10, 15, 25];
const SOUND_IDS: string[] = ['off', 'rain', 'waves', 'clock'];

@Component
export struct MineTab {
  @StorageLink('appLocale') locale: string = 'zh-CN';
  @StorageLink('appAmbient') ambient: string = 'off';
  @State ready: boolean = false;
  @State localeCodes: string[] = [];
  @State customMin: number = 5;
  @State customScenes: CustomScene[] = [];
  @State scenesSummary: string = '';
  /** '' | lang | sound | customScenes | sceneEditor | feedback */
  @State dialog: string = '';
  /** Empty string = add; otherwise edit id */
  @State editorId: string = '';
  @State editorName: string = '';
  @State editorMinutes: string = '5';
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
    this.customMin = await this.prefs.getCustomMin(this.catalog.defaultMin);
    await this.migrateLegacyCustomMinIfNeeded();
    await this.reloadCustomScenes();
    this.refreshLabels();
    this.ready = true;
  }

  /** Same one-shot migration as Index; safe if already migrated. */
  private async migrateLegacyCustomMinIfNeeded(): Promise<void> {
    if (await this.prefs.isCustomScenesMigrated()) {
      return;
    }
    try {
      const existing = await this.prefs.getCustomScenes();
      if (existing.length > 0) {
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
    this.refreshScenesSummary();
    this.uiTick = this.uiTick + 1;
  }

  private refreshScenesSummary(): void {
    const n = this.customScenes.length;
    if (n <= 0) {
      this.scenesSummary = this.t('customScenesEmpty');
    } else {
      const vars: Record<string, string> = {};
      vars['n'] = `${n}`;
      this.scenesSummary = this.t('customScenesCount', vars);
    }
  }

  private async reloadCustomScenes(): Promise<void> {
    this.customScenes = await this.prefs.getCustomScenes();
    this.refreshScenesSummary();
  }

  closeDialog(): void {
    this.dialog = '';
    this.editorId = '';
    this.editorName = '';
  }

  openDialog(kind: string): void {
    if (kind === 'customScenes') {
      this.reloadCustomScenes();
    }
    this.dialog = kind;
  }

  private openSceneEditor(id: string): void {
    if (id.length === 0) {
      if (this.customScenes.length >= CustomScene.MAX_COUNT) {
        return;
      }
      this.editorId = '';
      this.editorName = '';
      this.editorMinutes = `${this.customMin}`;
    } else {
      const found = this.customScenes.find((s) => s.id === id);
      if (!found) {
        return;
      }
      this.editorId = found.id;
      this.editorName = found.name;
      this.editorMinutes = `${found.min}`;
    }
    this.dialog = 'sceneEditor';
  }

  private backToScenesList(): void {
    this.editorId = '';
    this.editorName = '';
    this.dialog = 'customScenes';
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
    this.refreshScenesSummary();
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
      return CustomScene.clampMinutes(this.customMin);
    }
    return CustomScene.clampMinutes(raw);
  }

  nudgeEditor(delta: number): void {
    const next = this.clampMin(this.clampMin(Number(this.editorMinutes)) + delta);
    this.editorMinutes = `${next}`;
  }

  private async persistScenes(next: CustomScene[]): Promise<void> {
    await this.prefs.setCustomScenes(next);
    this.customScenes = await this.prefs.getCustomScenes();
    this.refreshScenesSummary();
    this.uiTick = this.uiTick + 1;
  }

  async saveSceneEditor(): Promise<void> {
    const name = CustomScene.normalizedName(this.editorName);
    if (!name) {
      return;
    }
    const minutes = this.clampMin(Number(this.editorMinutes));
    const next: CustomScene[] = this.customScenes.slice();
    if (this.editorId.length > 0) {
      const idx = next.findIndex((s) => s.id === this.editorId);
      if (idx < 0) {
        return;
      }
      next[idx] = new CustomScene(this.editorId, name, minutes);
    } else {
      if (next.length >= CustomScene.MAX_COUNT) {
        return;
      }
      const saved = new CustomScene(CustomScene.makeId(), name, minutes);
      next.unshift(saved);
      AppStorage.setOrCreate<string>('pendingSceneId', saved.id);
    }
    this.customMin = minutes;
    await this.prefs.setCustomMin(minutes);
    await this.persistScenes(next);
    this.backToScenesList();
  }

  async deleteCustomScene(id: string): Promise<void> {
    const next = this.customScenes.filter((s) => s.id !== id);
    await this.persistScenes(next);
    const pending = AppStorage.get<string>('pendingSceneId');
    if (pending === id) {
      AppStorage.delete('pendingSceneId');
    }
  }

  useCustomScene(id: string): void {
    if (!this.customScenes.find((s) => s.id === id)) {
      return;
    }
    AppStorage.setOrCreate<string>('pendingSceneId', id);
    this.closeDialog();
    try {
      promptAction.showToast({ message: this.t('customApplied'), duration: 2000 });
    } catch (_) {
    }
  }

  openFeedback(): void {
    this.openDialog('feedback');
  }

  async copyFeedbackEmail(): Promise<void> {
    const email = this.t('feedbackEmail');
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createPlainTextData(email);
      await systemPasteboard.setPasteData(pasteData);
      this.closeDialog();
      promptAction.showToast({ message: this.t('emailCopied'), duration: 2000 });
    } catch (_) {
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

  async openBeian(): Promise<void> {
    try {
      const buttons: promptAction.Button[] = [
        {
          text: this.t('confirmLabel'),
          color: '#2F9A68'
        }
      ];
      await promptAction.showDialog({
        title: this.t('beianTitle'),
        message: this.t('beianIcp'),
        buttons: buttons
      });
    } catch (_) {
    }
  }

  private canSaveEditor(): boolean {
    return CustomScene.normalizedName(this.editorName).length > 0;
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
                    Text(this.t('customScenesLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.scenesSummary)
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
                  .onClick(() => this.openDialog('customScenes'))
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
        .onClick(() => {
          if (this.dialog === 'sceneEditor') {
            this.backToScenesList();
          } else {
            this.closeDialog();
          }
        })

      Column({ space: 0 }) {
        Row() {
          Text(this.dialogTitle())
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          if (this.dialog === 'customScenes') {
            Text('+')
              .fontSize(22)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.customScenes.length >= CustomScene.MAX_COUNT ?
                $r('app.color.muted') : $r('app.color.brand_strong'))
              .width(36)
              .height(36)
              .textAlign(TextAlign.Center)
              .opacity(this.customScenes.length >= CustomScene.MAX_COUNT ? 0.4 : 1)
              .onClick(() => this.openSceneEditor(''))
          }
          Text('✕')
            .fontSize(18)
            .fontColor($r('app.color.muted'))
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (this.dialog === 'sceneEditor') {
                this.backToScenesList();
              } else {
                this.closeDialog();
              }
            })
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
        } else if (this.dialog === 'customScenes') {
          this.CustomScenesPane()
        } else if (this.dialog === 'sceneEditor') {
          this.SceneEditorPane()
        } else if (this.dialog === 'feedback') {
          Column({ space: 16 }) {
            Text(this.t('feedbackBody'))
              .fontSize(14)
              .fontColor($r('app.color.muted'))
              .width('100%')
              .lineHeight(22)
            Text(this.t('feedbackEmail'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .width('100%')
            Text(this.t('copyEmailLabel'))
              .width('100%')
              .height(50)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand'))
              .borderRadius(14)
              .onClick(() => this.copyFeedbackEmail())
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

  @Builder
  CustomScenesPane() {
    if (this.customScenes.length === 0) {
      Column({ space: 12 }) {
        Text(this.t('customScenesEmptyHint'))
          .fontSize(14)
          .fontColor($r('app.color.muted'))
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 8, right: 8 })
        Text(this.t('customSceneAdd'))
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand'))
          .borderRadius(14)
          .onClick(() => this.openSceneEditor(''))
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 28, top: 16 })
    } else {
      Scroll() {
        Column({ space: 0 }) {
          ForEach(this.customScenes, (scene: CustomScene) => {
            Row({ space: 10 }) {
              Column({ space: 4 }) {
                Text(scene.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(`${scene.min} ${this.t('customUnit')}`)
                  .fontSize(13)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => this.openSceneEditor(scene.id))

              Text(this.t('customSceneUse'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.brand_strong'))
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor($r('app.color.brand_soft'))
                .borderRadius(8)
                .onClick(() => this.useCustomScene(scene.id))

              Text('✕')
                .fontSize(14)
                .fontColor($r('app.color.muted'))
                .width(28)
                .height(28)
                .textAlign(TextAlign.Center)
                .onClick(() => this.deleteCustomScene(scene.id))
            }
            .width('100%')
            .padding({ left: 16, right: 12, top: 12, bottom: 12 })

            Divider().color($r('app.color.line')).margin({ left: 16 })
          }, (scene: CustomScene) => `scene-${scene.id}-${this.uiTick}`)
        }
        .width('100%')
        .padding({ bottom: 20 })
      }
      .width('100%')
      .constraintSize({ maxHeight: 420 })
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  SceneEditorPane() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text(this.t('customSceneNameLabel'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.muted'))
          .width('100%')
        TextInput({
          text: this.editorName,
          placeholder: this.t('customSceneNamePlaceholder')
        })
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontColor($r('app.color.ink'))
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.ghost_bg'))
          .border({ width: 1, color: $r('app.color.line') })
          .borderRadius(12)
          .maxLength(CustomScene.MAX_NAME_LENGTH)
          .onChange((v: string) => {
            this.editorName = v;
          })
      }
      .width('100%')

      Text(this.t('customMinutesLabel'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
        .width('100%')

      Row() {
        Text('−')
          .width(48)
          .height(48)
          .fontSize(26)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_strong'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand_soft'))
          .borderRadius(24)
          .onClick(() => this.nudgeEditor(-1))

        Column({ space: 2 }) {
          TextInput({ text: this.editorMinutes })
            .width(96)
            .height(48)
            .fontSize(28)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .textAlign(TextAlign.Center)
            .type(InputType.Number)
            .backgroundColor(Color.Transparent)
            .onChange((v: string) => {
              this.editorMinutes = v;
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
          .backgroundColor($r('app.color.brand_soft'))
          .borderRadius(24)
          .onClick(() => this.nudgeEditor(1))
      }
      .width('100%')
      .height(56)
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.SpaceBetween)

      Row({ space: 8 }) {
        ForEach(QUICK_MINS, (min: number) => {
          Text(`${min}`)
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_strong'))
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.brand_soft'))
            .borderRadius(10)
            .onClick(() => {
              this.editorMinutes = `${min}`;
            })
        }, (min: number) => `q-${min}`)
      }
      .width('100%')

      Text(this.t('confirmLabel'))
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand'))
        .borderRadius(14)
        .opacity(this.canSaveEditor() ? 1 : 0.55)
        .onClick(() => {
          if (this.canSaveEditor()) {
            this.saveSceneEditor();
          }
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 28, top: 8 })
  }

  private dialogTitle(): string {
    if (this.dialog === 'lang') {
      return this.t('langLabel');
    }
    if (this.dialog === 'sound') {
      return this.t('ambientLabel');
    }
    if (this.dialog === 'customScenes') {
      return this.t('customScenesLabel');
    }
    if (this.dialog === 'sceneEditor') {
      return this.editorId.length > 0 ? this.t('customSceneEdit') : this.t('customSceneAdd');
    }
    if (this.dialog === 'feedback') {
      return this.t('feedbackLabel');
    }
    return '';
  }
}
