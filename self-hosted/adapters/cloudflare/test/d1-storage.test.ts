import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { DatabaseSync, type SQLInputValue } from "node:sqlite";
import test from "node:test";
import type { SyncRecordEnvelopeV1 } from "@fud-ai/sync-contracts";
import {
  D1SyncStorage,
  type D1DatabaseLike,
} from "../src/index.js";
import type { D1PreparedStatement, D1Result } from "../src/d1-types.js";

class SqliteStatement implements D1PreparedStatement {
  constructor(
    private readonly database: DatabaseSync,
    private readonly query: string,
    private readonly values: readonly unknown[] = [],
  ) {}

  bind(...values: unknown[]): D1PreparedStatement {
    return new SqliteStatement(this.database, this.query, values);
  }

  async first<T = unknown>(): Promise<T | null> {
    const row = this.database.prepare(this.query).get(...this.sqliteValues());
    return row === undefined ? null : row as T;
  }

  async all<T = unknown>(): Promise<D1Result<T>> {
    return this.execute<T>();
  }

  async run<T = unknown>(): Promise<D1Result<T>> {
    return this.execute<T>();
  }

  execute<T>(): D1Result<T> {
    const results = this.database.prepare(this.query).all(...this.sqliteValues()) as T[];
    const changes = this.database.prepare("SELECT changes() AS count").get()?.count;
    return { success: true, results, meta: { changes: Number(changes ?? 0) } };
  }

  private sqliteValues(): SQLInputValue[] {
    return this.values.map((value) => {
      if (value === null
          || typeof value === "string"
          || typeof value === "number"
          || typeof value === "bigint") return value;
      throw new TypeError("Test D1 received a value unsupported by SQLite");
    });
  }
}

class SqliteD1Database implements D1DatabaseLike {
  readonly database = new DatabaseSync(":memory:");

  constructor() {
    const migration = readFileSync(
      new URL("../migrations/0001_init.sql", import.meta.url),
      "utf8",
    );
    this.database.exec(migration);
  }

  prepare(query: string): D1PreparedStatement {
    return new SqliteStatement(this.database, query);
  }

  async batch<T = unknown>(statements: D1PreparedStatement[]): Promise<Array<D1Result<T>>> {
    this.database.exec("BEGIN IMMEDIATE");
    try {
      const results = statements.map((statement) => {
        if (!(statement instanceof SqliteStatement)) throw new Error("Unexpected statement implementation");
        return statement.execute<T>();
      });
      this.database.exec("COMMIT");
      return results;
    } catch (error) {
      this.database.exec("ROLLBACK");
      throw error;
    }
  }
}

const payload = {
  algorithm: "AES-256-GCM" as const,
  keyId: "key-1",
  nonce: "AAECAwQFBgcICQoL",
  ciphertext: "AAECAwQFBgcICQoLDA0ODxAREhM",
};

function record(
  mutationId: string,
  updatedAt: string,
  overrides: Partial<SyncRecordEnvelopeV1> = {},
): SyncRecordEnvelopeV1 {
  return {
    protocolVersion: 1,
    recordId: "food:1",
    namespace: "diary.food",
    version: { revision: 1, deviceId: "device-a", mutationId, updatedAt },
    deleted: false,
    payload,
    ...overrides,
  };
}

test("D1 applies deterministic LWW atomically and records only actual winners", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const earlier = record("mutation-1", "2026-08-31T10:00:00.000Z");
  const later = record("mutation-2", "2026-08-31T10:01:00.000Z", {
    version: {
      revision: 1,
      deviceId: "device-a",
      mutationId: "mutation-2",
      updatedAt: "2026-08-31T10:01:00.000Z",
    },
  });

  assert.deepEqual((await storage.push([earlier])).acceptedRecordIds, [earlier.recordId]);
  assert.deepEqual((await storage.push([later])).acceptedRecordIds, [later.recordId]);
  const losingResult = await storage.push([
    record("mutation-loser", "2026-08-31T09:59:00.000Z"),
  ]);
  assert.deepEqual(losingResult.acceptedRecordIds, []);
  assert.equal(losingResult.conflicts[0]?.version.mutationId, later.version.mutationId);
  assert.equal(losingResult.cursor, "2");

  const pull = await storage.pull("0", 10);
  assert.deepEqual(
    pull.records.map((item) => item.version.mutationId),
    [earlier.version.mutationId, later.version.mutationId],
  );
});

test("D1 uses binary ID tie-breaks and does not allow namespace migration", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const timestamp = "2026-08-31T10:00:00.000Z";
  const first = record("mutation-a", timestamp);
  const deviceWinner = record("mutation-b", timestamp, {
    version: { ...first.version, deviceId: "device-b", mutationId: "mutation-b" },
  });
  const mutationWinner = record("mutation-z", timestamp, {
    version: { ...first.version, deviceId: "device-b", mutationId: "mutation-z" },
  });

  await storage.push([first]);
  assert.deepEqual((await storage.push([deviceWinner])).acceptedRecordIds, [first.recordId]);
  assert.deepEqual((await storage.push([mutationWinner])).acceptedRecordIds, [first.recordId]);

  const movedNamespace = record("mutation-zz", "2026-08-31T11:00:00.000Z", {
    namespace: "diary.water",
    version: {
      revision: 2,
      deviceId: "device-z",
      mutationId: "mutation-zz",
      updatedAt: "2026-08-31T11:00:00.000Z",
    },
  });
  const result = await storage.push([movedNamespace]);
  assert.deepEqual(result.acceptedRecordIds, []);
  assert.equal(result.conflicts[0]?.namespace, first.namespace);
  assert.equal(result.cursor, "3");
});

test("D1 preserves encrypted tombstone payloads and replay is idempotent", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const tombstone = record("mutation-delete", "2026-08-31T12:00:00.000Z", {
    deleted: true,
    payload: { ...payload, ciphertext: "dG9tYnN0b25lLWNpcGhlcnRleHQ" },
  });

  assert.deepEqual((await storage.push([tombstone])).acceptedRecordIds, [tombstone.recordId]);
  assert.deepEqual((await storage.push([tombstone])).acceptedRecordIds, [tombstone.recordId]);
  const pull = await storage.pull("0", 10);
  assert.equal(pull.records.length, 1);
  assert.equal(pull.records[0]?.deleted, true);
  assert.equal(pull.records[0]?.payload.ciphertext, tombstone.payload.ciphertext);
});

test("D1 rejects a mutation id reused for a different record", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const first = record("mutation-reused", "2026-08-31T12:00:00.000Z");
  const reused = record("mutation-reused", "2026-08-31T13:00:00.000Z", {
    recordId: "food:2",
    version: {
      revision: 1,
      deviceId: "device-b",
      mutationId: "mutation-reused",
      updatedAt: "2026-08-31T13:00:00.000Z",
    },
  });

  await storage.push([first]);
  const result = await storage.push([reused]);
  assert.deepEqual(result.acceptedRecordIds, []);
  assert.deepEqual(result.rejected, [{
    recordId: reused.recordId,
    code: "invalid_record",
    message: "mutationId has already been used by another record",
  }]);
  assert.equal((await storage.pull("0", 10)).records.length, 1);
});

test("D1 pins one encryption key id for the workspace", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const first = record("mutation-key-a", "2026-08-31T12:00:00.000Z");
  const wrongKey = record("mutation-key-b", "2026-08-31T13:00:00.000Z", {
    recordId: "food:2",
    payload: { ...payload, keyId: "key-2" },
    version: {
      revision: 1,
      deviceId: "device-b",
      mutationId: "mutation-key-b",
      updatedAt: "2026-08-31T13:00:00.000Z",
    },
  });

  await storage.push([first]);
  const result = await storage.push([wrongKey]);
  assert.deepEqual(result.rejected, [{
    recordId: wrongKey.recordId,
    code: "invalid_record",
    message: "record uses a different encryption key than this sync workspace",
  }]);
  assert.equal((await storage.pull("0", 10)).records.length, 1);
});

test("D1 restarts a pull when a restored database is behind the client cursor", async () => {
  const storage = new D1SyncStorage(new SqliteD1Database());
  const first = record("mutation-restore", "2026-08-31T12:00:00.000Z");
  await storage.push([first]);
  const result = await storage.pull("99", 10);
  assert.equal(result.records[0]?.recordId, first.recordId);
  assert.equal(result.cursor, "1");
});
