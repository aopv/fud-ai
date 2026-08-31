import { afterEach, describe, expect, it, vi } from "vitest";
import { SYNC_PROTOCOL, SYNC_PROTOCOL_VERSION } from "@fud-ai/sync-contracts";
import type { LocalEntity, SyncConfiguration } from "../domain";
import { encryptEntity, generateEncryptionMaterial } from "./crypto";
import { synchronize } from "./client";

const serverTime = "2026-08-31T00:00:00.000Z";

describe("encrypted sync client", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("chunks pushes to the server-advertised record limit", async () => {
    const material = await generateEncryptionMaterial();
    const configuration: SyncConfiguration = {
      endpoint: "https://sync.example.test",
      accessToken: "a".repeat(32),
      ...material,
      cursor: "",
      enabled: true,
    };
    const records: LocalEntity[] = Array.from({ length: 205 }, (_, index) => ({
      recordId: `food-${index}`,
      namespace: "food.logs",
      deleted: false,
      data: { name: `Meal ${index}` },
      version: {
        updatedAt: serverTime,
        revision: 1,
        deviceId: "test-device",
        mutationId: `mutation-${index}`,
      },
    }));
    const pushedBatchSizes: number[] = [];

    vi.stubGlobal("fetch", vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (url.endsWith("/v1/info")) {
        return Response.json({
          protocol: SYNC_PROTOCOL,
          protocolVersion: SYNC_PROTOCOL_VERSION,
          minSupportedProtocolVersion: SYNC_PROTOCOL_VERSION,
          serverTime,
          limits: { maxBatchRecords: 100, maxCiphertextBytes: 5_242_880, maxRequestBytes: 26_214_400 },
          capabilities: { push: true, pull: true, tombstones: true },
        });
      }
      if (url.endsWith("/v1/sync/push")) {
        const body = JSON.parse(String(init?.body)) as { requestId: string; records: Array<{ recordId: string }> };
        pushedBatchSizes.push(body.records.length);
        return Response.json({
          protocolVersion: SYNC_PROTOCOL_VERSION,
          requestId: body.requestId,
          serverTime,
          acceptedRecordIds: body.records.map((record) => record.recordId),
          conflicts: [],
          rejected: [],
          cursor: `push-${pushedBatchSizes.length}`,
        });
      }
      if (url.endsWith("/v1/sync/pull")) {
        return Response.json({
          protocolVersion: SYNC_PROTOCOL_VERSION,
          serverTime,
          records: [],
          cursor: "pull-complete",
          hasMore: false,
        });
      }
      return new Response(null, { status: 404 });
    }));

    const result = await synchronize(records, configuration, "test-device");

    expect(pushedBatchSizes).toEqual([100, 100, 5]);
    expect(result.acceptedCount).toBe(205);
    expect(result.cursor).toBe("pull-complete");
  });

  it("rejects a local record that exceeds the advertised ciphertext limit before pushing", async () => {
    const material = await generateEncryptionMaterial();
    const configuration: SyncConfiguration = {
      endpoint: "https://sync.example.test",
      accessToken: "a".repeat(32),
      ...material,
      cursor: "",
      enabled: true,
    };
    const fetchMock = vi.fn(async () => Response.json({
      protocol: SYNC_PROTOCOL,
      protocolVersion: SYNC_PROTOCOL_VERSION,
      minSupportedProtocolVersion: SYNC_PROTOCOL_VERSION,
      serverTime,
      limits: { maxBatchRecords: 100, maxCiphertextBytes: 1, maxRequestBytes: 26_214_400 },
      capabilities: { push: true, pull: true, tombstones: true },
    }));
    vi.stubGlobal("fetch", fetchMock);

    await expect(synchronize([{
      recordId: "food-too-large",
      namespace: "food.logs",
      deleted: false,
      data: { name: "A meal that cannot fit" },
      version: {
        updatedAt: serverTime,
        revision: 1,
        deviceId: "test-device",
        mutationId: "mutation-too-large",
      },
    }], configuration, "test-device")).rejects.toThrow("exceeds the server ciphertext limit");
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("retains the previous cursor when any pulled envelope cannot be decrypted", async () => {
    const localMaterial = await generateEncryptionMaterial();
    const remoteMaterial = await generateEncryptionMaterial();
    const configuration: SyncConfiguration = {
      endpoint: "https://sync.example.test",
      accessToken: "a".repeat(32),
      ...localMaterial,
      cursor: "cursor-before",
      enabled: true,
    };
    const remote = await encryptEntity({
      recordId: "food-remote",
      namespace: "food.logs",
      deleted: false,
      data: { name: "Encrypted elsewhere" },
      version: {
        updatedAt: serverTime,
        revision: 1,
        deviceId: "remote-device",
        mutationId: "remote-mutation",
      },
    }, remoteMaterial.encryptionKey, remoteMaterial.keyId);

    vi.stubGlobal("fetch", vi.fn(async (input: string | URL | Request) => {
      const url = String(input);
      if (url.endsWith("/v1/info")) {
        return Response.json({
          protocol: SYNC_PROTOCOL,
          protocolVersion: SYNC_PROTOCOL_VERSION,
          minSupportedProtocolVersion: SYNC_PROTOCOL_VERSION,
          serverTime,
          limits: { maxBatchRecords: 100, maxCiphertextBytes: 5_242_880, maxRequestBytes: 26_214_400 },
          capabilities: { push: true, pull: true, tombstones: true },
        });
      }
      return Response.json({
        protocolVersion: SYNC_PROTOCOL_VERSION,
        serverTime,
        records: [remote],
        cursor: "cursor-after",
        hasMore: false,
      });
    }));

    const result = await synchronize([], configuration, "local-device");
    expect(result.skippedCount).toBe(1);
    expect(result.cursor).toBe("cursor-before");
  });

  it("continues later batches and pulls when one local record is rejected", async () => {
    const material = await generateEncryptionMaterial();
    const configuration: SyncConfiguration = {
      endpoint: "https://sync.example.test",
      accessToken: "a".repeat(32),
      ...material,
      cursor: "",
      enabled: true,
    };
    let pushCount = 0;
    let pullCount = 0;
    vi.stubGlobal("fetch", vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      if (url.endsWith("/v1/info")) return Response.json({
        protocol: SYNC_PROTOCOL,
        protocolVersion: SYNC_PROTOCOL_VERSION,
        minSupportedProtocolVersion: SYNC_PROTOCOL_VERSION,
        serverTime,
        limits: { maxBatchRecords: 1, maxCiphertextBytes: 5_242_880, maxRequestBytes: 26_214_400 },
        capabilities: { push: true, pull: true, tombstones: true },
      });
      if (url.endsWith("/v1/sync/push")) {
        pushCount += 1;
        const body = JSON.parse(String(init?.body)) as { requestId: string; records: Array<{ recordId: string }> };
        const rejected = pushCount === 1
          ? [{ recordId: body.records[0]?.recordId, code: "invalid_record", message: "wrong workspace key" }]
          : [];
        return Response.json({
          protocolVersion: SYNC_PROTOCOL_VERSION,
          requestId: body.requestId,
          serverTime,
          acceptedRecordIds: rejected.length === 0 ? [body.records[0]?.recordId] : [],
          conflicts: [],
          rejected,
          cursor: `push-${pushCount}`,
        });
      }
      pullCount += 1;
      return Response.json({
        protocolVersion: SYNC_PROTOCOL_VERSION,
        serverTime,
        records: [],
        cursor: "pull-complete",
        hasMore: false,
      });
    }));
    const records: LocalEntity[] = [0, 1].map((index) => ({
      recordId: `food-rejection-${index}`,
      namespace: "food.logs",
      deleted: false,
      data: { name: `Meal ${index}` },
      version: { updatedAt: serverTime, revision: 1, deviceId: "device", mutationId: `mutation-rejection-${index}` },
    }));

    const result = await synchronize(records, configuration, "device");
    expect(pushCount).toBe(2);
    expect(pullCount).toBe(1);
    expect(result.acceptedCount).toBe(1);
    expect(result.rejectedCount).toBe(1);
  });

  it("stops a malformed pull loop whose cursor does not advance", async () => {
    const material = await generateEncryptionMaterial();
    const configuration: SyncConfiguration = {
      endpoint: "https://sync.example.test",
      accessToken: "a".repeat(32),
      ...material,
      cursor: "cursor-stuck",
      enabled: true,
    };
    vi.stubGlobal("fetch", vi.fn(async (input: string | URL | Request) => {
      const url = String(input);
      if (url.endsWith("/v1/info")) return Response.json({
        protocol: SYNC_PROTOCOL,
        protocolVersion: SYNC_PROTOCOL_VERSION,
        minSupportedProtocolVersion: SYNC_PROTOCOL_VERSION,
        serverTime,
        limits: { maxBatchRecords: 100, maxCiphertextBytes: 5_242_880, maxRequestBytes: 26_214_400 },
        capabilities: { push: true, pull: true, tombstones: true },
      });
      return Response.json({
        protocolVersion: SYNC_PROTOCOL_VERSION,
        serverTime,
        records: [],
        cursor: "cursor-stuck",
        hasMore: true,
      });
    }));

    await expect(synchronize([], configuration, "device"))
      .rejects.toThrow("non-advancing cursor");
  });
});
