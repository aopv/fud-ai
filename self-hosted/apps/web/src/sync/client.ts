import {
  parseSyncPullResponseV1,
  parseSyncPushResponseV1,
  parseSyncServerInfoV1,
  SYNC_PROTOCOL_VERSION,
  type SyncRecordEnvelopeV1,
  type SyncServerInfoV1,
} from "@fud-ai/sync-contracts";
import type { LocalEntity, SyncConfiguration } from "../domain";
import { decryptEnvelope, encryptEntity } from "./crypto";

const encoder = new TextEncoder();
const REQUEST_ID_PLACEHOLDER = "00000000-0000-4000-8000-000000000000";
const REQUEST_TIMEOUT_MS = 30_000;
const MAX_PULL_PAGES = 10_000;

function endpoint(base: string, path: string): string {
  const normalized = (base.trim() || window.location.origin).replace(/\/+$/u, "");
  return `${normalized}${path}`;
}

async function readJson(response: Response): Promise<unknown> {
  const body = await response.json().catch(() => null) as unknown;
  if (!response.ok) {
    const message = typeof body === "object" && body !== null && "error" in body
      ? JSON.stringify((body as { error: unknown }).error)
      : `HTTP ${response.status}`;
    throw new Error(`Sync server rejected the request: ${message}`);
  }
  return body;
}

async function fetchSync(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeout = globalThis.setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (controller.signal.aborted) throw new Error("Sync request timed out");
    throw error;
  } finally {
    globalThis.clearTimeout(timeout);
  }
}

export async function testSyncServer(configuration: SyncConfiguration): Promise<SyncServerInfoV1> {
  const response = await fetchSync(endpoint(configuration.endpoint, "/v1/info"), {
    headers: { accept: "application/json" },
  });
  return parseSyncServerInfoV1(await readJson(response));
}

export interface SyncResult {
  records: LocalEntity[];
  cursor: string;
  acceptedCount: number;
  rejectedCount: number;
  rejectionMessage: string;
  skippedCount: number;
}

function serializePush(
  records: readonly SyncRecordEnvelopeV1[],
  deviceId: string,
  requestId: string,
): string {
  return JSON.stringify({
    protocolVersion: SYNC_PROTOCOL_VERSION,
    requestId,
    deviceId,
    records,
  });
}

function partitionPushRecords(
  records: readonly SyncRecordEnvelopeV1[],
  serverInfo: SyncServerInfoV1,
  deviceId: string,
): SyncRecordEnvelopeV1[][] {
  const batches: SyncRecordEnvelopeV1[][] = [];
  let current: SyncRecordEnvelopeV1[] = [];

  for (const record of records) {
    const ciphertextBytes = Math.floor(record.payload.ciphertext.length * 3 / 4);
    if (ciphertextBytes > serverInfo.limits.maxCiphertextBytes) {
      throw new Error(`Encrypted record ${record.recordId} exceeds the server ciphertext limit`);
    }

    const candidate = [...current, record];
    const exceedsCount = candidate.length > serverInfo.limits.maxBatchRecords;
    const exceedsBytes = encoder.encode(serializePush(candidate, deviceId, REQUEST_ID_PLACEHOLDER)).byteLength
      > serverInfo.limits.maxRequestBytes;
    if (!exceedsCount && !exceedsBytes) {
      current = candidate;
      continue;
    }

    if (current.length === 0) {
      throw new Error(`Encrypted record ${record.recordId} cannot fit within the server request limit`);
    }
    batches.push(current);
    current = [record];
    if (encoder.encode(serializePush(current, deviceId, REQUEST_ID_PLACEHOLDER)).byteLength
        > serverInfo.limits.maxRequestBytes) {
      throw new Error(`Encrypted record ${record.recordId} cannot fit within the server request limit`);
    }
  }

  if (current.length > 0) batches.push(current);
  return batches;
}

export async function synchronize(
  localRecords: readonly LocalEntity[],
  configuration: SyncConfiguration,
  deviceId: string,
): Promise<SyncResult> {
  if (!configuration.enabled) throw new Error("Encrypted sync is not enabled");
  if (configuration.accessToken.length < 32) throw new Error("The sync access token must contain at least 32 characters");
  if (!configuration.encryptionKey || !configuration.keyId) throw new Error("Create or import a pairing key first");
  assertGloballyUniqueRecordIds(localRecords);

  const serverInfo = await testSyncServer(configuration);
  const encrypted = await Promise.all(
    localRecords.map((record) => encryptEntity(record, configuration.encryptionKey, configuration.keyId)),
  );
  const remoteEnvelopes: SyncRecordEnvelopeV1[] = [];
  let acceptedCount = 0;
  let rejectedCount = 0;
  let rejectionMessage = "";
  const pushBatches = partitionPushRecords(encrypted, serverInfo, deviceId);
  for (const records of pushBatches) {
    const requestId = crypto.randomUUID();
    const pushResponse = await fetchSync(endpoint(configuration.endpoint, "/v1/sync/push"), {
      method: "POST",
      headers: {
        authorization: `Bearer ${configuration.accessToken}`,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: serializePush(records, deviceId, requestId),
    });
    const pushed = parseSyncPushResponseV1(await readJson(pushResponse));
    acceptedCount += pushed.acceptedRecordIds.length;
    rejectedCount += pushed.rejected.length;
    rejectionMessage ||= pushed.rejected[0]?.message ?? "unknown validation error";
    remoteEnvelopes.push(...pushed.conflicts);
  }

  let cursor = configuration.cursor;
  let hasMore = true;
  let pullPages = 0;
  while (hasMore) {
    if (pullPages >= MAX_PULL_PAGES) throw new Error("Sync pull exceeded the page safety limit");
    pullPages += 1;
    const previousCursor = cursor;
    const pullResponse = await fetchSync(endpoint(configuration.endpoint, "/v1/sync/pull"), {
      method: "POST",
      headers: {
        authorization: `Bearer ${configuration.accessToken}`,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        protocolVersion: SYNC_PROTOCOL_VERSION,
        ...(cursor ? { cursor } : {}),
        limit: 250,
      }),
    });
    const page = parseSyncPullResponseV1(await readJson(pullResponse));
    remoteEnvelopes.push(...page.records);
    cursor = page.cursor;
    hasMore = page.hasMore;
    if (hasMore && cursor === previousCursor) {
      throw new Error("Sync server returned a non-advancing cursor");
    }
  }

  const decrypted = await Promise.allSettled(
    remoteEnvelopes.map((record) => decryptEnvelope(
      record,
      configuration.encryptionKey,
      configuration.keyId,
    )),
  );
  const records = decrypted.flatMap((result) => result.status === "fulfilled" ? [result.value] : []);
  const skippedCount = decrypted.length - records.length;
  return {
    records,
    cursor: skippedCount > 0 ? configuration.cursor : cursor,
    acceptedCount,
    rejectedCount,
    rejectionMessage,
    skippedCount,
  };
}

function assertGloballyUniqueRecordIds(records: readonly LocalEntity[]): void {
  const namespaceByRecordId = new Map<string, string>();
  for (const record of records) {
    const previousNamespace = namespaceByRecordId.get(record.recordId);
    if (previousNamespace !== undefined) {
      throw new Error(
        `Record ID ${record.recordId} is duplicated across ${previousNamespace} and ${record.namespace}; record IDs must be globally unique`,
      );
    }
    namespaceByRecordId.set(record.recordId, record.namespace);
  }
}
