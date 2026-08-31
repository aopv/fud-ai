import { openDB, type DBSchema, type IDBPDatabase } from "idb";
import { compareRecordVersionsLww } from "@fud-ai/sync-contracts";
import type { LocalEntity, SyncConfiguration } from "../domain";
import { EMPTY_SYNC_CONFIGURATION } from "../domain";

interface FudDatabase extends DBSchema {
  records: {
    key: string;
    value: LocalEntity;
    indexes: { namespace: string };
  };
  metadata: {
    key: string;
    value: string;
  };
}

const DATABASE_NAME = "fud-ai-web";
const DATABASE_VERSION = 1;
let databasePromise: Promise<IDBPDatabase<FudDatabase>> | undefined;

function database(): Promise<IDBPDatabase<FudDatabase>> {
  databasePromise ??= openDB<FudDatabase>(DATABASE_NAME, DATABASE_VERSION, {
    upgrade(db) {
      const records = db.createObjectStore("records", { keyPath: "recordId" });
      records.createIndex("namespace", "namespace");
      db.createObjectStore("metadata");
    },
  });
  return databasePromise;
}

export async function listRecords(): Promise<LocalEntity[]> {
  return (await database()).getAll("records");
}

export async function getRecord(recordId: string): Promise<LocalEntity | undefined> {
  return (await database()).get("records", recordId);
}

export async function putRecord(record: LocalEntity): Promise<void> {
  await (await database()).put("records", record);
}

export async function updateRecordAtomically(
  recordId: string,
  transform: (current: LocalEntity | undefined) => LocalEntity,
): Promise<void> {
  const db = await database();
  const transaction = db.transaction("records", "readwrite");
  const current = await transaction.store.get(recordId);
  await transaction.store.put(transform(current));
  await transaction.done;
}

export async function putRecords(records: readonly LocalEntity[]): Promise<void> {
  const db = await database();
  const transaction = db.transaction("records", "readwrite");
  await Promise.all(records.map((record) => transaction.store.put(record)));
  await transaction.done;
}

export async function mergeRemoteRecordsAtomically(records: readonly LocalEntity[]): Promise<void> {
  if (records.length === 0) return;
  const db = await database();
  const transaction = db.transaction("records", "readwrite");
  try {
    for (const incoming of records) {
      const current = await transaction.store.get(incoming.recordId);
      if (current && current.namespace !== incoming.namespace) {
        throw new Error(`Record ${incoming.recordId} cannot change namespace`);
      }
      if (!current || compareRecordVersionsLww(incoming.version, current.version) > 0) {
        await transaction.store.put(incoming);
      }
    }
    await transaction.done;
  } catch (error) {
    try { transaction.abort(); } catch { /* The transaction may already be inactive. */ }
    throw error;
  }
}

export async function clearRecords(): Promise<void> {
  await (await database()).clear("records");
}

/**
 * Replaces the record set inside one IndexedDB transaction. The transform must
 * remain synchronous so the transaction cannot become inactive between its
 * read and writes.
 */
export async function replaceRecordsAtomically(
  transform: (current: readonly LocalEntity[]) => readonly LocalEntity[],
): Promise<void> {
  const db = await database();
  const transaction = db.transaction("records", "readwrite");
  const current = await transaction.store.getAll();
  const next = transform(current);
  await transaction.store.clear();
  await Promise.all(next.map((record) => transaction.store.put(record)));
  await transaction.done;
}

export async function getMetadata(key: string): Promise<string | undefined> {
  return (await database()).get("metadata", key);
}

export async function setMetadata(key: string, value: string): Promise<void> {
  await (await database()).put("metadata", value, key);
}

export async function getDeviceId(): Promise<string> {
  const existing = await getMetadata("deviceId");
  if (existing) return existing;
  const created = crypto.randomUUID();
  await setMetadata("deviceId", created);
  return created;
}

export async function getSyncConfiguration(): Promise<SyncConfiguration> {
  const value = await getMetadata("syncConfiguration");
  if (!value) return EMPTY_SYNC_CONFIGURATION;
  try {
    const parsed = JSON.parse(value) as Partial<SyncConfiguration>;
    return { ...EMPTY_SYNC_CONFIGURATION, ...parsed };
  } catch {
    return EMPTY_SYNC_CONFIGURATION;
  }
}

export async function setSyncConfiguration(configuration: SyncConfiguration): Promise<void> {
  await setMetadata("syncConfiguration", JSON.stringify(configuration));
}
