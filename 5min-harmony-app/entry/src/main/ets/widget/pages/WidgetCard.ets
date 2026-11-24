/**
 * 2×2 glance card: today session count + remain when timer is running.
 * Tap routes to EntryAbility.
 */
const CARD_STORAGE = new LocalStorage();

@Entry(CARD_STORAGE)
@Component
struct WidgetCard {
  @LocalStorageProp('todayCount') todayCount: number = 0;
  @LocalStorageProp('remainText') remainText: string = '';
  @LocalStorageProp('running') running: boolean = false;
  @LocalStorageProp('countLine') countLine: string = '今日 0 次';
  @LocalStorageProp('remainLine') remainLine: string = '';

  build() {
    Column({ space: 6 }) {
      Text('如厕计时器')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#5F6F66')
        .width('100%')

      Text(this.countLine.length > 0 ? this.countLine : `今日 ${this.todayCount} 次`)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2A24')
        .width('100%')
        .maxLines(1)

      if (this.running && (this.remainLine.length > 0 || this.remainText.length > 0)) {
        Text(this.remainLine.length > 0 ? this.remainLine : `剩余 ${this.remainText}`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2F9A68')
          .width('100%')
          .maxLines(1)
      } else {
        Text('轻触打开')
          .fontSize(12)
          .fontColor('#8A9A90')
          .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#EEF6F1')
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { from: 'glance' }
      });
    })
  }
}
