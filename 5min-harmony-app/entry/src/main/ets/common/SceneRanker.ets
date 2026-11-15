/**
 * On-device scene ranking from local session history (shared rules across clients).
 */
export class SessionRef {
  sceneId: string = '';
  at: number = 0;

  constructor(sceneId: string, at: number) {
    this.sceneId = sceneId;
    this.at = at;
  }
}

class RankedItem {
  id: string = '';
  score: number = 0;
  lastAt: number = 0;

  constructor(id: string, score: number, lastAt: number) {
    this.id = id;
    this.score = score;
    this.lastAt = lastAt;
  }
}

class UsageAgg {
  id: string = '';
  count: number = 0;
  lastAt: number = 0;

  constructor(id: string, count: number, lastAt: number) {
    this.id = id;
    this.count = count;
    this.lastAt = lastAt;
  }
}

export class SceneRanker {
  static readonly GROUP_ID: string = 'suggested';
  static readonly LABEL_KEY: string = 'sceneGroupSuggested';
  static readonly TOP_N: number = 6;
  static readonly CHIP_N: number = 5;
  static readonly MIN_COUNT: number = 2;
  static readonly RECENT_DAYS: number = 3;
  static readonly HISTORY_WINDOW_DAYS: number = 14;
  static readonly DAY_MS: number = 24 * 60 * 60 * 1000;

  /** Rank known scenes by frequency + recency. Empty when nothing qualifies (cold start). */
  static rank(sessions: SessionRef[], knownIds: string[], nowMs?: number): string[] {
    const now = nowMs !== undefined ? nowMs : Date.now();
    const known = new Set<string>(knownIds);
    const aggs: UsageAgg[] = [];

    for (let i = 0; i < sessions.length; i++) {
      const session = sessions[i];
      const id = (session.sceneId || '').trim();
      if (id.length === 0 || !known.has(id)) {
        continue;
      }
      let found: UsageAgg | null = null;
      for (let j = 0; j < aggs.length; j++) {
        if (aggs[j].id === id) {
          found = aggs[j];
          break;
        }
      }
      if (found) {
        found.count = found.count + 1;
        if (session.at > found.lastAt) {
          found.lastAt = session.at;
        }
      } else {
        aggs.push(new UsageAgg(id, 1, session.at));
      }
    }

    const ranked: RankedItem[] = [];
    for (let i = 0; i < aggs.length; i++) {
      const agg = aggs[i];
      const daysSince = Math.max(0, Math.floor((now - agg.lastAt) / SceneRanker.DAY_MS));
      const qualifies = agg.count >= SceneRanker.MIN_COUNT || daysSince <= SceneRanker.RECENT_DAYS;
      if (!qualifies) {
        continue;
      }
      const score = agg.count * 100 + Math.max(0, SceneRanker.HISTORY_WINDOW_DAYS - daysSince);
      ranked.push(new RankedItem(agg.id, score, agg.lastAt));
    }

    ranked.sort((a: RankedItem, b: RankedItem): number => {
      if (a.score !== b.score) {
        return b.score - a.score;
      }
      return b.lastAt - a.lastAt;
    });

    const out: string[] = [];
    const n = Math.min(SceneRanker.TOP_N, ranked.length);
    for (let i = 0; i < n; i++) {
      out.push(ranked[i].id);
    }
    return out;
  }
}
