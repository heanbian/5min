import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { filterAppLocales } from './AppLocales';

export interface SceneGroup {
  id: string;
  labelKey: string;
}

export interface SceneItem {
  id: string;
  min: number;
  group: string;
  labelKey: string;
  titleKey: string;
}

export class SharedCatalog {
  defaultMin: number = 5;
  alertDurationMs: number = 5000;
  groups: SceneGroup[] = [];
  scenes: SceneItem[] = [];
  localeCodes: string[] = [];
  defaultLocale: string = 'zh-CN';
  private localeMaps: Map<string, Map<string, string>> = new Map();
  private static cached: SharedCatalog | null = null;

  /** Shared across Index / Records / Mine — parse scenes + locales once per process. */
  static async load(context: common.UIAbilityContext): Promise<SharedCatalog> {
    if (SharedCatalog.cached) {
      return SharedCatalog.cached;
    }
    const cat = new SharedCatalog();
    const scenesText = await SharedCatalog.readRaw(context, 'shared/scenes.json');
    const root: Record<string, Object> = JSON.parse(scenesText);
    cat.defaultMin = root['defaultMin'] as number;
    cat.alertDurationMs = root['alertDurationMs'] as number;
    cat.groups = root['groups'] as SceneGroup[];
    cat.scenes = root['scenes'] as SceneItem[];
    cat.localeCodes = filterAppLocales(root['localeCodes'] as string[]);
    cat.defaultLocale = 'zh-CN';
    for (let i = 0; i < cat.localeCodes.length; i++) {
      const code = cat.localeCodes[i];
      const text = await SharedCatalog.readRaw(context, `shared/locales/${code}.json`);
      const obj: Record<string, Object> = JSON.parse(text);
      const map = new Map<string, string>();
      const keys = Object.keys(obj);
      for (let j = 0; j < keys.length; j++) {
        const k = keys[j];
        map.set(k, String(obj[k]));
      }
      cat.localeMaps.set(code, map);
    }
    SharedCatalog.cached = cat;
    return cat;
  }

  private static async readRaw(context: common.UIAbilityContext, path: string): Promise<string> {
    const buf = await context.resourceManager.getRawFileContent(path);
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    return decoder.decodeToString(buf);
  }

  t(locale: string, key: string, vars?: Record<string, string>): string {
    let pack = this.localeMaps.get(locale);
    if (!pack) {
      pack = this.localeMaps.get(this.defaultLocale);
    }
    let text = key;
    if (pack && pack.has(key)) {
      text = pack.get(key) as string;
    } else {
      const fallback = this.localeMaps.get(this.defaultLocale);
      if (fallback && fallback.has(key)) {
        text = fallback.get(key) as string;
      }
    }
    if (vars) {
      const keys = Object.keys(vars);
      for (let i = 0; i < keys.length; i++) {
        const k = keys[i];
        const token = `{${k}}`;
        const value = vars[k];
        while (text.indexOf(token) >= 0) {
          text = text.replace(token, value);
        }
      }
    }
    return text;
  }
}
