import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { SharedCatalog } from '../common/SharedCatalog';
import { PrefsStore, CustomScene, STORAGE_MODE_CLOUD, STORAGE_MODE_LOCAL } from '../common/PrefsStore';
import { HistoryStore } from '../common/HistoryStore';
import { CloudSync } from '../common/CloudSync';
import {
  RITUAL_OFF,
  RITUAL_BASIC,
  PROFILE_NORMAL,
  PROFILE_QUIET,
  PROFILE_SILENT
} from '../common/P0Features';
import { resolveLocale } from '../common/I18n';
import { APP_LOCALES, normalizeAppLocale } from '../common/AppLocales';
import { openExternalUrl } from '../common/OpenUrl';
import { AppUpdate } from '../common/AppUpdate';
import { FiveMinDimens, FiveMinFont } from '../common/FiveMinDimens';
import { HarmonyChrome, HarmonySheetHandle } from '../common/HarmonyChrome';
import { AmbientPlayer } from '../alert/AmbientPlayer';
import { i18n } from '@kit.LocalizationKit';

const PRIVACY_URL = 'https://5min.chat/privacy.html';
const TERMS_URL = 'https://5min.chat/terms.html';
const ABOUT_URL = 'https://5min.chat/about.html';
const QUICK_MINS: number[] = [3, 5, 10, 15, 25];
const SOUND_IDS: string[] = ['off', 'rain', 'waves', 'clock'];
const STORAGE_IDS: string[] = [STORAGE_MODE_LOCAL, STORAGE_MODE_CLOUD];
const RITUAL_IDS: string[] = [RITUAL_OFF, RITUAL_BASIC];
const ALERT_PROFILE_IDS: string[] = [PROFILE_NORMAL, PROFILE_QUIET, PROFILE_SILENT];

@Component
export struct MineTab {
  @StorageLink('appLocale') locale: string = 'zh-CN';
  @StorageLink('appAmbient') ambient: string = 'off';
  @StorageLink('appTabIndex') @Watch('onAppTab') appTab: number = 1;
  @State ready: boolean = false;
  @State localeCodes: string[] = [];
  @State customMin: number = 5;
  @State customScenes: CustomScene[] = [];
  @State scenesSummary: string = '';
  /** '' | lang | sound | customScenes | sceneEditor | feedback | storage | ritual | alertProfile | update */
  @State dialog: string = '';
  /** Empty string = add; otherwise edit id */
  @State editorId: string = '';
  @State editorName: string = '';
  @State editorMinutes: string = '5';
  /** Force full Mine UI refresh after locale/ambient change. */
  @State uiTick: number = 0;
  @State localeName: string = '';
  @State ambientName: string = '';
  @State finishTone: boolean = true;
  @State finishVibrate: boolean = true;
  @State finishNotify: boolean = true;
  @State showOvertimeInsight: boolean = true;
  @State standRitual: string = RITUAL_BASIC;
  @State standRitualName: string = '';
  @State alertProfile: string = PROFILE_NORMAL;
  @State alertProfileName: string = '';
  @State storageMode: string = STORAGE_MODE_LOCAL;
  @State storageModeName: string = '';
  @State storageSyncStatus: string = '';
  @State backupRevealed: boolean = false;
  @State restoreRevealed: boolean = false;
  @State backupCode: string = '';
  @State restoreCode: string = '';
  @State promptRecoveryOnce: boolean = false;
  @State appVersion: string = '—';
  @State checkingUpdate: boolean = false;
  @State pendingUpdateName: string = '';
  @State pendingUpdateUrl: string = '';

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private history: HistoryStore = new HistoryStore();
  private cloud: CloudSync | null = null;
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    // ArkTS forbids `instanceof` on namespace types; cast host Context instead.
    const host = this.getUIContext().getHostContext();
    this.context = host ? host as common.UIAbilityContext : null;
    this.bootstrap();
  }

  async bootstrap(): Promise<void> {
    if (!this.context) {
      return;
    }
    await this.prefs.init(this.context);
    await this.history.init(this.context);
    this.cloud = new CloudSync(this.prefs, this.history);
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
    this.finishTone = await this.prefs.getFinishTone();
    this.finishVibrate = await this.prefs.getFinishVibrate();
    this.finishNotify = await this.prefs.getFinishNotify();
    this.showOvertimeInsight = await this.prefs.getShowOvertimeInsight();
    AppStorage.setOrCreate('appFinishTone', this.finishTone);
    AppStorage.setOrCreate('appFinishVibrate', this.finishVibrate);
    AppStorage.setOrCreate('appFinishNotify', this.finishNotify);
    this.standRitual = await this.prefs.getStandRitual();
    this.alertProfile = await this.prefs.getAlertProfile();
    this.storageMode = await this.prefs.getStorageMode();
    this.customMin = await this.prefs.getCustomMin(this.catalog.defaultMin);
    await this.migrateLegacyCustomMinIfNeeded();
    await this.reloadCustomScenes();
    this.appVersion = AppUpdate.localVersionName();
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

  private ritualLabelOf(mode: string): string {
    return mode === RITUAL_BASIC ? this.t('standRitualBasic') : this.t('standRitualOff');
  }

  private alertProfileLabelOf(mode: string): string {
    if (mode === PROFILE_QUIET) {
      return this.t('alertProfileQuiet');
    }
    if (mode === PROFILE_SILENT) {
      return this.t('alertProfileSilent');
    }
    return this.t('alertProfileNormal');
  }

  private refreshLabels(): void {
    // Read against the current locale code explicitly so values never stick to the old pack.
    this.localeName = this.catalog.t(this.locale, 'nativeName');
    this.ambientName = this.catalog.t(this.locale, this.ambientKeyOf(this.ambient));
    this.storageModeName = this.storageMode === STORAGE_MODE_CLOUD
      ? this.catalog.t(this.locale, 'storageModeCloud')
      : this.catalog.t(this.locale, 'storageModeLocal');
    this.standRitualName = this.ritualLabelOf(this.standRitual);
    this.alertProfileName = this.alertProfileLabelOf(this.alertProfile);
    this.refreshScenesSummary();
    this.uiTick = this.uiTick + 1;
  }

  private pushPrefsIfCloud(): void {
    if (this.cloud) {
      this.cloud.schedulePushPrefs();
    }
  }

  private storageLabelOf(id: string): string {
    return id === STORAGE_MODE_CLOUD ? this.t('storageModeCloud') : this.t('storageModeLocal');
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

  onAppTab(): void {
    if (this.appTab !== 2 && this.dialog !== '') {
      this.closeDialog();
    }
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
    this.storageModeName = this.storageMode === STORAGE_MODE_CLOUD
      ? this.catalog.t(next, 'storageModeCloud')
      : this.catalog.t(next, 'storageModeLocal');
    this.standRitualName = this.ritualLabelOf(this.standRitual);
    this.alertProfileName = this.alertProfileLabelOf(this.alertProfile);
    this.refreshScenesSummary();
    this.uiTick = this.uiTick + 1;
    this.pushPrefsIfCloud();
  }

  async setAmbient(mode: string): Promise<void> {
    this.closeDialog();
    this.ambient = mode;
    AppStorage.setOrCreate('appAmbient', mode);
    await this.prefs.setAmbient(mode);
    this.ambientName = this.catalog.t(this.locale, this.ambientKeyOf(mode));
    // Start / stop procedural ambient immediately (reviewer: 选择后应有声音).
    await AmbientPlayer.setMode(mode);
    this.pushPrefsIfCloud();
  }

  async setFinishTone(on: boolean): Promise<void> {
    this.finishTone = on;
    AppStorage.setOrCreate('appFinishTone', on);
    await this.prefs.setFinishTone(on);
    this.pushPrefsIfCloud();
  }

  async setFinishVibrate(on: boolean): Promise<void> {
    this.finishVibrate = on;
    AppStorage.setOrCreate('appFinishVibrate', on);
    await this.prefs.setFinishVibrate(on);
    this.pushPrefsIfCloud();
  }

  async setFinishNotify(on: boolean): Promise<void> {
    this.finishNotify = on;
    AppStorage.setOrCreate('appFinishNotify', on);
    await this.prefs.setFinishNotify(on);
    this.pushPrefsIfCloud();
  }

  async setShowOvertimeInsight(on: boolean): Promise<void> {
    this.showOvertimeInsight = on;
    await this.prefs.setShowOvertimeInsight(on);
    this.pushPrefsIfCloud();
  }

  async setStandRitual(mode: string): Promise<void> {
    this.closeDialog();
    this.standRitual = mode === RITUAL_BASIC ? RITUAL_BASIC : RITUAL_OFF;
    await this.prefs.setStandRitual(this.standRitual);
    this.standRitualName = this.ritualLabelOf(this.standRitual);
  }

  async setAlertProfile(mode: string): Promise<void> {
    this.closeDialog();
    if (mode === PROFILE_QUIET || mode === PROFILE_SILENT) {
      this.alertProfile = mode;
    } else {
      this.alertProfile = PROFILE_NORMAL;
    }
    await this.prefs.setAlertProfile(this.alertProfile);
    this.alertProfileName = this.alertProfileLabelOf(this.alertProfile);
  }

  async pickStorageMode(mode: string): Promise<void> {
    if (mode === STORAGE_MODE_CLOUD) {
      try {
        const buttons: promptAction.Button[] = [
          { text: this.t('cancelLabel'), color: '#5F6F66' },
          { text: this.t('confirmLabel'), color: '#2F9A68' }
        ];
        const res = await this.getUIContext().getPromptAction().showDialog({
          title: this.t('storageModeCloud'),
          message: this.t('storageCloudConfirm'),
          buttons: buttons
        });
        if (res.index !== 1) {
          return;
        }
      } catch (_) {
        return;
      }
      await this.applyStorageMode(STORAGE_MODE_CLOUD);
      return;
    }
    await this.applyStorageMode(STORAGE_MODE_LOCAL);
  }

  async applyStorageMode(mode: string): Promise<void> {
    this.closeDialog();
    this.storageSyncStatus = '';
    if (!this.cloud) {
      return;
    }
    if (mode === STORAGE_MODE_CLOUD) {
      this.storageSyncStatus = this.t('storageSyncing');
      this.uiTick = this.uiTick + 1;
      this.promptRecoveryOnce = true;
      const ok = await this.cloud.enableCloud();
      if (ok) {
        this.storageMode = STORAGE_MODE_CLOUD;
        this.storageSyncStatus = this.t('storageSyncOk');
        await this.reloadFromPrefsAfterCloud();
        if (this.promptRecoveryOnce) {
          this.promptRecoveryOnce = false;
          const code = await this.prefs.formatRecoveryCode();
          if (code) {
            this.backupCode = code;
            this.backupRevealed = true;
          }
        }
      } else {
        this.promptRecoveryOnce = false;
        this.storageMode = STORAGE_MODE_LOCAL;
        this.storageSyncStatus = this.t('storageSyncFail');
      }
      this.refreshLabels();
      return;
    }
    await this.cloud.disableCloud();
    this.storageMode = STORAGE_MODE_LOCAL;
    this.storageSyncStatus = '';
    this.backupRevealed = false;
    this.restoreRevealed = false;
    this.backupCode = '';
    this.refreshLabels();
  }

  async toggleRecoveryDrawer(): Promise<void> {
    if (this.backupRevealed) {
      this.backupRevealed = false;
      this.uiTick = this.uiTick + 1;
      return;
    }
    if (!this.cloud) {
      return;
    }
    try {
      await this.cloud.ensureCredentials();
      const code = await this.prefs.formatRecoveryCode();
      const id = await this.prefs.getDeviceId();
      const secret = await this.prefs.getDeviceSecret();
      if (!code || CloudSync.isWeakDeviceCredentials(id, secret)) {
        this.getUIContext().getPromptAction().showToast({
          message: this.t('storageSyncFail'),
          duration: 2000
        });
        return;
      }
      this.backupCode = code;
      this.backupRevealed = true;
      this.uiTick = this.uiTick + 1;
    } catch (_) {
      try {
        this.getUIContext().getPromptAction().showToast({
          message: this.t('storageSyncFail'),
          duration: 2000
        });
      } catch (__) {
      }
    }
  }

  async copyRecoveryCode(): Promise<void> {
    const code = this.backupCode || await this.prefs.formatRecoveryCode();
    if (!code) {
      return;
    }
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, code);
      await systemPasteboard.setData(pasteData);
      this.getUIContext().getPromptAction().showToast({
        message: this.t('storageBackupCopied'),
        duration: 2000
      });
    } catch (_) {
    }
  }

  async restoreWithCode(): Promise<void> {
    if (!this.cloud) {
      return;
    }
    const parsed = this.prefs.parseRecoveryCode(this.restoreCode);
    if (!parsed) {
      this.storageSyncStatus = this.t('storageRestoreInvalid');
      this.uiTick = this.uiTick + 1;
      return;
    }
    this.storageSyncStatus = this.t('storageSyncing');
    this.uiTick = this.uiTick + 1;
    const err = await this.cloud.restoreWithCode(this.restoreCode);
    if (!err) {
      this.storageMode = STORAGE_MODE_CLOUD;
      this.storageSyncStatus = this.t('storageRestoreOk');
      this.restoreCode = '';
      this.backupRevealed = false;
      this.restoreRevealed = false;
      this.backupCode = '';
      await this.reloadFromPrefsAfterCloud();
    } else if (err === 'invalid') {
      this.storageSyncStatus = this.t('storageRestoreInvalid');
    } else {
      this.storageMode = STORAGE_MODE_LOCAL;
      this.storageSyncStatus = this.t('storageRestoreFail');
    }
    this.refreshLabels();
    this.uiTick = this.uiTick + 1;
  }

  /** After a successful cloud pull, refresh Mine + AppStorage from prefs. */
  private async reloadFromPrefsAfterCloud(): Promise<void> {
    const nextLocale = normalizeAppLocale(await this.prefs.getLocale(), 'zh-CN');
    this.locale = nextLocale;
    AppStorage.setOrCreate('appLocale', nextLocale);
    const amb = await this.prefs.getAmbient();
    this.ambient = amb;
    AppStorage.setOrCreate('appAmbient', amb);
    this.finishTone = await this.prefs.getFinishTone();
    this.finishVibrate = await this.prefs.getFinishVibrate();
    this.finishNotify = await this.prefs.getFinishNotify();
    this.showOvertimeInsight = await this.prefs.getShowOvertimeInsight();
    AppStorage.setOrCreate('appFinishTone', this.finishTone);
    AppStorage.setOrCreate('appFinishVibrate', this.finishVibrate);
    AppStorage.setOrCreate('appFinishNotify', this.finishNotify);
    this.customMin = await this.prefs.getCustomMin(this.catalog.defaultMin);
    await this.reloadCustomScenes();
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
    this.pushPrefsIfCloud();
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
    try {
      const result = await this.getUIContext().getPromptAction().showDialog({
        message: this.t('customSceneDeleteConfirm'),
        buttons: [
          { text: this.t('cancelLabel'), color: '#5F6F66' },
          { text: this.t('historyDelete'), color: '#D2554A' }
        ]
      });
      if (result.index !== 1) {
        return;
      }
    } catch (_) {
      return;
    }
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
      this.getUIContext().getPromptAction().showToast({ message: this.t('customApplied'), duration: 2000 });
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
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, email);
      await systemPasteboard.setData(pasteData);
      this.closeDialog();
      this.getUIContext().getPromptAction().showToast({ message: this.t('emailCopied'), duration: 2000 });
    } catch (_) {
      this.getUIContext().getPromptAction().showToast({
        message: this.t('shareFailed'),
        duration: 2000
      });
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
      await this.getUIContext().getPromptAction().showDialog({
        title: this.t('beianTitle'),
        message: this.t('beianIcp'),
        buttons: buttons
      });
    } catch (_) {
    }
  }

  async checkSoftwareUpdate(): Promise<void> {
    if (this.checkingUpdate) {
      return;
    }
    this.checkingUpdate = true;
    this.uiTick = this.uiTick + 1;
    const prompt = this.getUIContext().getPromptAction();
    try {
      prompt.showToast({ message: this.t('softwareUpdateChecking'), duration: 1500 });
    } catch (_) {
    }
    const result = await AppUpdate.check();
    this.checkingUpdate = false;
    this.uiTick = this.uiTick + 1;
    if (result.kind === 'latest') {
      try {
        prompt.showToast({ message: this.t('softwareUpdateLatest'), duration: 2000 });
      } catch (_) {
      }
      return;
    }
    if (result.kind === 'available' && result.latest) {
      this.pendingUpdateName = result.latest.versionName;
      this.pendingUpdateUrl = result.latest.pageUrl;
      this.dialog = 'update';
      return;
    }
    try {
      prompt.showToast({ message: this.t('softwareUpdateFailed'), duration: 2000 });
    } catch (_) {
    }
  }

  async confirmSoftwareUpdate(): Promise<void> {
    const url = this.pendingUpdateUrl.length > 0
      ? this.pendingUpdateUrl
      : 'https://5min.chat/download.html';
    this.closeDialog();
    this.pendingUpdateName = '';
    this.pendingUpdateUrl = '';
    if (this.context) {
      await AppUpdate.openUrl(this.context, url);
    }
  }

  private closeUpdateDialog(): void {
    this.pendingUpdateName = '';
    this.pendingUpdateUrl = '';
    this.closeDialog();
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
            .fontFamily(FiveMinFont.semiBold)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .key(`mine-title-${this.uiTick}`)
        }
        .width('100%')
        .height(FiveMinDimens.headerH)
        .padding({ left: FiveMinDimens.padX, right: FiveMinDimens.padX })
        .alignItems(VerticalAlign.Center)
        .backgroundColor(FiveMinDimens.headerBg)
        .border({ width: { bottom: 1 }, color: FiveMinDimens.headerLine })

        if (!this.ready) {
          Text('…')
            .fontColor($r('app.color.muted'))
            .margin({ top: 24 })
            .width('100%')
            .textAlign(TextAlign.Center)
        } else {
          Scroll() {
            Column({ space: FiveMinDimens.sectionGap }) {
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
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('lang'))

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('ambientLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.ambientName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('sound'))

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('customScenesLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.scenesSummary)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('customScenes'))
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .clip(true)
                .shadow({
                  radius: 8,
                  color: 'rgba(31, 42, 36, 0.04)',
                  offsetX: 0,
                  offsetY: 2
                })
              }
              .width('100%')

              Column({ space: 8 }) {
                Text(this.t('prefAlertsSection'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4 })

                Column({ space: 0 }) {
                  Row() {
                    Text(this.t('prefFinishTone'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.finishTone })
                      .selectedColor($r('app.color.brand'))
                      .onChange((on: boolean) => this.setFinishTone(on))
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('prefFinishVibrate'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.finishVibrate })
                      .selectedColor($r('app.color.brand'))
                      .onChange((on: boolean) => this.setFinishVibrate(on))
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('prefFinishNotify'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.finishNotify })
                      .selectedColor($r('app.color.brand'))
                      .onChange((on: boolean) => this.setFinishNotify(on))
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('prefOvertimeInsight'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Toggle({ type: ToggleType.Switch, isOn: this.showOvertimeInsight })
                      .selectedColor($r('app.color.brand'))
                      .onChange((on: boolean) => this.setShowOvertimeInsight(on))
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('alertProfileLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.alertProfileName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('alertProfile'))
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .clip(true)
                .shadow({
                  radius: 8,
                  color: 'rgba(31, 42, 36, 0.04)',
                  offsetX: 0,
                  offsetY: 2
                })

                Text(this.t('alertProfileHint'))
                  .fontSize(12)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4, right: 4 })
                  .lineHeight(18)
              }
              .width('100%')

              Column({ space: 8 }) {
                Text(this.t('standRitualSection'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4 })

                Column({ space: 0 }) {
                  Row() {
                    Text(this.t('standRitualLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.standRitualName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('ritual'))
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .clip(true)
                .shadow({
                  radius: 8,
                  color: 'rgba(31, 42, 36, 0.04)',
                  offsetX: 0,
                  offsetY: 2
                })
              }
              .width('100%')

              Column({ space: 8 }) {
                Text(this.t('storageSection'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4 })

                Column({ space: 0 }) {
                  Row() {
                    Text(this.t('storageModeLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.storageModeName)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openDialog('storage'))
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .clip(true)
                .shadow({
                  radius: 8,
                  color: 'rgba(31, 42, 36, 0.04)',
                  offsetX: 0,
                  offsetY: 2
                })

                Text(this.t('storageModeHint'))
                  .fontSize(12)
                  .fontColor($r('app.color.muted'))
                  .width('100%')
                  .padding({ left: 4, right: 4 })
                  .lineHeight(18)

                if (this.storageSyncStatus.length > 0) {
                  Text(this.storageSyncStatus)
                    .fontSize(12)
                    .fontColor($r('app.color.muted'))
                    .width('100%')
                    .padding({ left: 4, right: 4 })
                }

                if (this.storageMode === STORAGE_MODE_CLOUD) {
                  Column({ space: 0 }) {
                    Row() {
                      Text(this.t('storageBackupShow'))
                        .fontSize(15)
                        .fontColor($r('app.color.ink'))
                        .layoutWeight(1)
                      SymbolGlyph($r('sys.symbol.chevron_right'))
                        .fontSize(16)
                        .fontColor([$r('app.color.muted')])
                        .rotate({
                          angle: this.backupRevealed ? 90 : 0,
                        })
                        .animation({ duration: 180, curve: Curve.EaseInOut })
                    }
                    .width('100%')
                    .height(FiveMinDimens.controlH)
                    .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                    .onClick(() => this.toggleRecoveryDrawer())

                    if (this.backupRevealed && this.backupCode.length > 0) {
                      Divider().color(FiveMinDimens.cardBorder).margin({ left: FiveMinDimens.padBody })
                      Column({ space: 12 }) {
                        Text(this.backupCode)
                          .fontSize(12)
                          .fontColor($r('app.color.ink'))
                          .width('100%')
                          .lineHeight(18)
                        Text(this.t('storageBackupHint'))
                          .fontSize(12)
                          .fontColor($r('app.color.muted'))
                          .width('100%')
                          .lineHeight(18)
                        Button(this.t('storageBackupCopy'))
                          .type(ButtonType.Normal)
                          .width('100%')
                          .height(48)
                          .fontSize(15)
                          .fontWeight(FontWeight.Medium)
                          .fontColor(Color.White)
                          .backgroundColor($r('app.color.brand'))
                          .borderRadius(FiveMinDimens.radiusSm)
                          .stateEffect(true)
                          .onClick(() => this.copyRecoveryCode())
                      }
                      .width('100%')
                      .padding({
                        left: FiveMinDimens.padBody,
                        right: FiveMinDimens.padBody,
                        top: 14,
                        bottom: 16
                      })
                      .alignItems(HorizontalAlign.Start)
                    }
                  }
                  .width('100%')
                  .backgroundColor(HarmonyChrome.cardSurface)
                  .border({ width: 1, color: FiveMinDimens.cardBorder })
                  .borderRadius(FiveMinDimens.radiusCard)
                  .margin({ top: 8 })
                  .clip(true)
                }

                Column({ space: 0 }) {
                  Row() {
                    Text(this.t('storageRestoreLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .rotate({
                        angle: this.restoreRevealed ? 90 : 0,
                      })
                      .animation({ duration: 180, curve: Curve.EaseInOut })
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => {
                    this.restoreRevealed = !this.restoreRevealed;
                  })

                  if (this.restoreRevealed) {
                    Divider().color(FiveMinDimens.cardBorder).margin({ left: FiveMinDimens.padBody })
                    Column({ space: 12 }) {
                      TextInput({
                        placeholder: this.t('storageRestorePlaceholder'),
                        text: this.restoreCode
                      })
                        .height(44)
                        .fontSize(13)
                        .padding({ left: 12, right: 12 })
                        .width('100%')
                        .backgroundColor($r('app.color.bg2'))
                        .borderRadius(FiveMinDimens.radiusSm)
                        .onChange((v: string) => {
                          this.restoreCode = v;
                        })
                      Text(this.t('storageRestoreHint'))
                        .fontSize(12)
                        .fontColor($r('app.color.muted'))
                        .width('100%')
                        .lineHeight(18)
                      Button(this.t('storageRestoreAction'))
                        .type(ButtonType.Normal)
                        .width('100%')
                        .height(48)
                        .fontSize(15)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(Color.White)
                        .backgroundColor($r('app.color.brand'))
                        .borderRadius(FiveMinDimens.radiusSm)
                        .stateEffect(true)
                        .onClick(() => this.restoreWithCode())
                    }
                    .width('100%')
                    .padding({
                      left: FiveMinDimens.padBody,
                      right: FiveMinDimens.padBody,
                      top: 14,
                      bottom: 16
                    })
                    .alignItems(HorizontalAlign.Start)
                  }
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .margin({ top: 8 })
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
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openPrivacy())

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('termsLink'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openTerms())

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('aboutLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openAbout())

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('feedbackLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openFeedback())

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('beianEntry'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.openBeian())

                  Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })

                  Row() {
                    Text(this.t('softwareUpdateLabel'))
                      .fontSize(15)
                      .fontColor($r('app.color.ink'))
                      .layoutWeight(1)
                    Text(this.checkingUpdate ? '…' : this.appVersion)
                      .fontSize(14)
                      .fontColor($r('app.color.muted'))
                      .margin({ right: 6 })
                      .constraintSize({ maxWidth: '46%' })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.End)
                    SymbolGlyph($r('sys.symbol.chevron_right'))
                      .fontSize(16)
                      .fontColor([$r('app.color.muted')])
                      .flexShrink(0)
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .opacity(this.checkingUpdate ? 0.6 : 1)
                  .onClick(() => this.checkSoftwareUpdate())
                }
                .width('100%')
                .backgroundColor(HarmonyChrome.cardSurface)
                .border({ width: 1, color: FiveMinDimens.cardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
                .clip(true)
                .shadow({
                  radius: 8,
                  color: 'rgba(31, 42, 36, 0.04)',
                  offsetX: 0,
                  offsetY: 2
                })
              }
              .width('100%')
            }
            .width('100%')
            .padding({
              left: FiveMinDimens.padBody,
              right: FiveMinDimens.padBody,
              top: FiveMinDimens.padBody,
              bottom: 28
            })
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
      .linearGradient({
        angle: 180,
        colors: [[$r('app.color.bg'), 0], [$r('app.color.bg2'), 0.48], [$r('app.color.bg_bottom'), 1]]
      })

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
        .backgroundColor(FiveMinDimens.overlayDim)
        .onClick(() => {
          if (this.dialog === 'sceneEditor') {
            this.backToScenesList();
          } else {
            this.closeDialog();
          }
        })

      Column({ space: 0 }) {
        HarmonySheetHandle()

        Row() {
          Text(this.dialogTitle())
            .fontSize(18)
            .fontFamily(FiveMinFont.semiBold)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          if (this.dialog === 'customScenes') {
            Button('+')
              .type(ButtonType.Circle)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.customScenes.length >= CustomScene.MAX_COUNT ?
                $r('app.color.muted') : $r('app.color.brand_strong'))
              .backgroundColor($r('app.color.brand_soft'))
              .width(32)
              .height(32)
              .enabled(this.customScenes.length < CustomScene.MAX_COUNT)
              .opacity(this.customScenes.length >= CustomScene.MAX_COUNT ? 0.4 : 1)
              .onClick(() => this.openSceneEditor(''))
          }
          Button('✕')
            .type(ButtonType.Circle)
            .fontSize(16)
            .fontColor($r('app.color.muted'))
            .backgroundColor($r('app.color.ghost_bg'))
            .width(32)
            .height(32)
            .margin({ left: 8 })
            .onClick(() => {
              if (this.dialog === 'sceneEditor') {
                this.backToScenesList();
              } else {
                this.closeDialog();
              }
            })
        }
        .width('100%')
        .padding({ left: FiveMinDimens.padX, right: 16, top: 4, bottom: 8 })

        if (this.dialog === 'lang') {
          Scroll() {
            Column({ space: 4 }) {
              ForEach(this.localeCodes, (code: string) => {
                Row({ space: 12 }) {
                  Radio({ value: code, group: 'mine-lang' })
                    .checked(code === this.locale)
                    .radioStyle({
                      checkedBackgroundColor: $r('app.color.brand')
                    })
                    .onClick(() => this.setLocale(code))
                  Text(this.catalog.t(code, 'nativeName'))
                    .layoutWeight(1)
                    .fontSize(16)
                    .fontWeight(code === this.locale ? FontWeight.Medium : FontWeight.Regular)
                    .fontColor(code === this.locale ? $r('app.color.brand_strong') : $r('app.color.ink'))
                    .textAlign(TextAlign.Start)
                    .direction(Direction.Ltr)
                }
                .width('100%')
                .height(56)
                .padding({ left: 14, right: 14 })
                .backgroundColor(code === this.locale ? $r('app.color.brand_soft') : Color.Transparent)
                .borderRadius(FiveMinDimens.radiusSm)
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
          .constraintSize({ maxHeight: FiveMinDimens.sheetMaxH })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'sound') {
          Column({ space: 4 }) {
            ForEach(SOUND_IDS, (id: string) => {
              Row({ space: 12 }) {
                Radio({ value: id, group: 'mine-sound' })
                  .checked(id === this.ambient)
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.brand')
                  })
                  .onClick(() => this.setAmbient(id))
                Text(this.ambientLabelOf(id))
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontWeight(id === this.ambient ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(id === this.ambient ? $r('app.color.brand_strong') : $r('app.color.ink'))
                  .textAlign(TextAlign.Start)
                  .direction(Direction.Ltr)
              }
              .width('100%')
              .height(56)
              .padding({ left: 14, right: 14 })
              .backgroundColor(id === this.ambient ? $r('app.color.brand_soft') : Color.Transparent)
              .borderRadius(FiveMinDimens.radiusSm)
              .direction(Direction.Ltr)
              .onClick(() => this.setAmbient(id))
            }, (id: string) => `snd-${id}-${this.uiTick}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 28 })
          .alignItems(HorizontalAlign.Center)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'storage') {
          Column({ space: 4 }) {
            ForEach(STORAGE_IDS, (id: string) => {
              Row({ space: 12 }) {
                Radio({ value: id, group: 'mine-storage' })
                  .checked(id === this.storageMode)
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.brand')
                  })
                  .onClick(() => this.pickStorageMode(id))
                Text(this.storageLabelOf(id))
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontWeight(id === this.storageMode ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(id === this.storageMode ? $r('app.color.brand_strong') : $r('app.color.ink'))
                  .textAlign(TextAlign.Start)
                  .direction(Direction.Ltr)
              }
              .width('100%')
              .height(56)
              .padding({ left: 14, right: 14 })
              .backgroundColor(id === this.storageMode ? $r('app.color.brand_soft') : Color.Transparent)
              .borderRadius(FiveMinDimens.radiusSm)
              .direction(Direction.Ltr)
              .onClick(() => this.pickStorageMode(id))
            }, (id: string) => `storage-${id}-${this.uiTick}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 28 })
          .alignItems(HorizontalAlign.Center)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'ritual') {
          Column({ space: 4 }) {
            ForEach(RITUAL_IDS, (id: string) => {
              Row({ space: 12 }) {
                Radio({ value: id, group: 'mine-ritual' })
                  .checked(id === this.standRitual)
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.brand')
                  })
                  .onClick(() => this.setStandRitual(id))
                Text(this.ritualLabelOf(id))
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontWeight(id === this.standRitual ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(id === this.standRitual ? $r('app.color.brand_strong') : $r('app.color.ink'))
                  .textAlign(TextAlign.Start)
                  .direction(Direction.Ltr)
              }
              .width('100%')
              .height(56)
              .padding({ left: 14, right: 14 })
              .backgroundColor(id === this.standRitual ? $r('app.color.brand_soft') : Color.Transparent)
              .borderRadius(FiveMinDimens.radiusSm)
              .direction(Direction.Ltr)
              .onClick(() => this.setStandRitual(id))
            }, (id: string) => `ritual-${id}-${this.uiTick}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 28 })
          .alignItems(HorizontalAlign.Center)
          .direction(Direction.Ltr)
        } else if (this.dialog === 'alertProfile') {
          Column({ space: 4 }) {
            ForEach(ALERT_PROFILE_IDS, (id: string) => {
              Row({ space: 12 }) {
                Radio({ value: id, group: 'mine-alert' })
                  .checked(id === this.alertProfile)
                  .radioStyle({
                    checkedBackgroundColor: $r('app.color.brand')
                  })
                  .onClick(() => this.setAlertProfile(id))
                Text(this.alertProfileLabelOf(id))
                  .layoutWeight(1)
                  .fontSize(16)
                  .fontWeight(id === this.alertProfile ? FontWeight.Medium : FontWeight.Regular)
                  .fontColor(id === this.alertProfile ? $r('app.color.brand_strong') : $r('app.color.ink'))
                  .textAlign(TextAlign.Start)
                  .direction(Direction.Ltr)
              }
              .width('100%')
              .height(56)
              .padding({ left: 14, right: 14 })
              .backgroundColor(id === this.alertProfile ? $r('app.color.brand_soft') : Color.Transparent)
              .borderRadius(FiveMinDimens.radiusSm)
              .direction(Direction.Ltr)
              .onClick(() => this.setAlertProfile(id))
            }, (id: string) => `alert-profile-${id}-${this.uiTick}`)
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
            Button(this.t('copyEmailLabel'))
              .type(ButtonType.Normal)
              .width('100%')
              .height(48)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.brand'))
              .borderRadius(FiveMinDimens.radiusSm)
              .stateEffect(true)
              .onClick(() => this.copyFeedbackEmail())
          }
          .width('100%')
          .padding({ left: FiveMinDimens.padX, right: FiveMinDimens.padX, bottom: 28, top: 8 })
        } else if (this.dialog === 'update') {
          Column({ space: 16 }) {
            Text(this.updateAvailableMessage())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .lineHeight(22)
            Row({ space: 10 }) {
              Button(this.t('cancelLabel'))
                .type(ButtonType.Normal)
                .layoutWeight(1)
                .height(48)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.muted'))
                .backgroundColor($r('app.color.ghost_bg'))
                .borderRadius(FiveMinDimens.radiusSm)
                .stateEffect(true)
                .onClick(() => this.closeUpdateDialog())
              Button(this.t('softwareUpdateAction'))
                .type(ButtonType.Normal)
                .layoutWeight(1)
                .height(48)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.brand'))
                .borderRadius(FiveMinDimens.radiusSm)
                .stateEffect(true)
                .onClick(() => this.confirmSoftwareUpdate())
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: FiveMinDimens.padX, right: FiveMinDimens.padX, bottom: 28, top: 8 })
        }
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius({ topLeft: FiveMinDimens.radiusSheet, topRight: FiveMinDimens.radiusSheet })
      .shadow({
        radius: 24,
        color: 'rgba(31, 42, 36, 0.12)',
        offsetX: 0,
        offsetY: -4
      })
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
        Button(this.t('customSceneAdd'))
          .type(ButtonType.Normal)
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand'))
          .borderRadius(FiveMinDimens.radiusSm)
          .stateEffect(true)
          .onClick(() => this.openSceneEditor(''))
      }
      .width('100%')
      .padding({ left: FiveMinDimens.padX, right: FiveMinDimens.padX, bottom: 28, top: FiveMinDimens.padBody })
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

              Button(this.t('customSceneUse'))
                .type(ButtonType.Normal)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.brand_strong'))
                .backgroundColor($r('app.color.brand_soft'))
                .borderRadius(8)
                .height(32)
                .padding({ left: 10, right: 10 })
                .onClick(() => this.useCustomScene(scene.id))

              Button('✕')
                .type(ButtonType.Circle)
                .fontSize(14)
                .fontColor($r('app.color.muted'))
                .backgroundColor($r('app.color.ghost_bg'))
                .width(32)
                .height(32)
                .onClick(() => this.deleteCustomScene(scene.id))
            }
            .width('100%')
            .padding({ left: 16, right: 12, top: 12, bottom: 12 })

            Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })
          }, (scene: CustomScene) => `scene-${scene.id}-${this.uiTick}`)
        }
        .width('100%')
        .padding({ bottom: 20 })
      }
      .width('100%')
      .constraintSize({ maxHeight: FiveMinDimens.customScenesMaxH })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  SceneEditorPane() {
    Column({ space: 20 }) {
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
          .height(FiveMinDimens.fieldH)
          .fontSize(15)
          .fontColor($r('app.color.ink'))
          .padding({ left: 14, right: 14 })
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.line') })
          .borderRadius(FiveMinDimens.radiusSm)
          .maxLength(CustomScene.MAX_NAME_LENGTH)
          .onChange((v: string) => {
            this.editorName = v;
          })
      }
      .width('100%')

      Column({ space: 8 }) {
        Text(this.t('customMinutesLabel'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.muted'))
          .width('100%')

        Row({ space: 10 }) {
          Button('−')
            .type(ButtonType.Normal)
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.ghost_bg'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(FiveMinDimens.radiusSm)
            .stateEffect(true)
            .onClick(() => this.nudgeEditor(-1))

          TextInput({ text: this.editorMinutes })
            .layoutWeight(1)
            .height(FiveMinDimens.fieldH)
            .fontSize(24)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .textAlign(TextAlign.Center)
            .type(InputType.Number)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(FiveMinDimens.radiusSm)
            .onChange((v: string) => {
              this.editorMinutes = v;
            })

          Button('+')
            .type(ButtonType.Normal)
            .width(48)
            .height(48)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .backgroundColor($r('app.color.ghost_bg'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(FiveMinDimens.radiusSm)
            .stateEffect(true)
            .onClick(() => this.nudgeEditor(1))
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(QUICK_MINS, (min: number) => {
          Button(`${min}`)
            .type(ButtonType.Normal)
            .layoutWeight(1)
            .height(FiveMinDimens.rowH)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_strong'))
            .backgroundColor($r('app.color.brand_soft'))
            .borderRadius(FiveMinDimens.radiusSm)
            .stateEffect(true)
            .onClick(() => {
              this.editorMinutes = `${min}`;
            })
        }, (min: number) => `q-${min}`)
      }
      .width('100%')

      Button(this.t('confirmLabel'))
        .type(ButtonType.Normal)
        .width('100%')
        .height(FiveMinDimens.controlH)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.brand'))
        .borderRadius(FiveMinDimens.radius)
        .enabled(this.canSaveEditor())
        .opacity(this.canSaveEditor() ? 1 : 0.55)
        .stateEffect(true)
        .onClick(() => {
          if (this.canSaveEditor()) {
            this.saveSceneEditor();
          }
        })
    }
    .width('100%')
    .padding({ left: FiveMinDimens.padX, right: FiveMinDimens.padX, bottom: 28, top: 8 })
  }

  private dialogTitle(): string {
    if (this.dialog === 'lang') {
      return this.t('langLabel');
    }
    if (this.dialog === 'sound') {
      return this.t('ambientLabel');
    }
    if (this.dialog === 'storage') {
      return this.t('storageModeLabel');
    }
    if (this.dialog === 'ritual') {
      return this.t('standRitualLabel');
    }
    if (this.dialog === 'alertProfile') {
      return this.t('alertProfileLabel');
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
    if (this.dialog === 'update') {
      return this.t('softwareUpdateLabel');
    }
    return '';
  }

  private updateAvailableMessage(): string {
    const vars: Record<string, string> = {};
    vars['n'] = this.pendingUpdateName;
    return this.t('softwareUpdateAvailable', vars);
  }
}
