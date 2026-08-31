import type { StoragePullResult, StoragePushResult, SyncStorage } from "@fud-ai/server-core";
import type { SyncRecordEnvelopeV1 } from "@fud-ai/sync-contracts";
import { Pool, type PoolClient, type PoolConfig } from "pg";

interface RecordRow {
  record_id: string;
  namespace_name: string;
  updated_at: Date | string;
  revision: string;
  device_id: string;
  mutation_id: string;
  deleted: boolean;
  algorithm: "AES-256-GCM";
  key_id: string;
  nonce: string;
  ciphertext: string;
}
interface ChangeRow extends RecordRow { sequence: string }

function fromRow(row: RecordRow): SyncRecordEnvelopeV1 {
  return {
    protocolVersion: 1,
    recordId: row.record_id,
    namespace: row.namespace_name,
    version: {
      updatedAt: row.updated_at instanceof Date ? row.updated_at.toISOString() : row.updated_at,
      revision: Number(row.revision),
      deviceId: row.device_id,
      mutationId: row.mutation_id,
    },
    deleted: row.deleted,
    payload: {
      algorithm: row.algorithm,
      keyId: row.key_id,
      nonce: row.nonce,
      ciphertext: row.ciphertext,
    },
  };
}

const RECORD_COLUMNS = `record_id, namespace_name, updated_at, revision::text, device_id,
  mutation_id, deleted, algorithm, key_id, nonce, ciphertext`;
const PUSH_SERIALIZATION_LOCK = "507544414953594";

type PushOneResult =
  | { kind: "accepted" }
  | { kind: "conflict"; record: SyncRecordEnvelopeV1 }
  | { kind: "rejected"; message: string };

export class PostgresSyncStorage implements SyncStorage {
  readonly pool: Pool;
  constructor(configOrPool: PoolConfig | Pool) {
    this.pool = configOrPool instanceof Pool ? configOrPool : new Pool(configOrPool);
  }

  async health(): Promise<boolean> {
    return (await this.pool.query<{ ok: number }>("SELECT 1 AS ok")).rows[0]?.ok === 1;
  }

  async push(records: readonly SyncRecordEnvelopeV1[]): Promise<StoragePushResult> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      // PostgreSQL identity values are allocated before commit. Serializing
      // push transactions guarantees sequence order is also commit order, so a
      // pull cursor can never jump over a still-uncommitted lower sequence.
      await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [PUSH_SERIALIZATION_LOCK]);
      const acceptedRecordIds: string[] = [];
      const conflicts: SyncRecordEnvelopeV1[] = [];
      const rejected: StoragePushResult["rejected"] = [];
      for (const record of records) {
        if (!(await this.workspaceAcceptsKeyId(client, record.payload.keyId))) {
          rejected.push({
            recordId: record.recordId,
            code: "invalid_record",
            message: "record uses a different encryption key than this sync workspace",
          });
          continue;
        }
        const outcome = await this.pushOne(client, record);
        if (outcome.kind === "accepted") acceptedRecordIds.push(record.recordId);
        else if (outcome.kind === "conflict") conflicts.push(outcome.record);
        else rejected.push({ recordId: record.recordId, code: "invalid_record", message: outcome.message });
      }
      const cursorResult = await client.query<{ cursor: string }>(
        "SELECT COALESCE(MAX(sequence), 0)::text AS cursor FROM sync_changes",
      );
      await client.query("COMMIT");
      return {
        acceptedRecordIds,
        conflicts,
        rejected,
        cursor: cursorResult.rows[0]?.cursor ?? "0",
      };
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }

  private async pushOne(
    client: PoolClient,
    record: SyncRecordEnvelopeV1,
  ): Promise<PushOneResult> {
    const mutation = await client.query(
      "INSERT INTO sync_mutations (mutation_id) VALUES ($1) ON CONFLICT DO NOTHING RETURNING mutation_id",
      [record.version.mutationId],
    );
    if (mutation.rowCount !== 1) {
      const current = await client.query<RecordRow>(
        `SELECT ${RECORD_COLUMNS} FROM sync_records WHERE record_id = $1`,
        [record.recordId],
      );
      const winner = current.rows[0];
      if (winner === undefined) {
        return { kind: "rejected", message: "mutationId has already been used by another record" };
      }
      const envelope = fromRow(winner);
      return envelope.namespace === record.namespace
          && envelope.version.mutationId === record.version.mutationId
        ? { kind: "accepted" }
        : { kind: "conflict", record: envelope };
    }
    const values = [
      record.recordId, record.namespace, record.version.updatedAt, record.version.revision,
      record.version.deviceId, record.version.mutationId, record.deleted,
      record.payload.algorithm, record.payload.keyId,
      record.payload.nonce, record.payload.ciphertext,
    ];
    // Explicit branches mirror compareRecordVersionsLww. "C" is required for
    // the portable ASCII identifiers because a database's locale collation can
    // otherwise order punctuation and case differently from JavaScript.
    const upsert = await client.query<RecordRow>(`
      INSERT INTO sync_records
        (record_id, namespace_name, updated_at, revision, device_id, mutation_id,
         deleted, algorithm, key_id, nonce, ciphertext)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      ON CONFLICT(record_id) DO UPDATE SET
        namespace_name = EXCLUDED.namespace_name, updated_at = EXCLUDED.updated_at,
        revision = EXCLUDED.revision, device_id = EXCLUDED.device_id,
        mutation_id = EXCLUDED.mutation_id, deleted = EXCLUDED.deleted,
        algorithm = EXCLUDED.algorithm, key_id = EXCLUDED.key_id,
        nonce = EXCLUDED.nonce, ciphertext = EXCLUDED.ciphertext
      WHERE sync_records.namespace_name COLLATE "C" = EXCLUDED.namespace_name COLLATE "C"
        AND (
          EXCLUDED.updated_at > sync_records.updated_at
          OR (EXCLUDED.updated_at = sync_records.updated_at
            AND EXCLUDED.revision > sync_records.revision)
          OR (EXCLUDED.updated_at = sync_records.updated_at
            AND EXCLUDED.revision = sync_records.revision
            AND EXCLUDED.device_id COLLATE "C" > sync_records.device_id COLLATE "C")
          OR (EXCLUDED.updated_at = sync_records.updated_at
            AND EXCLUDED.revision = sync_records.revision
            AND EXCLUDED.device_id COLLATE "C" = sync_records.device_id COLLATE "C"
            AND EXCLUDED.mutation_id COLLATE "C" > sync_records.mutation_id COLLATE "C")
        )
      RETURNING ${RECORD_COLUMNS}
    `, values);

    if (upsert.rowCount !== 1) {
      const current = await client.query<RecordRow>(
        `SELECT ${RECORD_COLUMNS} FROM sync_records WHERE record_id = $1`,
        [record.recordId],
      );
      const winner = current.rows[0];
      if (winner === undefined) throw new Error("LWW conflict winner disappeared");
      return { kind: "conflict", record: fromRow(winner) };
    }
    await client.query(`
      INSERT INTO sync_changes
        (record_id, namespace_name, updated_at, revision, device_id, mutation_id,
         deleted, algorithm, key_id, nonce, ciphertext)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    `, values);
    return { kind: "accepted" };
  }

  private async workspaceAcceptsKeyId(client: PoolClient, keyId: string): Promise<boolean> {
    await client.query(`
      INSERT INTO sync_metadata (metadata_key, metadata_value)
      VALUES ('workspace_key_id', $1)
      ON CONFLICT(metadata_key) DO NOTHING
    `, [keyId]);
    const pinned = await client.query<{ metadata_value: string }>(`
      SELECT metadata_value FROM sync_metadata WHERE metadata_key = 'workspace_key_id'
    `);
    return pinned.rows[0]?.metadata_value === keyId;
  }

  async pull(cursor: string | null, limit: number): Promise<StoragePullResult> {
    const after = cursor ?? "0";
    if (!/^\d+$/.test(after)) throw new Error("Invalid storage cursor");
    const currentResult = await this.pool.query<{ cursor: string }>(
      "SELECT COALESCE(MAX(sequence), 0)::text AS cursor FROM sync_changes",
    );
    const current = currentResult.rows[0]?.cursor ?? "0";
    const effectiveAfter = BigInt(after) > BigInt(current) ? "0" : after;
    const result = await this.pool.query<ChangeRow>(`
      SELECT sequence::text, ${RECORD_COLUMNS}
      FROM sync_changes WHERE sequence > $1::bigint ORDER BY sequence ASC LIMIT $2
    `, [effectiveAfter, limit + 1]);
    const hasMore = result.rows.length > limit;
    const page = result.rows.slice(0, limit);
    return {
      records: page.map(fromRow),
      cursor: page.at(-1)?.sequence ?? effectiveAfter,
      hasMore,
    };
  }

  async close(): Promise<void> { await this.pool.end(); }
}
