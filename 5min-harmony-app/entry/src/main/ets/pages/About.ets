import { common, bundleManager } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { SharedCatalog } from '../common/SharedCatalog';
import { PrefsStore } from '../common/PrefsStore';
import { resolveLocale } from '../common/I18n';
import { normalizeAppLocale } from '../common/AppLocales';
import { openExternalUrl } from '../common/OpenUrl';
import { i18n } from '@kit.LocalizationKit';

const PRIVACY_URL = 'https://5min.chat/privacy.html';
const TERMS_URL = 'https://5min.chat/terms.html';
const SITE_URL = 'https://5min.chat/';

@Entry
@Component
struct About {
  @State ready: boolean = false;
  @State locale: string = 'zh-CN';
  @State appVersion: string = '1.0.5';

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
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = info.versionName;
    } catch (_) {
    }
    this.ready = true;
  }

  t(key: string, vars?: Record<string, string>): string {
    return this.catalog.t(this.locale, key, vars);
  }

  private varsN(n: string): Record<string, string> {
    const vars: Record<string, string> = {};
    vars['n'] = n;
    return vars;
  }

  goBack(): void {
    router.back();
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

  async openSite(): Promise<void> {
    if (this.context) {
      await openExternalUrl(this.context, SITE_URL);
    }
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
        Text(this.ready ? this.t('aboutLabel') : '…')
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
        Scroll() {
          Column({ space: 16 }) {
            Image($r('app.media.logo'))
              .height(36)
              .objectFit(ImageFit.Contain)
              .alignSelf(ItemAlign.Center)
              .margin({ top: 8, bottom: 4 })

            Text(this.t('aboutTitle'))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ink'))
              .width('100%')
              .textAlign(TextAlign.Center)

            Text(this.t('aboutVersion', this.varsN(this.appVersion)))
              .fontSize(13)
              .fontColor($r('app.color.muted'))
              .width('100%')
              .textAlign(TextAlign.Center)

            Text(this.t('aboutBody'))
              .fontSize(14)
              .fontColor($r('app.color.ink'))
              .lineHeight(22)
              .width('100%')
              .margin({ top: 8 })

            Column({ space: 0 }) {
              this.linkRow(this.t('privacyLink'), () => this.openPrivacy())
              Divider().color($r('app.color.line'))
              this.linkRow(this.t('termsLink'), () => this.openTerms())
              Divider().color($r('app.color.line'))
              this.linkRow(this.t('aboutWebsite'), () => this.openSite())
            }
            .width('100%')
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.line') })
            .borderRadius(14)
            .clip(true)
            .margin({ top: 8 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 4, bottom: 24 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg'))
  }

  @Builder
  linkRow(label: string, onTap: () => void) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.ink'))
        .layoutWeight(1)
      Text('›')
        .fontSize(18)
        .fontColor($r('app.color.muted'))
    }
    .width('100%')
    .height(48)
    .padding({ left: 14, right: 14 })
    .onClick(onTap)
  }
}
