import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { SharedCatalog, SceneItem } from '../common/SharedCatalog';
import { PrefsStore, CustomScene } from '../common/PrefsStore';
import { HistoryStore, HistoryItem, SyncSession, HISTORY_DAYS } from '../common/HistoryStore';
import { CloudSync } from '../common/CloudSync';
import { insightMinutes } from '../common/P0Features';
import { resolveLocale } from '../common/I18n';
import { FiveMinDimens, FiveMinFont } from '../common/FiveMinDimens';
import { i18n } from '@kit.LocalizationKit';

/** One list row: scene / duration / time on separate lines. */
class HistoryRowView {
  key: string = '';
  id: number = 0;
  sceneLine: string = '';
  durationLine: string = '';
  timeLine: string = '';
}

class FilterOption {
  id: string = '';
  label: string = '';

  constructor(id: string, label: string) {
    this.id = id;
    this.label = label;
  }
}

@Component
export struct RecordsTab {
  @StorageLink('appLocale') @Watch('onLocaleChange') locale: string = 'zh-CN';
  @StorageLink('appTabIndex') @Watch('onAppTab') appTab: number = 1;
  @Watch('onEpoch') @Prop epoch: number = 0;
  @State ready: boolean = false;
  @State historyRows: HistoryRowView[] = [];
  @State periodCount: number = 0;
  @State periodMins: number = 0;
  @State streakDays: number = 0;
  @State uiTick: number = 0;
  @State filterSceneId: string = '';
  @State filterLabel: string = '';
  @State filterOptions: FilterOption[] = [];
  @State showFilter: boolean = false;
  @State showOvertimeInsight: boolean = true;
  @State overtimeInsightLine: string = '';

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private history: HistoryStore = new HistoryStore();
  private cloud: CloudSync | null = null;
  private scenes: SceneItem[] = [];
  private customScenes: CustomScene[] = [];
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    // ArkTS forbids `instanceof` on namespace types; cast host Context instead.
    const host = this.getUIContext().getHostContext();
    this.context = host ? host as common.UIAbilityContext : null;
    this.bootstrap();
  }

  onEpoch(): void {
    if (this.ready) {
      this.reload();
    }
  }

  onAppTab(): void {
    if (this.appTab !== 0) {
      this.showFilter = false;
    }
  }

  onLocaleChange(): void {
    if (this.ready) {
      this.reload();
      this.uiTick = this.uiTick + 1;
    }
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
    if (!this.locale) {
      const saved = await this.prefs.getLocale();
      const systemTags: string[] = [];
      try {
        systemTags.push(i18n.System.getSystemLanguage());
      } catch (_) {
      }
      this.locale = resolveLocale(this.catalog, saved, systemTags);
    }
    await this.reload();
    this.ready = true;
  }

  /** Called by parent when tab becomes visible. */
  async reload(): Promise<void> {
    this.customScenes = await this.prefs.getCustomScenes();
    await this.buildFilterOptions();
    const hist = await this.history.getHistory(this.filterSceneId);
    this.historyRows = this.formatHistory(hist);
    // One history pass for period + streak (avoid 2–3 full reloads).
    const summary = await this.history.shareSummaryValues();
    this.periodCount = summary[0];
    this.periodMins = summary[1];
    this.streakDays = summary[2];
    this.filterLabel = this.currentFilterLabel();
    this.showOvertimeInsight = await this.prefs.getShowOvertimeInsight();
    const ot = await this.prefs.readOvertimeStats();
    if (ot.count > 0) {
      const vars: Record<string, string> = {};
      vars['count'] = `${ot.count}`;
      vars['mins'] = `${insightMinutes(ot.ms)}`;
      this.overtimeInsightLine = this.t('overtimeInsightLine', vars);
    } else {
      this.overtimeInsightLine = this.t('overtimeInsightEmpty');
    }
  }

  private streakLine(): string {
    if (this.streakDays > 0) {
      const vars: Record<string, string> = {};
      vars['n'] = `${this.streakDays}`;
      return this.t('streakDays', vars);
    }
    return this.t('streakNone');
  }

  async shareSummary(): Promise<void> {
    const prompt = this.getUIContext().getPromptAction();
    try {
      const values = await this.history.shareSummaryValues();
      const vars: Record<string, string> = {};
      vars['count'] = `${values[0]}`;
      vars['mins'] = `${values[1]}`;
      vars['streak'] = `${values[2]}`;
      const text = this.t('shareText', vars);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await systemPasteboard.setData(pasteData);
      prompt.showToast({ message: this.t('shareCopied'), duration: 2000 });
    } catch (_) {
      try {
        prompt.showToast({ message: this.t('shareFailed'), duration: 2000 });
      } catch (__) {
      }
    }
  }

  private escCsv(v: string): string {
    if (v.indexOf(',') >= 0 || v.indexOf('"') >= 0 || v.indexOf('\n') >= 0) {
      return `"${v.replace(/"/g, '""')}"`;
    }
    return v;
  }

  private buildExportCsv(rows: SyncSession[]): string {
    const lines: string[] = [];
    lines.push(this.t('exportCsvHeader'));
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      const at = new Date(row.at);
      const iso = isNaN(at.getTime()) ? String(row.at) : at.toISOString();
      const scene = this.resolveSceneTitle(row.sceneId);
      const planned = String(row.minutes);
      const elapsed = row.elapsedMs > 0 ? row.elapsedMs : row.minutes * 60000;
      const actual = String(Math.max(1, Math.round(elapsed / 60000)));
      lines.push([
        this.escCsv(iso),
        this.escCsv(scene),
        this.escCsv(planned),
        this.escCsv(actual)
      ].join(','));
    }
    return `${lines.join('\n')}\n`;
  }

  async exportCsv(): Promise<void> {
    const prompt = this.getUIContext().getPromptAction();
    try {
      const rows = await this.history.exportForSync();
      const csv = this.buildExportCsv(rows);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, csv);
      await systemPasteboard.setData(pasteData);
      prompt.showToast({ message: this.t('exportDone'), duration: 2000 });
    } catch (_) {
      try {
        prompt.showToast({ message: this.t('exportFailed'), duration: 2000 });
      } catch (__) {
      }
    }
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  private resolveSceneTitle(sceneId: string): string {
    if (!sceneId) {
      return this.t('historySceneDefault');
    }
    const custom = this.customScenes.find((s) => s.id === sceneId);
    if (custom) {
      return custom.name;
    }
    const found = this.scenes.find((s) => s.id === sceneId);
    if (found) {
      return this.t(found.titleKey);
    }
    return this.t('historySceneDefault');
  }

  private formatHistory(items: HistoryItem[]): HistoryRowView[] {
    const out: HistoryRowView[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const scene = this.resolveSceneTitle(item.sceneId);
      const sceneVars: Record<string, string> = {};
      sceneVars['scene'] = scene;
      const durVars: Record<string, string> = {};
      durVars['n'] = String(item.minutes);
      const timeVars: Record<string, string> = {};
      timeVars['time'] = this.formatDateTime(item.at);

      const row = new HistoryRowView();
      row.id = item.id;
      row.key = `${item.id}-${item.at}-${i}`;
      row.sceneLine = this.t('historySceneLine', sceneVars);
      row.durationLine = this.t('historyDurationLine', durVars);
      row.timeLine = this.t('historyTimeLine', timeVars);
      out.push(row);
    }
    return out;
  }

  private async buildFilterOptions(): Promise<void> {
    const all = await this.history.getHistory();
    const seen: string[] = [];
    const opts: FilterOption[] = [];
    opts.push(new FilterOption('', this.t('historyFilterAll')));
    for (let i = 0; i < all.length; i++) {
      const sid = all[i].sceneId;
      if (!sid || seen.indexOf(sid) >= 0) {
        continue;
      }
      seen.push(sid);
      opts.push(new FilterOption(sid, this.resolveSceneTitle(sid)));
    }
    this.filterOptions = opts;
  }

  private currentFilterLabel(): string {
    const found = this.filterOptions.find((o) => o.id === this.filterSceneId);
    if (found) {
      return found.label;
    }
    return this.t('historyFilterAll');
  }

  async setFilter(sceneId: string): Promise<void> {
    this.filterSceneId = sceneId;
    this.showFilter = false;
    await this.reload();
    this.uiTick = this.uiTick + 1;
  }

  async deleteRow(id: number): Promise<void> {
    try {
      const buttons: promptAction.Button[] = [
        { text: this.t('cancelLabel'), color: '#5F6F66' },
        { text: this.t('historyDelete'), color: '#D2554A' }
      ];
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: this.t('historyDelete'),
        message: this.t('historyDeleteConfirm'),
        buttons: buttons
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_) {
      return;
    }
    const clientId = await this.history.deleteSession(id);
    if (this.cloud && clientId) {
      this.cloud.scheduleDeleteSession(clientId);
    }
    await this.reload();
    this.uiTick = this.uiTick + 1;
  }

  async clearAll(): Promise<void> {
    try {
      const buttons: promptAction.Button[] = [
        { text: this.t('cancelLabel'), color: '#5F6F66' },
        { text: this.t('historyClear'), color: '#D2554A' }
      ];
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: this.t('historyClear'),
        message: this.t('historyClearConfirm'),
        buttons: buttons
      });
      if (res.index !== 1) {
        return;
      }
    } catch (_) {
      return;
    }
    await this.history.clearHistory();
    if (this.cloud) {
      this.cloud.scheduleClearSessions();
    }
    await this.reload();
    this.uiTick = this.uiTick + 1;
  }

  /** yyyy-MM-dd HH:mm:ss */
  private formatDateTime(at: number): string {
    const d = new Date(at);
    const y = d.getFullYear().toString();
    const mo = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const hh = d.getHours().toString().padStart(2, '0');
    const mm = d.getMinutes().toString().padStart(2, '0');
    const ss = d.getSeconds().toString().padStart(2, '0');
    return `${y}-${mo}-${day} ${hh}:${mm}:${ss}`;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Row() {
          Text(this.ready ? this.t('tabRecords') : '…')
            .fontSize(20)
            .fontFamily(FiveMinFont.semiBold)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
            .key(`records-title-${this.uiTick}`)
          if (this.ready) {
            Text(this.t('shareLabel'))
              .fontSize(14)
              .fontFamily(FiveMinFont.semiBold)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_strong'))
              .padding({ left: 8, right: 4, top: 10, bottom: 10 })
              .onClick(() => this.shareSummary())
            Text(this.t('exportLabel'))
              .fontSize(14)
              .fontFamily(FiveMinFont.semiBold)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.brand_strong'))
              .padding({ left: 4, right: 4, top: 10, bottom: 10 })
              .onClick(() => this.exportCsv())
          }
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
            Column({ space: FiveMinDimens.listSectionGap }) {
              Text(this.t('weekStatsLabel'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.muted'))
                .width('100%')
                .padding({ left: 4 })
                .key(`rec-period-${this.uiTick}-${HISTORY_DAYS}`)

              Row({ space: 10 }) {
                Column({ space: 6 }) {
                  Text(this.t('weekStatsCountLabel'))
                    .fontSize(12)
                    .fontFamily(FiveMinFont.medium)
                    .fontColor($r('app.color.muted'))
                  Text(`${this.periodCount}`)
                    .fontSize(28)
                    .fontFamily(FiveMinFont.semiBold)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.brand_strong'))
                }
                .layoutWeight(1)
                .padding(FiveMinDimens.padBody)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(FiveMinDimens.brandSoftStat)
                .border({ width: 1, color: FiveMinDimens.brandBorderSoft })
                .borderRadius(FiveMinDimens.radiusCard)

                Column({ space: 6 }) {
                  Text(this.t('weekStatsMinsLabel'))
                    .fontSize(12)
                    .fontFamily(FiveMinFont.medium)
                    .fontColor($r('app.color.muted'))
                  Row({ space: 4 }) {
                    Text(`${this.periodMins}`)
                      .fontSize(28)
                      .fontFamily(FiveMinFont.semiBold)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.brand_strong'))
                    Text(this.t('customUnit'))
                      .fontSize(13)
                      .fontColor($r('app.color.muted'))
                      .margin({ top: 10 })
                  }
                }
                .layoutWeight(1)
                .padding(FiveMinDimens.padBody)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(FiveMinDimens.brandSoftStat)
                .border({ width: 1, color: FiveMinDimens.brandBorderSoft })
                .borderRadius(FiveMinDimens.radiusCard)
              }
              .width('100%')

              Text(this.streakLine())
                .fontSize(13)
                .fontFamily(FiveMinFont.medium)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.muted'))
                .width('100%')
                .padding({ left: 4 })
                .key(`rec-streak-${this.uiTick}-${this.streakDays}`)

              if (this.showOvertimeInsight) {
                Column({ space: 8 }) {
                  Text(this.t('overtimeInsightTitle'))
                    .fontSize(15)
                    .fontFamily(FiveMinFont.semiBold)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ink'))
                    .width('100%')
                  Text(this.overtimeInsightLine)
                    .fontSize(14)
                    .fontFamily(FiveMinFont.medium)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ink'))
                    .width('100%')
                  Text(this.t('overtimeInsightHint'))
                    .fontSize(13)
                    .fontColor($r('app.color.muted'))
                    .width('100%')
                    .lineHeight(19)
                  Text(this.t('overtimeInsightTip'))
                    .fontSize(12)
                    .fontColor($r('app.color.muted'))
                    .margin({ top: 4 })
                    .width('100%')
                    .lineHeight(18)
                }
                .width('100%')
                .padding(FiveMinDimens.padBody)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(FiveMinDimens.warnCardBg)
                .border({ width: 1, color: FiveMinDimens.warnCardBorder })
                .borderRadius(FiveMinDimens.radiusCard)
              }

              Row() {
                Text(this.t('historyLabel'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.muted'))
                  .layoutWeight(1)
                Text(this.t('historyClear'))
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.danger'))
                  .padding({ left: 10, right: 4, top: 8, bottom: 8 })
                  .onClick(() => this.clearAll())
              }
              .width('100%')
              .padding({ left: 4, right: 4, top: 4 })

              Row() {
                Text(this.t('historyFilterLabel'))
                  .fontSize(13)
                  .fontColor($r('app.color.muted'))
                  .margin({ right: 8 })
                Text(this.filterLabel)
                  .fontSize(14)
                  .fontColor($r('app.color.ink'))
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text('▾')
                  .fontSize(12)
                  .fontColor(this.showFilter ? $r('app.color.brand_strong') : $r('app.color.muted'))
                  .rotate({ angle: this.showFilter ? 180 : 0 })
              }
              .width('100%')
              .height(FiveMinDimens.rowH)
              .padding({ left: 14, right: 14 })
              .backgroundColor($r('app.color.surface'))
              .border({
                width: 1,
                color: this.showFilter ? FiveMinDimens.brandBorderOpen : $r('app.color.line')
              })
              .borderRadius(FiveMinDimens.radius)
              .onClick(() => {
                this.showFilter = true;
              })

              Column({ space: 0 }) {
                if (this.historyRows.length === 0) {
                  Text(this.t('historyEmpty'))
                    .width('100%')
                    .fontSize(14)
                    .fontColor($r('app.color.muted'))
                    .padding(20)
                    .textAlign(TextAlign.Center)
                } else {
                  ForEach(this.historyRows, (row: HistoryRowView) => {
                    Column() {
                      Row({ space: 8 }) {
                        Column({ space: 6 }) {
                          Text(row.sceneLine)
                            .width('100%')
                            .fontSize(14)
                            .fontColor($r('app.color.ink'))
                            .maxLines(2)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(row.durationLine)
                            .width('100%')
                            .fontSize(14)
                            .fontColor($r('app.color.ink'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                          Text(row.timeLine)
                            .width('100%')
                            .fontSize(14)
                            .fontColor($r('app.color.ink'))
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        Text(this.t('historyDelete'))
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.danger'))
                          .padding({ left: 12, right: 8, top: 12, bottom: 12 })
                          .onClick(() => this.deleteRow(row.id))
                      }
                      .width('100%')
                      .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody, top: 14, bottom: 14 })
                      Divider().color($r('app.color.line')).margin({ left: FiveMinDimens.padBody })
                    }
                    .width('100%')
                  }, (row: HistoryRowView) => row.key)
                }
              }
              .width('100%')
              .backgroundColor(FiveMinDimens.cardSurface)
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
            .padding({
              left: FiveMinDimens.padBody,
              right: FiveMinDimens.padBody,
              top: FiveMinDimens.padBody,
              bottom: 24
            })
          }
          .layoutWeight(1)
          .width('100%')
          .align(Alignment.Top)
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
        colors: [['#EEF6F1', 0], ['#F2F5F3', 0.48], ['#F4F8F5', 1]]
      })

      if (this.showFilter) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(FiveMinDimens.overlayDim)
            .onClick(() => {
              this.showFilter = false;
            })

          Column({ space: 0 }) {
            Row() {
              Text(this.t('historyFilterLabel'))
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.ink'))
                .layoutWeight(1)
              Text('✕')
                .fontSize(18)
                .fontColor($r('app.color.muted'))
                .width(FiveMinDimens.rowH)
                .height(FiveMinDimens.rowH)
                .textAlign(TextAlign.Center)
                .onClick(() => {
                  this.showFilter = false;
                })
            }
            .width('100%')
            .padding({ left: FiveMinDimens.padX, right: 12, top: FiveMinDimens.padBody, bottom: 8 })

            Scroll() {
              Column({ space: 4 }) {
                ForEach(this.filterOptions, (opt: FilterOption) => {
                  Row() {
                    Text(opt.label)
                      .fontSize(15)
                      .fontColor(opt.id === this.filterSceneId ?
                        $r('app.color.brand_strong') : $r('app.color.ink'))
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    if (opt.id === this.filterSceneId) {
                      Text('✓')
                        .fontSize(16)
                        .fontColor($r('app.color.brand_strong'))
                    }
                  }
                  .width('100%')
                  .height(FiveMinDimens.controlH)
                  .padding({ left: FiveMinDimens.padBody, right: FiveMinDimens.padBody })
                  .onClick(() => this.setFilter(opt.id))
                }, (opt: FilterOption) => `filt-${opt.id}`)
              }
              .width('100%')
              .padding({ bottom: 28 })
            }
            .width('100%')
            .constraintSize({ maxHeight: FiveMinDimens.sheetMaxH })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius({ topLeft: FiveMinDimens.radiusSheet, topRight: FiveMinDimens.radiusSheet })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}