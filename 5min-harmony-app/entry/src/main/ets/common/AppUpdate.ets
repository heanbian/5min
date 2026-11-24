/**
 * Checks https://5min.chat/app/harmony-latest.json against the installed version.
 */
import { bundleManager, common, Want } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const LATEST_URL = 'https://5min.chat/app/harmony-latest.json';
const FALLBACK_PAGE = 'https://5min.chat/download.html';
const TRUSTED_HOSTS: string[] = ['5min.chat', 'www.5min.chat'];

function isTrustedHost(host: string): boolean {
  return TRUSTED_HOSTS.indexOf(host) >= 0 || host.endsWith('.5min.chat');
}
const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'AppUpdate';

export class HarmonyLatest {
  versionCode: number = 0;
  versionName: string = '';
  pageUrl: string = '';
}

export type UpdateCheckKind = 'latest' | 'available' | 'failed';

export class UpdateCheckResult {
  kind: UpdateCheckKind = 'failed';
  currentName: string = '';
  latest: HarmonyLatest | null = null;
  message: string = '';

  static latest(currentName: string): UpdateCheckResult {
    const r = new UpdateCheckResult();
    r.kind = 'latest';
    r.currentName = currentName;
    return r;
  }

  static available(latest: HarmonyLatest, currentName: string): UpdateCheckResult {
    const r = new UpdateCheckResult();
    r.kind = 'available';
    r.latest = latest;
    r.currentName = currentName;
    return r;
  }

  static failed(message: string = ''): UpdateCheckResult {
    const r = new UpdateCheckResult();
    r.kind = 'failed';
    r.message = message;
    return r;
  }
}

export class AppUpdate {
  static localVersionName(): string {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      const name = String(info.versionName ?? '');
      return name.length > 0 ? name : '—';
    } catch (_) {
      return '—';
    }
  }

  static localVersionCode(): number {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      const code = Number(info.versionCode ?? 0);
      return isNaN(code) ? 0 : Math.floor(code);
    } catch (_) {
      return 0;
    }
  }

  /** Network call — await off the UI critical path. */
  static async check(): Promise<UpdateCheckResult> {
    const currentCode = AppUpdate.localVersionCode();
    const currentName = AppUpdate.localVersionName();
    try {
      const latest = await AppUpdate.fetchLatest();
      if (latest.versionCode > currentCode) {
        return UpdateCheckResult.available(latest, currentName);
      }
      return UpdateCheckResult.latest(currentName);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'check failed %{public}s', msg);
      return UpdateCheckResult.failed(msg);
    }
  }

  static async fetchLatest(): Promise<HarmonyLatest> {
    const client = http.createHttp();
    try {
      const response = await client.request(LATEST_URL, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const code = response.responseCode;
      if (code < 200 || code >= 300) {
        throw new Error(`HTTP ${code}`);
      }
      const text = typeof response.result === 'string' ? response.result as string : '';
      const json = JSON.parse(text) as Record<string, Object>;
      const versionCode = Math.floor(Number(json['versionCode'] ?? 0));
      const versionName = String(json['versionName'] ?? '').trim();
      const pageRaw = String(json['pageUrl'] ?? '').trim();
      const pageUrl = AppUpdate.trustedHttpsUrl(pageRaw) ?? FALLBACK_PAGE;
      if (versionCode <= 0 || versionName.length === 0) {
        throw new Error('invalid update manifest');
      }
      const latest = new HarmonyLatest();
      latest.versionCode = versionCode;
      latest.versionName = versionName;
      latest.pageUrl = pageUrl;
      return latest;
    } finally {
      client.destroy();
    }
  }

  static async openUrl(context: common.UIAbilityContext, url: string): Promise<void> {
    const target = AppUpdate.trustedHttpsUrl(url);
    if (!target) {
      return;
    }
    try {
      const want: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: target
      };
      await context.startAbility(want);
    } catch (e) {
      hilog.warn(LOG_DOMAIN, LOG_TAG, 'openUrl failed %{public}s', JSON.stringify(e));
    }
  }

  /** Only https URLs on 5min.chat (or www) are accepted for update / download links. */
  static trustedHttpsUrl(url: string): string | null {
    const target = url ? url.trim() : '';
    if (!target.toLowerCase().startsWith('https://')) {
      return null;
    }
    const host = AppUpdate.hostOf(target);
    if (!host || !isTrustedHost(host)) {
      return null;
    }
    return target;
  }

  private static hostOf(url: string): string | null {
    try {
      const withoutScheme = url.substring('https://'.length);
      const slash = withoutScheme.indexOf('/');
      const authority = slash >= 0 ? withoutScheme.substring(0, slash) : withoutScheme;
      const at = authority.lastIndexOf('@');
      const hostPort = at >= 0 ? authority.substring(at + 1) : authority;
      const colon = hostPort.indexOf(':');
      const host = (colon >= 0 ? hostPort.substring(0, colon) : hostPort).toLowerCase();
      return host.length > 0 ? host : null;
    } catch (_) {
      return null;
    }
  }
}
