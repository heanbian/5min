import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

/**
 * Durable RDB under app sandbox:
 *   {databaseDir}/rdb/5min-chat/5min_chat_history.db
 * Survives cover-install upgrades (same bundleName).
 */
const DB_NAME = '5min_chat_history.db';
const DB_CUSTOM_DIR = '5min-chat';
const TABLE = 'sessions';
/** Bump when schema changes; upgrades must ALTER / migrate, never DROP user data. */
const DB_SCHEMA_VERSION = 2;
/** Keep / show sessions within this many days. */
export const HISTORY_DAYS = 14;

const LOG_DOMAIN = 0x5f1d;
const LOG_TAG = 'HistoryStore';

/** One finished session for local history. */
export class HistoryItem {
  id: number = 0;
  at: number = 0;
  minutes: number = 0;
  sceneId: string = '';
  clientId: string = '';
}

/** Session row for cloud sync (device-bound client id). */
export class SyncSession {
  clientId: string = '';
  at: number = 0;
  minutes: number = 0;
  sceneId: string = '';
  elapsedMs: number = 0;

  constructor(clientId: string, at: number, minutes: number, sceneId: string, elapsedMs: number) {
    this.clientId = clientId;
    this.at = at;
    this.minutes = minutes;
    this.sceneId = sceneId;
    this.elapsedMs = elapsedMs;
  }
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
          'elapsed_ms INTEGER NOT NULL DEFAULT 0, ' +
          'client_id TEXT NOT NULL DEFAULT \'\')'
      );
      await store.executeSql(
        `CREATE INDEX IF NOT EXISTS idx_sessions_at ON ${TABLE}(at)`
      );
    }
    if (current < 2) {
      await HistoryStore.ensureClientIdColumn(store);
    }
    if (store.version !== DB_SCHEMA_VERSION) {
      store.version = DB_SCHEMA_VERSION;
    }
  }

  private static async ensureClientIdColumn(store: relationalStore.RdbStore): Promise<void> {
    let hasClientId = false;
    try {
      const rs = await store.querySql(`PRAGMA table_info(${TABLE})`);
      try {
        if (rs.goToFirstRow()) {
          do {
            const name = rs.getString(rs.getColumnIndex('name'));
            if (name === 'client_id') {
              hasClientId = true;
              break;
            }
          } while (rs.goToNextRow());
        }
      } finally {
        rs.close();
      }
    } catch (_) {
      hasClientId = false;
    }
    if (!hasClientId) {
      await store.executeSql(
        `ALTER TABLE ${TABLE} ADD COLUMN client_id TEXT NOT NULL DEFAULT ''`
      );
    }
    await store.executeSql(
      `UPDATE ${TABLE} SET client_id = 'n_' || id WHERE client_id IS NULL OR client_id = ''`
    );
    await store.executeSql(
      `CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_client_id ON ${TABLE}(client_id)`
    );
  }

  private static newClientId(): string {
    return `n_${util.generateRandomUUID().toLowerCase()}`;
  }

  async recordSession(elapsedMs: number, sceneId: string = ''): Promise<number> {
    if (!this.store) {
      return 0;
    }
    const ms = Math.max(0, elapsedMs);
    const minutes = Math.max(1, Math.round(ms / 60000));
    const values: relationalStore.ValuesBucket = {};
    values['at'] = Date.now();
    values['minutes'] = minutes;
    values['scene_id'] = sceneId ? sceneId : '';
    values['elapsed_ms'] = ms;
    values['client_id'] = HistoryStore.newClientId();
    const rowId = await this.store.insert(TABLE, values);
    await HistoryStore.pruneOld(this.store);
    return rowId;
  }

  async updateSessionElapsed(id: number, elapsedMs: number): Promise<void> {
    if (!this.store || id <= 0) {
      return;
    }
    const ms = Math.max(0, elapsedMs);
    const minutes = Math.max(1, Math.round(ms / 60000));
    const values: relationalStore.ValuesBucket = {};
    values['minutes'] = minutes;
    values['elapsed_ms'] = ms;
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    await this.store.update(values, predicates);
  }

  async clientIdOf(id: number): Promise<string> {
    if (!this.store || id <= 0) {
      return '';
    }
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    const rs = await this.store.query(predicates);
    try {
      if (rs.goToFirstRow()) {
        return rs.getString(rs.getColumnIndex('client_id'));
      }
    } finally {
      rs.close();
    }
    return '';
  }

  /** Delete one session; returns its clientId for remote delete when cloud. */
  async deleteSession(id: number): Promise<string> {
    if (!this.store || id <= 0) {
      return '';
    }
    const clientId = await this.clientIdOf(id);
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.equalTo('id', id);
    await this.store.delete(predicates);
    return clientId;
  }

  async clearHistory(): Promise<void> {
    if (!this.store) {
      return;
    }
    const predicates = new relationalStore.RdbPredicates(TABLE);
    await this.store.delete(predicates);
  }

  /** Sessions in the last HISTORY_DAYS days, newest first; optional scene filter. */
  async getHistory(sceneId: string = ''): Promise<HistoryItem[]> {
    if (!this.store) {
      return [];
    }
    const cutoff = HistoryStore.cutoffMs();
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('at', cutoff);
    if (sceneId.length > 0) {
      predicates.equalTo('scene_id', sceneId);
    }
    predicates.orderByDesc('at');
    const rs = await this.store.query(predicates);
    const out: HistoryItem[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          const item = new HistoryItem();
          item.id = rs.getLong(rs.getColumnIndex('id'));
          item.at = rs.getLong(rs.getColumnIndex('at'));
          item.minutes = rs.getLong(rs.getColumnIndex('minutes'));
          item.sceneId = rs.getString(rs.getColumnIndex('scene_id'));
          try {
            item.clientId = rs.getString(rs.getColumnIndex('client_id'));
          } catch (_) {
            item.clientId = '';
          }
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

  async exportForSync(): Promise<SyncSession[]> {
    if (!this.store) {
      return [];
    }
    const cutoff = HistoryStore.cutoffMs();
    const predicates = new relationalStore.RdbPredicates(TABLE);
    predicates.greaterThanOrEqualTo('at', cutoff);
    predicates.orderByDesc('at');
    const rs = await this.store.query(predicates);
    const out: SyncSession[] = [];
    try {
      if (rs.goToFirstRow()) {
        do {
          const clientId = rs.getString(rs.getColumnIndex('client_id'));
          const at = rs.getLong(rs.getColumnIndex('at'));
          const minutes = rs.getLong(rs.getColumnIndex('minutes'));
          if (!clientId || at <= 0 || minutes <= 0) {
            continue;
          }
          out.push(new SyncSession(
            clientId,
            at,
            minutes,
            rs.getString(rs.getColumnIndex('scene_id')),
            rs.getLong(rs.getColumnIndex('elapsed_ms'))
          ));
        } while (rs.goToNextRow());
      }
    } finally {
      rs.close();
    }
    return out;
  }

  async mergeFromCloud(rows: SyncSession[]): Promise<void> {
    if (!this.store || rows.length === 0) {
      return;
    }
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      if (!row.clientId || row.at <= 0 || row.minutes <= 0) {
        continue;
      }
      const predicates = new relationalStore.RdbPredicates(TABLE);
      predicates.equalTo('client_id', row.clientId);
      const rs = await this.store.query(predicates);
      let existingId = -1;
      try {
        if (rs.goToFirstRow()) {
          existingId = rs.getLong(rs.getColumnIndex('id'));
        }
      } finally {
        rs.close();
      }
      const values: relationalStore.ValuesBucket = {};
      values['at'] = row.at;
      values['minutes'] = row.minutes;
      values['scene_id'] = row.sceneId ? row.sceneId : '';
      values['elapsed_ms'] = Math.max(0, row.elapsedMs);
      values['client_id'] = row.clientId;
      if (existingId > 0) {
        const upd = new relationalStore.RdbPredicates(TABLE);
        upd.equalTo('id', existingId);
        await this.store.update(values, upd);
      } else {
        await this.store.insert(TABLE, values);
      }
    }
    await HistoryStore.pruneOld(this.store);
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
