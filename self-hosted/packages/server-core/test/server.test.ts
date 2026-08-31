import assert from "node:assert/strict";
import test from "node:test";
import {
  constantTimeTokenEquals,
  createSyncHandler,
  type SyncStorage,
} from "../src/index.js";
import type { SyncRecordEnvelopeV1 } from "@fud-ai/sync-contracts";

const TOKEN = "test-token-that-is-at-least-thirty-two-characters";
const record: SyncRecordEnvelopeV1 = {
  protocolVersion: 1,
  recordId: "food:1",
  namespace: "diary.food",
  version: {
    revision: 1,
    mutationId: "mutation-1",
    updatedAt: new Date(Date.now() - 60_000).toISOString(),
    deviceId: "ios-1",
  },
  deleted: false,
  payload: {
    algorithm: "AES-256-GCM",
    keyId: "key-1",
    nonce: "AAECAwQFBgcICQoL",
    ciphertext: "AAECAwQFBgcICQoLDA0ODxAREhM",
  },
};

function memoryStorage(): SyncStorage {
  const records: SyncRecordEnvelopeV1[] = [];
  return {
    async health() { return true; },
    async push(incoming) {
      records.push(...incoming);
      return {
        acceptedRecordIds: incoming.map((item) => item.recordId),
        conflicts: [],
        rejected: [],
        cursor: String(records.length),
      };
    },
    async pull(cursor) {
      return { records, cursor: cursor ?? String(records.length), hasMore: false };
    },
  };
}

test("constant-time token comparison returns the correct result", async () => {
  assert.equal(await constantTimeTokenEquals(TOKEN, TOKEN), true);
  assert.equal(await constantTimeTokenEquals(`${TOKEN}x`, TOKEN), false);
});

test("health and info do not disclose secrets", async () => {
  const handler = createSyncHandler({ storage: memoryStorage(), bearerToken: TOKEN });
  const health = await handler(new Request("https://sync.example/v1/health"));
  assert.equal(health.status, 200);
  const info = await handler(new Request("https://sync.example/v1/info"));
  assert.equal(info.status, 200);
  assert.equal((await info.text()).includes(TOKEN), false);
});

test("sync endpoints require authorization and accept valid encrypted records", async () => {
  const handler = createSyncHandler({ storage: memoryStorage(), bearerToken: TOKEN });
  const unauthorized = await handler(new Request("https://sync.example/v1/sync/pull", { method: "POST" }));
  assert.equal(unauthorized.status, 401);

  const pushed = await handler(new Request("https://sync.example/v1/sync/push", {
    method: "POST",
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" },
    body: JSON.stringify({
      protocolVersion: 1,
      requestId: "request-1",
      deviceId: "ios-1",
      records: [record],
    }),
  }));
  assert.equal(pushed.status, 200);
  const pushResponse = await pushed.json() as { acceptedRecordIds: string[] };
  assert.deepEqual(pushResponse.acceptedRecordIds, [record.recordId]);

  const pulled = await handler(new Request("https://sync.example/v1/sync/pull", {
    method: "POST",
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" },
    body: JSON.stringify({ protocolVersion: 1, cursor: "0", limit: 10 }),
  }));
  assert.equal(pulled.status, 200);
  const pullResponse = await pulled.json() as { records: SyncRecordEnvelopeV1[] };
  assert.equal(pullResponse.records[0]?.payload.ciphertext, record.payload.ciphertext);
});

test("contract validation rejects plaintext and unknown record fields", async () => {
  const handler = createSyncHandler({ storage: memoryStorage(), bearerToken: TOKEN });
  const invalid = await handler(new Request("https://sync.example/v1/sync/push", {
    method: "POST",
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" },
    body: JSON.stringify({
      protocolVersion: 1,
      requestId: "request-2",
      deviceId: "ios-1",
      records: [{ ...record, plaintext: { calories: 500 } }],
    }),
  }));
  assert.equal(invalid.status, 400);
});

test("future-dated records are rejected without reaching storage", async () => {
  const received: SyncRecordEnvelopeV1[] = [];
  const storage = memoryStorage();
  const handler = createSyncHandler({
    storage: {
      ...storage,
      async push(incoming) {
        received.push(...incoming);
        return storage.push(incoming);
      },
    },
    bearerToken: TOKEN,
  });
  const futureRecord: SyncRecordEnvelopeV1 = {
    ...record,
    recordId: "food:future",
    version: {
      ...record.version,
      mutationId: "mutation-future",
      updatedAt: new Date(Date.now() + 11 * 60 * 1000).toISOString(),
    },
  };
  const response = await handler(new Request("https://sync.example/v1/sync/push", {
    method: "POST",
    headers: { authorization: `Bearer ${TOKEN}`, "content-type": "application/json" },
    body: JSON.stringify({
      protocolVersion: 1,
      requestId: "request-future",
      deviceId: "ios-1",
      records: [record, futureRecord],
    }),
  }));

  assert.equal(response.status, 200);
  assert.deepEqual(received.map((item) => item.recordId), [record.recordId]);
  const body = await response.json() as {
    acceptedRecordIds: string[];
    rejected: Array<{ recordId: string; code: string }>;
  };
  assert.deepEqual(body.acceptedRecordIds, [record.recordId]);
  assert.deepEqual(body.rejected, [{ recordId: futureRecord.recordId, code: "invalid_record", message: "updatedAt is more than 10 minutes ahead of server time" }]);
});

test("CORS is restricted to configured origins", async () => {
  const handler = createSyncHandler({
    storage: memoryStorage(),
    bearerToken: TOKEN,
    allowedOrigins: ["https://app.example"],
  });
  const allowed = await handler(new Request("https://sync.example/v1/info", {
    headers: { origin: "https://app.example" },
  }));
  assert.equal(allowed.headers.get("access-control-allow-origin"), "https://app.example");
  const denied = await handler(new Request("https://sync.example/v1/info", {
    headers: { origin: "https://evil.example" },
  }));
  assert.equal(denied.headers.get("access-control-allow-origin"), null);
});
