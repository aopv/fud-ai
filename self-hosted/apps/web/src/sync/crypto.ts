import {
  serializeSyncRecordAadV1,
  SYNC_PROTOCOL_VERSION,
  type SyncRecordEnvelopeV1,
} from "@fud-ai/sync-contracts";
import type { AppNamespace, LocalEntity } from "../domain";

const encoder = new TextEncoder();
const decoder = new TextDecoder();
const APP_NAMESPACES = new Set<AppNamespace>([
  "profile",
  "food.logs",
  "water.logs",
  "fasting.logs",
  "weight.logs",
  "bodyfat.logs",
  "workout.logs",
  "coach.messages",
]);
const ENCRYPTED_TOMBSTONE_V1 = Object.freeze({ tombstone: true });

function bytesToBase64Url(bytes: Uint8Array): string {
  let binary = "";
  const chunkSize = 32_768;
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/u, "");
}

function base64UrlToBytes(value: string): Uint8Array<ArrayBuffer> {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const binary = atob(padded);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

async function importEncryptionKey(encodedKey: string): Promise<CryptoKey> {
  const raw = base64UrlToBytes(encodedKey);
  if (raw.byteLength !== 32) throw new Error("The pairing key must contain 32 bytes");
  return crypto.subtle.importKey("raw", raw, { name: "AES-GCM" }, false, ["encrypt", "decrypt"]);
}

export async function generateEncryptionMaterial(): Promise<{ encryptionKey: string; keyId: string }> {
  const raw = crypto.getRandomValues(new Uint8Array(32));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", raw));
  return {
    encryptionKey: bytesToBase64Url(raw),
    // Identifiers must begin with an alphanumeric character. Prefixing also
    // avoids rejecting the valid base64url values that happen to begin - or _.
    keyId: `key-${bytesToBase64Url(digest.subarray(0, 12))}`,
  };
}

export async function encryptEntity(
  entity: LocalEntity,
  encodedKey: string,
  keyId: string,
): Promise<SyncRecordEnvelopeV1> {
  if (entity.deleted && entity.data !== null) throw new Error("A deleted local record must not retain plaintext data");
  if (!entity.deleted && entity.data === null) throw new Error("A live local record must contain data");
  const nonce = crypto.getRandomValues(new Uint8Array(12));
  const key = await importEncryptionKey(encodedKey);
  const additionalData = encoder.encode(serializeSyncRecordAadV1({
    protocolVersion: SYNC_PROTOCOL_VERSION,
    recordId: entity.recordId,
    namespace: entity.namespace,
    version: entity.version,
    deleted: entity.deleted,
    keyId,
  }));
  const plaintext = encoder.encode(JSON.stringify(entity.deleted ? ENCRYPTED_TOMBSTONE_V1 : entity.data));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, additionalData, tagLength: 128 },
    key,
    plaintext,
  );
  return {
    protocolVersion: SYNC_PROTOCOL_VERSION,
    recordId: entity.recordId,
    namespace: entity.namespace,
    version: entity.version,
    deleted: entity.deleted,
    payload: {
      algorithm: "AES-256-GCM",
      keyId,
      nonce: bytesToBase64Url(nonce),
      ciphertext: bytesToBase64Url(new Uint8Array(encrypted)),
    },
  };
}

export async function decryptEnvelope(
  envelope: SyncRecordEnvelopeV1,
  encodedKey: string,
  expectedKeyId: string,
): Promise<LocalEntity> {
  if (!APP_NAMESPACES.has(envelope.namespace as AppNamespace)) {
    throw new Error(`Unsupported record namespace: ${envelope.namespace}`);
  }
  const namespace = envelope.namespace as AppNamespace;
  if (envelope.payload.algorithm !== "AES-256-GCM") throw new Error("Encrypted payload algorithm is unsupported");
  if (envelope.payload.keyId !== expectedKeyId) {
    throw new Error(`Encrypted record uses an unexpected pairing key (${envelope.payload.keyId})`);
  }
  const key = await importEncryptionKey(encodedKey);
  const additionalData = encoder.encode(serializeSyncRecordAadV1({
    protocolVersion: envelope.protocolVersion,
    recordId: envelope.recordId,
    namespace: envelope.namespace,
    version: envelope.version,
    deleted: envelope.deleted,
    keyId: envelope.payload.keyId,
  }));
  const decrypted = await crypto.subtle.decrypt(
    {
      name: "AES-GCM",
      iv: base64UrlToBytes(envelope.payload.nonce),
      additionalData,
      tagLength: 128,
    },
    key,
    base64UrlToBytes(envelope.payload.ciphertext),
  );
  let plaintext: unknown;
  try {
    plaintext = JSON.parse(decoder.decode(decrypted)) as unknown;
  } catch {
    throw new Error("Encrypted record plaintext is not valid JSON");
  }
  if (envelope.deleted) {
    if (!isEncryptedTombstoneV1(plaintext)) throw new Error("Encrypted tombstone marker is invalid");
    return {
      recordId: envelope.recordId,
      namespace,
      version: envelope.version,
      deleted: true,
      data: null,
    };
  }
  if (!isValidNamespaceData(namespace, plaintext, envelope.recordId)) {
    throw new Error(`Encrypted ${namespace} record has invalid data`);
  }
  return {
    recordId: envelope.recordId,
    namespace,
    version: envelope.version,
    deleted: false,
    data: plaintext,
  };
}

function isEncryptedTombstoneV1(value: unknown): boolean {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const candidate = value as Record<string, unknown>;
  return Object.keys(candidate).length === 1 && candidate.tombstone === true;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isString(value: unknown): value is string { return typeof value === "string"; }
function isNumber(value: unknown): value is number { return typeof value === "number" && Number.isFinite(value); }
function hasMatchingId(value: Record<string, unknown>, recordId: string): boolean {
  return value.id === recordId;
}
function hasNutrients(value: Record<string, unknown>): boolean {
  return isNumber(value.calories) && isNumber(value.protein) && isNumber(value.carbs)
    && isNumber(value.fat) && isNumber(value.fiber);
}

function isValidNamespaceData(namespace: AppNamespace, value: unknown, recordId: string): boolean {
  if (!isObject(value) || !hasMatchingId(value, recordId)) return false;
  switch (namespace) {
    case "profile":
      return recordId === "profile" && value.id === "profile" && isString(value.displayName)
        && hasNutrients(value) && isNumber(value.waterGoalMl)
        && (value.units === "metric" || value.units === "imperial");
    case "food.logs":
      return isString(value.name) && isString(value.timestamp) && isNumber(value.quantity)
        && isString(value.unit) && isString(value.note) && typeof value.favorite === "boolean"
        && isString(value.emoji) && hasNutrients(value)
        && ["breakfast", "lunch", "dinner", "snack"].includes(String(value.meal));
    case "water.logs":
      return isString(value.timestamp) && isNumber(value.milliliters);
    case "fasting.logs":
      return isString(value.startedAt) && (value.endedAt === null || isString(value.endedAt))
        && isNumber(value.targetHours)
        && ["active", "completed", "cancelled"].includes(String(value.status));
    case "weight.logs":
      return isString(value.timestamp) && isNumber(value.kilograms);
    case "bodyfat.logs":
      return isString(value.timestamp) && isNumber(value.percentage);
    case "workout.logs":
      return isString(value.timestamp) && isString(value.name) && isString(value.category)
        && isNumber(value.caloriesBurned) && typeof value.saved === "boolean"
        && Array.isArray(value.sets) && value.sets.every((set) => isObject(set)
          && isNumber(set.weightKg) && isNumber(set.reps));
    case "coach.messages":
      return isString(value.timestamp) && isString(value.content)
        && (value.role === "user" || value.role === "assistant");
  }
}
