/**
 * 2×2 glance card: today session count + remain when timer is running.
 * Tap routes to EntryAbility. Copy lines are published by the main ability (i18n).
 * Colors aligned with app.color.* brand tokens (widget cannot use $r in all runtimes).
 */
const CARD_STORAGE = new LocalStorage();

@Entry(CARD_STORAGE)
@Component
struct WidgetCard {
  @LocalStorageProp('todayCount') todayCount: number = 0;
  @LocalStorageProp('remainText') remainText: string = '';
  @LocalStorageProp('running') running: boolean = false;
  @LocalStorageProp('brandTitle') brandTitle: string = '';
  @LocalStorageProp('countLine') countLine: string = '';
  @LocalStorageProp('remainLine') remainLine: string = '';
  @LocalStorageProp('tapOpen') tapOpen: string = '';

  build() {
    Column({ space: 6 }) {
      if (this.brandTitle.length > 0) {
        Text(this.brandTitle)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#5F6F66') // muted
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.countLine.length > 0) {
        Text(this.countLine)
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1F2A24') // ink
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }

      if (this.running && this.remainLine.length > 0) {
        Text(this.remainLine)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#2F9A68') // brand
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else if (this.tapOpen.length > 0) {
        Text(this.tapOpen)
          .fontSize(12)
          .fontColor('#5F6F66') // muted
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#EEF6F1') // bg
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { from: 'glance' }
      });
    })
  }
}
