import type { StoragePullResult, StoragePushResult, SyncStorage } from "@fud-ai/server-core";
import type { SyncRecordEnvelopeV1 } from "@fud-ai/sync-contracts";
import type { D1DatabaseLike, D1Result } from "./d1-types.js";

interface RecordRow {
  record_id: string;
  namespace_name: string;
  updated_at: string;
  revision: number;
  device_id: string;
  mutation_id: string;
  deleted: number;
  algorithm: "AES-256-GCM";
  key_id: string;
  nonce: string;
  ciphertext: string;
}
interface ChangeRow extends RecordRow { sequence: number }

function fromRow(row: RecordRow): SyncRecordEnvelopeV1 {
  const payload = {
    algorithm: row.algorithm,
    keyId: row.key_id,
    nonce: row.nonce,
    ciphertext: row.ciphertext,
  };
  return {
    protocolVersion: 1,
    recordId: row.record_id,
    namespace: row.namespace_name,
    version: {
      updatedAt: row.updated_at,
      revision: row.revision,
      deviceId: row.device_id,
      mutationId: row.mutation_id,
    },
    deleted: row.deleted !== 0,
    payload,
  };
}

const SELECT_RECORD = `
  SELECT record_id, namespace_name, updated_at, revision, device_id, mutation_id,
         deleted, algorithm, key_id, nonce, ciphertext
  FROM sync_records WHERE record_id = ?
`;

/**
 * Canonical timestamps and portable identifiers are ASCII, so SQLite's BINARY
 * collation has the same ordering as compareRecordVersionsLww's code-unit
 * comparison. Namespace is immutable for a globally unique record id.
 */
const UPSERT_RECORD_IF_LWW_WINNER = `
  INSERT INTO sync_records
    (record_id, namespace_name, updated_at, revision, device_id, mutation_id,
     deleted, algorithm, key_id, nonce, ciphertext)
  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ON CONFLICT(record_id) DO UPDATE SET
    namespace_name = excluded.namespace_name, updated_at = excluded.updated_at,
    revision = excluded.revision, device_id = excluded.device_id,
    mutation_id = excluded.mutation_id, deleted = excluded.deleted,
    algorithm = excluded.algorithm, key_id = excluded.key_id,
    nonce = excluded.nonce, ciphertext = excluded.ciphertext
  WHERE sync_records.namespace_name = excluded.namespace_name
    AND (
      excluded.updated_at > sync_records.updated_at
      OR (excluded.updated_at = sync_records.updated_at
        AND excluded.revision > sync_records.revision)
      OR (excluded.updated_at = sync_records.updated_at
        AND excluded.revision = sync_records.revision
        AND excluded.device_id COLLATE BINARY > sync_records.device_id COLLATE BINARY)
      OR (excluded.updated_at = sync_records.updated_at
        AND excluded.revision = sync_records.revision
        AND excluded.device_id = sync_records.device_id
        AND excluded.mutation_id COLLATE BINARY > sync_records.mutation_id COLLATE BINARY)
    )
`;

const INSERT_CHANGE_IF_RECORD_WON = `
  INSERT INTO sync_changes
    (record_id, namespace_name, updated_at, revision, device_id, mutation_id,
     deleted, algorithm, key_id, nonce, ciphertext)
  SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
  WHERE EXISTS (
    SELECT 1 FROM sync_records
    WHERE record_id = ? AND namespace_name = ? AND mutation_id = ?
  )
  ON CONFLICT(mutation_id) DO NOTHING
`;

export class D1SyncStorage implements SyncStorage {
  constructor(private readonly database: D1DatabaseLike) {}

  async health(): Promise<boolean> {
    return (await this.database.prepare("SELECT 1 AS ok").first<{ ok: number }>())?.ok === 1;
  }

  async push(records: readonly SyncRecordEnvelopeV1[]): Promise<StoragePushResult> {
    const acceptedRecordIds: string[] = [];
    const conflicts: SyncRecordEnvelopeV1[] = [];
    const rejected: StoragePushResult["rejected"] = [];
    for (const record of records) {
      if (!(await this.workspaceAcceptsKeyId(record.payload.keyId))) {
        rejected.push({
          recordId: record.recordId,
          code: "invalid_record",
          message: "record uses a different encryption key than this sync workspace",
        });
        continue;
      }
      const duplicate = await this.mutationExists(record.version.mutationId);
      if (duplicate) {
        await this.classifyReplay(record, acceptedRecordIds, conflicts, rejected);
        continue;
      }
      const values: unknown[] = [
        record.recordId,
        record.namespace,
        record.version.updatedAt,
        record.version.revision,
        record.version.deviceId,
        record.version.mutationId,
        record.deleted ? 1 : 0,
        record.payload.algorithm,
        record.payload.keyId,
        record.payload.nonce,
        record.payload.ciphertext,
      ];
      let results: Array<D1Result<RecordRow>>;
      try {
        results = await this.database.batch<RecordRow>([
          // A plain insert makes a concurrently reused mutation id abort and
          // roll back this entire batch instead of creating an untracked row.
          this.database.prepare("INSERT INTO sync_mutations (mutation_id) VALUES (?)")
            .bind(record.version.mutationId),
          this.database.prepare(UPSERT_RECORD_IF_LWW_WINNER).bind(...values),
          this.database.prepare(INSERT_CHANGE_IF_RECORD_WON).bind(
            ...values,
            record.recordId,
            record.namespace,
            record.version.mutationId,
          ),
          this.database.prepare(SELECT_RECORD).bind(record.recordId),
        ]);
      } catch (error) {
        if (!(await this.mutationExists(record.version.mutationId))) throw error;
        await this.classifyReplay(record, acceptedRecordIds, conflicts, rejected);
        continue;
      }
      const winnerRow = results[3]?.results[0];
      if (winnerRow === undefined) throw new Error("LWW conflict winner disappeared");
      const winner = fromRow(winnerRow);
      if (winner.namespace === record.namespace
          && winner.version.mutationId === record.version.mutationId) {
        acceptedRecordIds.push(record.recordId);
      } else {
        conflicts.push(winner);
      }
    }
    return { acceptedRecordIds, conflicts, rejected, cursor: await this.currentCursor() };
  }

  async pull(cursor: string | null, limit: number): Promise<StoragePullResult> {
    const after = cursor === null ? 0 : Number(cursor);
    if (!Number.isSafeInteger(after) || after < 0) throw new Error("Invalid storage cursor");
    const current = Number(await this.currentCursor());
    // A database restore may move the change sequence behind a persisted
    // client cursor. Restart from zero instead of hiding restored changes.
    const effectiveAfter = after > current ? 0 : after;
    const result = await this.database.prepare(`
      SELECT sequence, record_id, namespace_name, updated_at, revision, device_id,
             mutation_id, deleted, algorithm, key_id, nonce, ciphertext
      FROM sync_changes WHERE sequence > ? ORDER BY sequence ASC LIMIT ?
    `).bind(effectiveAfter, limit + 1).all<ChangeRow>();
    const hasMore = result.results.length > limit;
    const page = result.results.slice(0, limit);
    return {
      records: page.map(fromRow),
      cursor: String(page.at(-1)?.sequence ?? effectiveAfter),
      hasMore,
    };
  }

  private async currentCursor(): Promise<string> {
    const row = await this.database.prepare(
      "SELECT COALESCE(MAX(sequence), 0) AS cursor FROM sync_changes",
    ).first<{ cursor: number }>();
    return String(row?.cursor ?? 0);
  }

  private async workspaceAcceptsKeyId(keyId: string): Promise<boolean> {
    const results = await this.database.batch<{ metadata_value: string }>([
      this.database.prepare(`
        INSERT OR IGNORE INTO sync_metadata (metadata_key, metadata_value)
        VALUES ('workspace_key_id', ?)
      `).bind(keyId),
      this.database.prepare(`
        SELECT metadata_value FROM sync_metadata WHERE metadata_key = 'workspace_key_id'
      `),
    ]);
    return results[1]?.results[0]?.metadata_value === keyId;
  }

  private async mutationExists(mutationId: string): Promise<boolean> {
    return await this.database.prepare(
      "SELECT 1 AS found FROM sync_mutations WHERE mutation_id = ? LIMIT 1",
    ).bind(mutationId).first<{ found: number }>() !== null;
  }

  private async classifyReplay(
    record: SyncRecordEnvelopeV1,
    acceptedRecordIds: string[],
    conflicts: SyncRecordEnvelopeV1[],
    rejected: StoragePushResult["rejected"],
  ): Promise<void> {
    const currentRow = await this.database.prepare(SELECT_RECORD)
      .bind(record.recordId)
      .first<RecordRow>();
    if (currentRow === null) {
      rejected.push({
        recordId: record.recordId,
        code: "invalid_record",
        message: "mutationId has already been used by another record",
      });
      return;
    }
    const current = fromRow(currentRow);
    if (current.namespace === record.namespace
        && current.version.mutationId === record.version.mutationId) {
      acceptedRecordIds.push(record.recordId);
    } else {
      conflicts.push(current);
    }
  }
}

export type { D1DatabaseLike } from "./d1-types.js";
