import { common } from '@kit.AbilityKit';
import { SharedCatalog, SceneItem } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { HistoryStore, HistoryItem, HISTORY_DAYS } from '../common/HistoryStore';
import { resolveLocale } from '../common/I18n';
import { i18n } from '@kit.LocalizationKit';

/** One list row: scene / duration / time on separate lines. */
class HistoryRowView {
  key: string = '';
  sceneLine: string = '';
  durationLine: string = '';
  timeLine: string = '';
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

  private catalog: SharedCatalog = new SharedCatalog();
  private prefs: PrefsStore = new PrefsStore();
  private history: HistoryStore = new HistoryStore();
  private scenes: SceneItem[] = [];

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
    const hist = await this.history.getHistory();
    this.historyRows = this.formatHistory(hist);
    const period = await this.history.periodStats();
    this.periodCount = period[0];
    this.periodMins = period[1];
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  private formatHistory(items: HistoryItem[]): HistoryRowView[] {
    // getHistory() already returns newest-first.
    const out: HistoryRowView[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      let scene = this.t('historySceneDefault');
      if (item.sceneId) {
        const found = this.scenes.find((s) => s.id === item.sceneId);
        if (found) {
          scene = this.t(found.titleKey);
        }
      }
      const sceneVars: Record<string, string> = {};
      sceneVars['scene'] = scene;
      const durVars: Record<string, string> = {};
      durVars['n'] = String(item.minutes);
      const timeVars: Record<string, string> = {};
      timeVars['time'] = this.formatDateTime(item.at);

      const row = new HistoryRowView();
      row.key = `${item.at}-${item.minutes}-${item.sceneId}-${i}`;
      row.sceneLine = this.t('historySceneLine', sceneVars);
      row.durationLine = this.t('historyDurationLine', durVars);
      row.timeLine = this.t('historyTimeLine', timeVars);
      out.push(row);
    }
    return out;
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
    Column() {
      Row() {
        Text(this.ready ? this.t('tabRecords') : '…')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .key(`records-title-${this.uiTick}`)
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
                  .fontColor($r('app.color.muted'))
                Text(`${this.periodCount}`)
                  .fontSize(28)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.ink'))
              }
              .layoutWeight(1)
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(14)

              Column({ space: 6 }) {
                Text(this.t('weekStatsMinsLabel'))
                  .fontSize(12)
                  .fontColor($r('app.color.muted'))
                Row({ space: 4 }) {
                  Text(`${this.periodMins}`)
                    .fontSize(28)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.ink'))
                  Text(this.t('customUnit'))
                    .fontSize(13)
                    .fontColor($r('app.color.muted'))
                    .margin({ top: 10 })
                }
              }
              .layoutWeight(1)
              .padding(16)
              .alignItems(HorizontalAlign.Start)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(14)
            }
            .width('100%')

            Text(this.t('historyLabel'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.muted'))
              .width('100%')
              .padding({ left: 4, top: 4 })

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
                    .width('100%')
                    .alignItems(HorizontalAlign.Start)
                    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                    Divider().color($r('app.color.line')).margin({ left: 16 })
                  }
                  .width('100%')
                }, (row: HistoryRowView) => row.key)
              }
            }
            .width('100%')
            .backgroundColor($r('app.color.surface'))
            .borderRadius(14)
            .clip(true)
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
    .backgroundColor('#F2F5F3')
  }
}
