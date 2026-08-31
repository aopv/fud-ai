import { describe, expect, it } from "vitest";
import type { SyncRecordEnvelopeV1 } from "@fud-ai/sync-contracts";
import type { FoodEntry, LocalEntity } from "../domain";
import { decryptEnvelope, encryptEntity, generateEncryptionMaterial } from "./crypto";

const food: FoodEntry = {
  id: "food-1",
  name: "Private lunch",
  meal: "lunch",
  timestamp: "2026-08-31T12:00:00.000Z",
  quantity: 1,
  unit: "serving",
  calories: 520,
  protein: 35,
  carbs: 55,
  fat: 18,
  fiber: 8,
  note: "",
  favorite: false,
  emoji: "🥗",
};

const record: LocalEntity<FoodEntry> = {
  recordId: food.id,
  namespace: "food.logs",
  deleted: false,
  data: food,
  version: {
    updatedAt: "2026-08-31T12:00:00.000Z",
    revision: 1,
    deviceId: "browser-device",
    mutationId: "mutation-1",
  },
};

describe("client-side encryption", () => {
  it("generates protocol-safe pairing key identifiers", async () => {
    const material = await generateEncryptionMaterial();
    expect(material.keyId).toMatch(/^key-[A-Za-z0-9_-]+$/u);
  });

  it("round-trips a record without exposing plaintext in the envelope", async () => {
    const material = await generateEncryptionMaterial();
    const envelope = await encryptEntity(record, material.encryptionKey, material.keyId);
    expect(JSON.stringify(envelope)).not.toContain(food.name);
    const decrypted = await decryptEnvelope(envelope, material.encryptionKey, material.keyId);
    expect(decrypted).toEqual(record);
  });

  it("encrypts and authenticates deletion tombstones", async () => {
    const material = await generateEncryptionMaterial();
    const tombstone = await encryptEntity({ ...record, deleted: true, data: null }, material.encryptionKey, material.keyId);
    expect(tombstone.payload.ciphertext.length).toBeGreaterThan(0);
    expect(JSON.stringify(tombstone)).not.toContain("tombstone");
    expect((await decryptEnvelope(tombstone, material.encryptionKey, material.keyId)).deleted).toBe(true);
  });

  it("rejects a pairing-key identifier other than the configured one", async () => {
    const material = await generateEncryptionMaterial();
    const envelope = await encryptEntity(record, material.encryptionKey, material.keyId);
    await expect(decryptEnvelope(envelope, material.encryptionKey, "another-key"))
      .rejects.toThrow("unexpected pairing key");
  });

  it("rejects authenticated plaintext whose id does not match its envelope", async () => {
    const material = await generateEncryptionMaterial();
    const envelope = await encryptEntity({
      ...record,
      data: { ...food, id: "different-food-id" },
    }, material.encryptionKey, material.keyId);
    await expect(decryptEnvelope(envelope, material.encryptionKey, material.keyId))
      .rejects.toThrow("invalid data");
  });

  it("authenticates every conflict and security metadata field", async () => {
    const material = await generateEncryptionMaterial();
    const envelope = await encryptEntity(record, material.encryptionKey, material.keyId);
    const tampered: SyncRecordEnvelopeV1[] = [
      { ...envelope, protocolVersion: 2 as 1 },
      { ...envelope, recordId: "food-2" },
      { ...envelope, namespace: "water.logs" },
      { ...envelope, version: { ...envelope.version, updatedAt: "2026-08-31T12:00:01.000Z" } },
      { ...envelope, version: { ...envelope.version, revision: 2 } },
      { ...envelope, version: { ...envelope.version, deviceId: "another-device" } },
      { ...envelope, version: { ...envelope.version, mutationId: "mutation-2" } },
      { ...envelope, deleted: true },
      { ...envelope, payload: { ...envelope.payload, keyId: "another-key" } },
    ];

    for (const candidate of tampered) {
      await expect(decryptEnvelope(candidate, material.encryptionKey, candidate.payload.keyId)).rejects.toThrow();
    }
  });
});
