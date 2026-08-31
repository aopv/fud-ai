import {
  ContractValidationError,
  SYNC_LIMITS,
  SYNC_PROTOCOL,
  SYNC_PROTOCOL_VERSION,
  SYNC_RECORD_AAD_DOMAIN_V1,
  compareRecordVersionsLww,
  parseSyncPullRequestV1,
  parseSyncPushRequestV1,
  parseSyncRecordEnvelopeV1,
  parseSyncServerInfoV1,
  serializeSyncRecordAadV1,
  selectLwwWinner,
  validateSyncPullResponseV1,
  validateSyncPushResponseV1,
  validateSyncRecordEnvelopeV1,
  type SyncRecordEnvelopeV1,
} from "../src/index.js";

type Test = { name: string; run: () => void };
const tests: Test[] = [];
const test = (name: string, run: () => void): void => { tests.push({ name, run }); };

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertThrows(run: () => void, errorType: new (...args: never[]) => Error): void {
  try {
    run();
  } catch (error: unknown) {
    assert(error instanceof errorType, `expected ${errorType.name}`);
    return;
  }
  throw new Error(`expected ${errorType.name} to be thrown`);
}

const record = (overrides: Partial<SyncRecordEnvelopeV1> = {}): SyncRecordEnvelopeV1 => ({
  protocolVersion: 1,
  recordId: "food.018f",
  namespace: "diary.food",
  version: {
    updatedAt: "2026-08-31T10:00:00.000Z",
    revision: 3,
    deviceId: "device-ios-1",
    mutationId: "mutation-003",
  },
  deleted: false,
  payload: {
    algorithm: "AES-256-GCM",
    keyId: "key-main-1",
    nonce: "AAECAwQFBgcICQoL",
    ciphertext: "AAECAwQFBgcICQoLDA0ODxAREhM",
  },
  ...overrides,
});

test("accepts a valid encrypted record", () => {
  const parsed = parseSyncRecordEnvelopeV1(record());
  assert(parsed.recordId === "food.018f");
  assert(parsed.payload.algorithm === "AES-256-GCM");
});

test("requires encrypted payloads for tombstones", () => {
  const parsed = parseSyncRecordEnvelopeV1(record({ deleted: true }));
  assert(parsed.deleted && parsed.payload.algorithm === "AES-256-GCM");
});

test("rejects plaintext-shaped payloads and unknown fields", () => {
  const candidate = { ...record(), plaintext: { calories: 500 } };
  const result = validateSyncRecordEnvelopeV1(candidate);
  assert(!result.success);
  assert(result.issues.some((item) => item.message.includes("unknown field")));
});

test("requires ciphertext for both live records and tombstones", () => {
  assert(!validateSyncRecordEnvelopeV1({ ...record(), payload: null }).success);
  assert(!validateSyncRecordEnvelopeV1({ ...record({ deleted: true }), payload: null }).success);
});

test("rejects non-canonical timestamps, bad nonces, and invalid namespaces", () => {
  const badTimestamp = record({ version: { ...record().version, updatedAt: "2026-08-31T10:00:00Z" } });
  const badNonce = record({ payload: { ...record().payload, nonce: "short" } });
  const badNamespace = record({ namespace: "Diary Food" });
  assert(!validateSyncRecordEnvelopeV1(badTimestamp).success);
  assert(!validateSyncRecordEnvelopeV1(badNonce).success);
  assert(!validateSyncRecordEnvelopeV1(badNamespace).success);
});

test("serializes every security and conflict field into deterministic AAD", () => {
  const envelope = record();
  const aad = serializeSyncRecordAadV1({
    protocolVersion: envelope.protocolVersion,
    recordId: envelope.recordId,
    namespace: envelope.namespace,
    version: envelope.version,
    deleted: envelope.deleted,
    keyId: envelope.payload.keyId,
  });
  assert(aad === JSON.stringify([
    SYNC_RECORD_AAD_DOMAIN_V1,
    1,
    "food.018f",
    "diary.food",
    "2026-08-31T10:00:00.000Z",
    3,
    "device-ios-1",
    "mutation-003",
    false,
    "key-main-1",
  ]));
});

test("validates server discovery information", () => {
  const info = parseSyncServerInfoV1({
    protocol: SYNC_PROTOCOL,
    protocolVersion: SYNC_PROTOCOL_VERSION,
    minSupportedProtocolVersion: 1,
    serverTime: "2026-08-31T11:00:00.000Z",
    limits: {
      maxBatchRecords: 100,
      maxCiphertextBytes: 1_000_000,
      maxRequestBytes: 10_000_000,
    },
    capabilities: { push: true, pull: true, tombstones: true },
  });
  assert(info.protocol === SYNC_PROTOCOL);
});

test("validates push and pull wire messages", () => {
  const push = parseSyncPushRequestV1({
    protocolVersion: 1,
    requestId: "request-1",
    deviceId: "device-ios-1",
    records: [record()],
  });
  assert(push.records.length === 1);
  assert(parseSyncPullRequestV1({ protocolVersion: 1, cursor: "cursor-1", limit: 50 }).limit === 50);

  assert(validateSyncPushResponseV1({
    protocolVersion: 1,
    requestId: "request-1",
    serverTime: "2026-08-31T11:00:00.000Z",
    acceptedRecordIds: ["food.018f"],
    conflicts: [],
    rejected: [],
    cursor: "cursor-2",
  }).success);
  assert(validateSyncPullResponseV1({
    protocolVersion: 1,
    serverTime: "2026-08-31T11:00:00.000Z",
    records: [record()],
    cursor: "cursor-2",
    hasMore: false,
  }).success);
});

test("rejects duplicate globally scoped record IDs across namespaces", () => {
  const result = validateSyncPushResponseV1({
    protocolVersion: 1,
    requestId: "request-duplicates",
    serverTime: "2026-08-31T11:00:00.000Z",
    acceptedRecordIds: ["food.018f"],
    conflicts: [],
    rejected: [],
    cursor: "cursor-2",
  });
  assert(result.success);

  assertThrows(() => parseSyncPushRequestV1({
    protocolVersion: 1,
    requestId: "request-duplicates",
    deviceId: "device-ios-1",
    records: [record(), record({ namespace: "diary.water" })],
  }), ContractValidationError);
});

test("enforces batch and pull limits", () => {
  assertThrows(() => parseSyncPullRequestV1({ protocolVersion: 1, limit: SYNC_LIMITS.maxBatchRecords + 1 }), ContractValidationError);
  const tooMany = Array.from({ length: SYNC_LIMITS.maxBatchRecords + 1 }, () => record());
  assertThrows(() => parseSyncPushRequestV1({
    protocolVersion: 1,
    requestId: "request-2",
    deviceId: "device-ios-1",
    records: tooMany,
  }), ContractValidationError);
});

test("LWW comparison is deterministic across every tie-break", () => {
  const base = record();
  const later = record({
    recordId: base.recordId,
    version: { ...base.version, updatedAt: "2026-08-31T10:00:01.000Z", mutationId: "mutation-001" },
  });
  assert(compareRecordVersionsLww(later.version, base.version) > 0);
  assert(selectLwwWinner(base, later) === later);

  const higherRevision = record({ version: { ...base.version, revision: 4, mutationId: "mutation-001" } });
  assert(compareRecordVersionsLww(higherRevision.version, base.version) > 0);
  const higherDevice = record({ version: { ...base.version, deviceId: "device-z", mutationId: "mutation-001" } });
  assert(compareRecordVersionsLww(higherDevice.version, base.version) > 0);
  const higherMutation = record({ version: { ...base.version, mutationId: "mutation-999" } });
  assert(compareRecordVersionsLww(higherMutation.version, base.version) > 0);
  assert(compareRecordVersionsLww(base.version, base.version) === 0);
});

const failures: string[] = [];
for (const item of tests) {
  try {
    item.run();
  } catch (error: unknown) {
    failures.push(`${item.name}: ${error instanceof Error ? error.message : String(error)}`);
  }
}
if (failures.length > 0) throw new Error(failures.join("\n"));
