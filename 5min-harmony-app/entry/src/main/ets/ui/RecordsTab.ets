import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { SharedCatalog, SceneItem } from '../common/SharedCatalog';
import { PrefsStore, CustomScene } from '../common/PrefsStore';
import { HistoryStore, HistoryItem, HISTORY_DAYS } from '../common/HistoryStore';
import { CloudSync } from '../common/CloudSync';
import { insightMinutes } from '../common/P0Features';
import { resolveLocale } from '../common/I18n';
import { FiveMinFont } from '../common/FiveMinDimens';
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
  @Watch('onEpoch') @Prop epoch: number = 0;
  @State ready: boolean = false;
  @State historyRows: HistoryRowView[] = [];
  @State periodCount: number = 0;
  @State periodMins: number = 0;
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

  aboutToAppear(): void {
    this.bootstrap();
  }

  onEpoch(): void {
    if (this.ready) {
      this.reload();
    }
  }

  onLocaleChange(): void {
    if (this.ready) {
      this.reload();
      this.uiTick = this.uiTick + 1;
    }
  }

  async bootstrap(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await this.prefs.init(context);
    await this.history.init(context);
    this.cloud = new CloudSync(this.prefs, this.history);
    this.catalog = await SharedCatalog.load(context);
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
    const period = await this.history.periodStats();
    this.periodCount = period[0];
    this.periodMins = period[1];
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
      const res = await promptAction.showDialog({
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
      const res = await promptAction.showDialog({
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
            .key(`records-title-${this.uiTick}`)
        }
        .width('100%')
        .height(52)
        .padding({ left: 20, right: 20 })
        .alignItems(VerticalAlign.Center)
        .backgroundColor('rgba(255, 255, 255, 0.72)')
        .border({ width: { bottom: 1 }, color: 'rgba(215, 229, 220, 0.85)' })

        if (!this.ready) {
          Text('…')
            .fontColor($r('app.color.muted'))
            .margin({ top: 24 })
            .width('100%')
            .textAlign(TextAlign.Center)
        } else {
          Scroll() {
            Column({ space: 16 }) {
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
                .padding(16)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor('rgba(229, 245, 236, 0.55)')
                .border({ width: 1, color: 'rgba(47, 154, 104, 0.12)' })
                .borderRadius(14)

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
                .padding(16)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor('rgba(229, 245, 236, 0.55)')
                .border({ width: 1, color: 'rgba(47, 154, 104, 0.12)' })
                .borderRadius(14)
              }
              .width('100%')

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
                    .fontSize(12)
                    .fontColor($r('app.color.muted'))
                    .width('100%')
                    .lineHeight(18)
                }
                .width('100%')
                .padding(16)
                .alignItems(HorizontalAlign.Start)
                .backgroundColor('rgba(255, 246, 232, 0.72)')
                .border({ width: 1, color: 'rgba(201, 134, 45, 0.16)' })
                .borderRadius(14)
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
                  .fontColor($r('app.color.muted'))
              }
              .width('100%')
              .height(40)
              .padding({ left: 14, right: 14 })
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.line') })
              .borderRadius(22)
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
                          Text(row.durationLine)
                            .width('100%')
                            .fontSize(14)
                            .fontColor($r('app.color.ink'))
                          Text(row.timeLine)
                            .width('100%')
                            .fontSize(14)
                            .fontColor($r('app.color.ink'))
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        Text(this.t('historyDelete'))
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor($r('app.color.danger'))
                          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                          .onClick(() => this.deleteRow(row.id))
                      }
                      .width('100%')
                      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                      Divider().color($r('app.color.line')).margin({ left: 16 })
                    }
                    .width('100%')
                  }, (row: HistoryRowView) => row.key)
                }
              }
              .width('100%')
              .backgroundColor('rgba(255, 255, 255, 0.88)')
              .border({ width: 1, color: 'rgba(215, 229, 220, 0.9)' })
              .borderRadius(14)
              .clip(true)
              .shadow({
                radius: 8,
                color: 'rgba(31, 42, 36, 0.04)',
                offsetX: 0,
                offsetY: 2
              })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 24 })
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
            .backgroundColor('#00000066')
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
                .onClick(() => {
                  this.showFilter = false;
                })
            }
            .width('100%')
            .padding({ left: 20, right: 16, top: 16, bottom: 8 })

            Scroll() {
              Column({ space: 4 }) {
                ForEach(this.filterOptions, (opt: FilterOption) => {
                  Row() {
                    Text(opt.label)
                      .fontSize(15)
                      .fontColor(opt.id === this.filterSceneId ?
                        $r('app.color.brand_strong') : $r('app.color.ink'))
                      .layoutWeight(1)
                    if (opt.id === this.filterSceneId) {
                      Text('✓')
                        .fontSize(16)
                        .fontColor($r('app.color.brand_strong'))
                    }
                  }
                  .width('100%')
                  .height(52)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => this.setFilter(opt.id))
                }, (opt: FilterOption) => `filt-${opt.id}`)
              }
              .width('100%')
              .padding({ bottom: 24 })
            }
            .width('100%')
            .constraintSize({ maxHeight: 360 })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .borderRadius({ topLeft: 18, topRight: 18 })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}