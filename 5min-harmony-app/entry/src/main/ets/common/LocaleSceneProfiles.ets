import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { SceneGroup } from './SharedCatalog';
import { SceneRanker } from './SceneRanker';

export class SceneProfile {
  pin: string[] = [];
  groupOrder: string[] = [];
  demoteGroups: string[] = [];
  hideGroups: string[] = [];
  hideScenes: string[] = [];
}

/** Locale scene picker profile — pin / order / demote / hide. */
export class LocaleSceneProfiles {
  private static root: Record<string, Object> | null = null;
  private static cache: Map<string, SceneProfile> = new Map();

  static async load(context: common.UIAbilityContext): Promise<void> {
    if (LocaleSceneProfiles.root) {
      return;
    }
    const buf = await context.resourceManager.getRawFileContent('shared/locale-scene-profiles.json');
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const text = decoder.decodeToString(buf);
    LocaleSceneProfiles.root = JSON.parse(text) as Record<string, Object>;
    LocaleSceneProfiles.cache.clear();
  }

  static resolve(locale: string): SceneProfile {
    const hit = LocaleSceneProfiles.cache.get(locale);
    if (hit) {
      return hit;
    }
    const doc = LocaleSceneProfiles.root;
    const base = doc ? (doc['default'] as Record<string, Object> | undefined) : undefined;
    const over = doc ? (doc[locale] as Record<string, Object> | undefined) : undefined;
    const profile = new SceneProfile();
    profile.pin = LocaleSceneProfiles.stringList(over, 'pin') ??
      LocaleSceneProfiles.stringList(base, 'pin') ??
      LocaleSceneProfiles.FALLBACK_PIN.slice();
    profile.groupOrder = LocaleSceneProfiles.stringList(over, 'groupOrder') ??
      LocaleSceneProfiles.stringList(base, 'groupOrder') ??
      LocaleSceneProfiles.FALLBACK_GROUP_ORDER.slice();
    profile.demoteGroups = LocaleSceneProfiles.stringList(over, 'demoteGroups') ??
      LocaleSceneProfiles.stringList(base, 'demoteGroups') ??
      LocaleSceneProfiles.FALLBACK_DEMOTE.slice();
    profile.hideGroups = LocaleSceneProfiles.stringList(over, 'hideGroups') ??
      LocaleSceneProfiles.stringList(base, 'hideGroups') ?? [];
    profile.hideScenes = LocaleSceneProfiles.stringList(over, 'hideScenes') ??
      LocaleSceneProfiles.stringList(base, 'hideScenes') ?? [];
    LocaleSceneProfiles.cache.set(locale, profile);
    return profile;
  }

  private static readonly FALLBACK_PIN: string[] =
    ['toilet', 'brush', 'noodles', 'shower', 'lazy5'];
  private static readonly FALLBACK_GROUP_ORDER: string[] =
    ['daily', 'kitchen', 'care', 'rest', 'work', 'study', 'chores', 'transit', 'labor', 'farm'];
  private static readonly FALLBACK_DEMOTE: string[] = ['farm', 'labor'];

  static orderGroups(groups: SceneGroup[], profile: SceneProfile): SceneGroup[] {
    const hide = new Set<string>(profile.hideGroups);
    const demote = new Set<string>(profile.demoteGroups);
    const byId = new Map<string, SceneGroup>();
    for (let i = 0; i < groups.length; i++) {
      byId.set(groups[i].id, groups[i]);
    }
    const primary: SceneGroup[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < profile.groupOrder.length; i++) {
      const id = profile.groupOrder[i];
      if (hide.has(id) || demote.has(id) || seen.has(id)) {
        continue;
      }
      const g = byId.get(id);
      if (!g) {
        continue;
      }
      primary.push(g);
      seen.add(id);
    }
    for (let i = 0; i < groups.length; i++) {
      const g = groups[i];
      if (hide.has(g.id) || demote.has(g.id) || seen.has(g.id)) {
        continue;
      }
      primary.push(g);
      seen.add(g.id);
    }
    const demoted: SceneGroup[] = [];
    for (let i = 0; i < profile.groupOrder.length; i++) {
      const id = profile.groupOrder[i];
      if (!demote.has(id) || hide.has(id) || seen.has(id)) {
        continue;
      }
      const g = byId.get(id);
      if (!g) {
        continue;
      }
      demoted.push(g);
      seen.add(id);
    }
    for (let i = 0; i < groups.length; i++) {
      const g = groups[i];
      if (!demote.has(g.id) || hide.has(g.id) || seen.has(g.id)) {
        continue;
      }
      demoted.push(g);
      seen.add(g.id);
    }
    return primary.concat(demoted);
  }

  static isSceneHidden(sceneId: string, profile: SceneProfile): boolean {
    return profile.hideScenes.indexOf(sceneId) >= 0;
  }

  /** Pin first, then ranked usage ids; unique; capped. Skips hideScenes so topN can still fill. */
  static mergePinnedSuggested(
    ranked: string[],
    pin: string[],
    knownIds: string[],
    topN: number = SceneRanker.TOP_N,
    hideScenes: string[] = []
  ): string[] {
    const known = new Set<string>(knownIds);
    const hidden = new Set<string>(hideScenes);
    const out: string[] = [];
    const seen = new Set<string>();
    const take = (id: string): boolean => {
      if (!known.has(id) || seen.has(id) || hidden.has(id)) {
        return false;
      }
      out.push(id);
      seen.add(id);
      return out.length >= topN;
    };
    for (let i = 0; i < pin.length; i++) {
      if (take(pin[i])) {
        return out;
      }
    }
    for (let i = 0; i < ranked.length; i++) {
      if (take(ranked[i])) {
        return out;
      }
    }
    return out;
  }

  private static stringList(obj: Record<string, Object> | undefined, key: string): string[] | null {
    if (!obj || !obj[key]) {
      return null;
    }
    const arr = obj[key] as Object;
    if (!Array.isArray(arr)) {
      return null;
    }
    const out: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(String(arr[i]));
    }
    return out;
  }
}
