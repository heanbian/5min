import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { SharedCatalog } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
import { normalizeAppLocale } from '../common/AppLocales';
import { i18n } from '@kit.LocalizationKit';

@Entry
@Component
struct Beian {
  @State ready: boolean = false;
  @State locale: string = 'zh-CN';
  @State icp: string = '';

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
    const saved = await this.prefs.getLocale();
    const systemTags: string[] = [];
    try {
      systemTags.push(i18n.System.getSystemLanguage());
    } catch (_) {
    }
    this.locale = normalizeAppLocale(resolveLocale(this.catalog, saved, systemTags), 'zh-CN');
    this.icp = this.t('beianIcp');
    this.ready = true;
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  goBack(): void {
    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.brand_strong'))
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .onClick(() => this.goBack())
        Text(this.ready ? this.t('beianTitle') : '…')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ink'))
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank().width(36)
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .margin({ bottom: 8 })

      if (!this.ready) {
        Text('…')
          .fontSize(16)
          .fontColor($r('app.color.muted'))
          .margin({ top: 40 })
      } else {
        Column() {
          Text(this.icp)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ink'))
            .textAlign(TextAlign.Center)
            .width('100%')
            .lineHeight(24)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 24, bottom: 24 })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .margin({ left: 16, right: 16, top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#F2F5F3')
  }
}
