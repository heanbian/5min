import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Durable RDB under app sandbox:
 *   {databaseDir}/rdb/5min-chat/5min_chat_history.db
 * Survives cover-install upgrades (same bundleName).
 */
const DB_NAME = '5min_chat_history.db';
const DB_CUSTOM_DIR = '5min-chat';
const TABLE = 'sessions';
/** Bump when schema changes; upgrades must ALTER / migrate, never DROP user data. */
const DB_SCHEMA_VERSION = 1;
/** Keep / show sessions within this many days. */
export const HISTORY_DAYS = 14;

const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'HistoryStore';

/** One finished session for local history. */
export class HistoryItem {
  at: number = 0;
  minutes: number = 0;
  sceneId: string = '';
}

/** Process-wide RDB handle so Index / Records share one durable store. */
let sharedRdb: relationalStore.RdbStore | null = null;
let sharedInit: Promise<relationalStore.RdbStore> | null = null;

/**
 * Local RDB for completed timer sessions.
 * Path: databaseDir/rdb/5min-chat/5min_chat_history.db
 */
export class HistoryStore {
  private store: relationalStore.RdbStore | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.store = await HistoryStore.openShared(context);
  }

  private static storeConfig(): relationalStore.StoreConfig {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      customDir: DB_CUSTOM_DIR,
      securityLevel: relationalStore.SecurityLevel.S1,
      encrypt: false,
      allowRebuild: false
    };
    return config;
  }

  private static openShared(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    if (sharedRdb) {
      return Promise.resolve(sharedRdb);
    }
    if (sharedInit) {
      return sharedInit;
    }
    sharedInit = HistoryStore.createStore(context).then((store: relationalStore.RdbStore) => {
      sharedRdb = store;
      return store;
    }).catch((err: Error) => {
      sharedInit = null;
      hilog.error(LOG_DOMAIN, LOG_TAG, 'open RDB failed %{public}s', JSON.stringify(err));
      throw err;
    });
    return sharedInit;
  }

  private static async createStore(context: common.UIAbilityContext): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, HistoryStore.storeConfig());
    await HistoryStore.ensureSchema(store);
    await HistoryStore.pruneOld(store);
    return store;
  }

  /** Create or upgrade schema in place — never DROP session tables. */
  private static async ensureSchema(store: relationalStore.RdbStore): Promise<void> {
    let current = 0;
    try {
      current = store.version;
    } catch (_) {
      current = 0;
    }
    if (current < 1) {
      await store.executeSql(
        `CREATE TABLE IF NOT EXISTS ${TABLE} (` +
          'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
          'at INTEGER NOT NULL, ' +
          'minutes INTEGER NOT NULL, ' +
          'scene_id TEXT NOT NULL DEFAULT \'\', ' +
          'elapsed_ms INTEGER NOT NULL DEFAULT 0)'
      );
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_sessions_at ON ${TABLE}(at)`
      );
    }
    if (store.version !== DB_SCHEMA_VERSION) {
      store.version = DB_SCHEMA_VERSION;
    }
  }

  async recordSession(elapsedMs: number, sceneId: string = ''): Promise<void> {
    if (!this.store) {
      return;
    }
    const ms = Math.max(0, elapsedMs);
    const minutes = Math.max(1, Math.round(ms / 60000));
    const values: relationalStore.ValuesBucket = {};
    values['at'] = Date.now();
    values['minutes'] = minutes;
    values['scene_id'] = sceneId ? sceneId : '';
    values['elapsed_ms'] = ms;
    await this.store.insert(TABLE, values);
    await HistoryStore.pruneOld(this.store);
  }

  /** Sessions in the last HISTORY_DAYS days, newest first. */
  async getHistory(): Promise<HistoryItem[]> {
    if (!this.store) {
      return [];
    }
    const cutoff = HistoryStore.cutoffMs();
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('at', cutoff);
    predicates.orderByDesc('at');
    const rs = await this.store.query(predicates);
    const out: HistoryItem[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          const item = new HistoryItem();
          item.at = rs.getLong(rs.getColumnIndex('at'));
          item.minutes = rs.getLong(rs.getColumnIndex('minutes'));
          item.sceneId = rs.getString(rs.getColumnIndex('scene_id'));
          if (item.at > 0 && item.minutes > 0) {
            out.push(item);
          }
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async periodStats(): Promise<[number, number]> {
    const list = await this.getHistory();
    let count = 0;
    let minutes = 0;
    for (let i = 0; i < list.length; i++) {
      count += 1;
      minutes += list[i].minutes;
    }
    return [count, minutes];
  }

  async todayStats(): Promise<[number, number]> {
    if (!this.store) {
      return [0, 0];
    }
    const start = HistoryStore.todayStartMs();
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('at', start);
    const rs = await this.store.query(predicates);
    let count = 0;
    let ms = 0;
    try {
      if (rs.goToFirstRow()) {
        do {
          count += 1;
          const elapsed = rs.getLong(rs.getColumnIndex('elapsed_ms'));
          const minutes = rs.getLong(rs.getColumnIndex('minutes'));
          ms += elapsed > 0 ? elapsed : minutes * 60000;
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return [count, ms];
  }

  private static cutoffMs(): number {
    return Date.now() - HISTORY_DAYS * 24 * 60 * 60 * 1000;
  }

  private static todayStartMs(): number {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  private static async pruneOld(store: relationalStore.RdbStore): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.lessThan('at', HistoryStore.cutoffMs());
    await store.delete(predicates);
  }
}
