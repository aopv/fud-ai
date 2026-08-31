/** Stable wire identifier for the Fud AI end-to-end encrypted sync protocol. */
export const SYNC_PROTOCOL = "fud-ai-e2ee-sync" as const;
export const SYNC_PROTOCOL_VERSION = 1 as const;
export const MIN_SUPPORTED_SYNC_PROTOCOL_VERSION = 1 as const;

/** Hard protocol ceilings. Deployments may advertise smaller operational limits. */
export const SYNC_LIMITS = Object.freeze({
  maxBatchRecords: 500,
  maxCiphertextBytes: 5 * 1024 * 1024,
  maxRequestBytes: 25 * 1024 * 1024,
  maxIdentifierLength: 128,
  maxNamespaceLength: 96,
  maxCursorLength: 1024,
  maxRejectionMessageLength: 512,
} as const);

export const E2EE_ALGORITHMS = ["AES-256-GCM"] as const;
export type E2EEAlgorithm = (typeof E2EE_ALGORITHMS)[number];

export interface SyncServerInfoV1 {
  protocol: typeof SYNC_PROTOCOL;
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  minSupportedProtocolVersion: typeof MIN_SUPPORTED_SYNC_PROTOCOL_VERSION;
  serverTime: string;
  limits: {
    maxBatchRecords: number;
    maxCiphertextBytes: number;
    maxRequestBytes: number;
  };
  capabilities: {
    push: true;
    pull: true;
    tombstones: true;
  };
}

/**
 * Encryption material is produced and consumed only by clients. The server stores
 * these fields as opaque strings and must never receive the corresponding key.
 */
export interface EncryptedPayloadV1 {
  algorithm: E2EEAlgorithm;
  keyId: string;
  nonce: string;
  ciphertext: string;
}

export interface RecordVersionV1 {
  /** Canonical UTC RFC 3339 timestamp, e.g. 2026-08-31T12:34:56.789Z. */
  updatedAt: string;
  /** Monotonic counter maintained by the originating client for this record. */
  revision: number;
  deviceId: string;
  /** Unique id for this mutation; also provides a deterministic final tie-break. */
  mutationId: string;
}

export interface SyncRecordEnvelopeV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  /**
   * Globally unique within one sync workspace, regardless of namespace. A
   * namespace is record metadata, not part of the record's storage identity.
   */
  recordId: string;
  namespace: string;
  version: RecordVersionV1;
  deleted: boolean;
  /** Always encrypted, including authenticated deletion tombstones. */
  payload: EncryptedPayloadV1;
}

/**
 * Stable domain separator for AES-GCM additional authenticated data (AAD).
 * Changing its value or field order is a wire-protocol change.
 */
export const SYNC_RECORD_AAD_DOMAIN_V1 = "fud-ai-e2ee-sync-record-v1" as const;

export interface SyncRecordAadInputV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  recordId: string;
  namespace: string;
  version: RecordVersionV1;
  deleted: boolean;
  keyId: string;
}

/**
 * Serialize all unencrypted conflict/security metadata into an unambiguous,
 * cross-platform AES-GCM AAD string. The array order is normative.
 */
export function serializeSyncRecordAadV1(input: SyncRecordAadInputV1): string {
  return JSON.stringify([
    SYNC_RECORD_AAD_DOMAIN_V1,
    input.protocolVersion,
    input.recordId,
    input.namespace,
    input.version.updatedAt,
    input.version.revision,
    input.version.deviceId,
    input.version.mutationId,
    input.deleted,
    input.keyId,
  ]);
}

export interface SyncPushRequestV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  requestId: string;
  deviceId: string;
  records: SyncRecordEnvelopeV1[];
}

export type SyncRejectionCodeV1 =
  | "invalid_record"
  | "payload_too_large"
  | "unsupported_version"
  | "quota_exceeded";

export interface SyncRejectedRecordV1 {
  recordId: string;
  code: SyncRejectionCodeV1;
  message: string;
}

export interface SyncPushResponseV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  requestId: string;
  serverTime: string;
  acceptedRecordIds: string[];
  /** Current winners returned when the submitted mutation lost LWW resolution. */
  conflicts: SyncRecordEnvelopeV1[];
  rejected: SyncRejectedRecordV1[];
  cursor: string;
}

export interface SyncPullRequestV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  cursor?: string;
  limit?: number;
}

export interface SyncPullResponseV1 {
  protocolVersion: typeof SYNC_PROTOCOL_VERSION;
  serverTime: string;
  records: SyncRecordEnvelopeV1[];
  cursor: string;
  hasMore: boolean;
}

export interface ValidationIssue {
  path: string;
  message: string;
}

export type ValidationResult<T> =
  | { success: true; value: T }
  | { success: false; issues: ValidationIssue[] };

export class ContractValidationError extends Error {
  readonly issues: readonly ValidationIssue[];

  constructor(issues: readonly ValidationIssue[]) {
    super(issues.map((issue) => `${issue.path}: ${issue.message}`).join("; "));
    this.name = "ContractValidationError";
    this.issues = issues;
  }
}

type JsonObject = Record<string, unknown>;
type Validator<T> = (value: unknown, path: string, issues: ValidationIssue[]) => value is T;

const IDENTIFIER_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._:-]*$/;
const NAMESPACE_PATTERN = /^[a-z][a-z0-9]*(?:[._-][a-z0-9]+)*$/;
const BASE64URL_PATTERN = /^[A-Za-z0-9_-]+$/;
const REJECTION_CODES: readonly SyncRejectionCodeV1[] = [
  "invalid_record",
  "payload_too_large",
  "unsupported_version",
  "quota_exceeded",
];

function issue(issues: ValidationIssue[], path: string, message: string): false {
  issues.push({ path, message });
  return false;
}

function isObject(value: unknown, path: string, issues: ValidationIssue[]): value is JsonObject {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return issue(issues, path, "must be an object");
  }
  return true;
}

function hasOnlyKeys(
  value: JsonObject,
  allowed: readonly string[],
  path: string,
  issues: ValidationIssue[],
): boolean {
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unknown.length > 0) {
    issue(issues, path, `contains unknown field(s): ${unknown.sort().join(", ")}`);
    return false;
  }
  return true;
}

function isStringInRange(
  value: unknown,
  min: number,
  max: number,
  path: string,
  issues: ValidationIssue[],
): value is string {
  return typeof value === "string" && value.length >= min && value.length <= max
    ? true
    : issue(issues, path, `must be a string between ${min} and ${max} characters`);
}

function isIdentifier(value: unknown, path: string, issues: ValidationIssue[]): value is string {
  if (!isStringInRange(value, 1, SYNC_LIMITS.maxIdentifierLength, path, issues)) return false;
  return IDENTIFIER_PATTERN.test(value)
    ? true
    : issue(issues, path, "must contain only portable identifier characters");
}

function isNamespace(value: unknown, path: string, issues: ValidationIssue[]): value is string {
  if (!isStringInRange(value, 1, SYNC_LIMITS.maxNamespaceLength, path, issues)) return false;
  return NAMESPACE_PATTERN.test(value)
    ? true
    : issue(issues, path, "must be a lowercase dotted, dashed, or underscored namespace");
}

function isCanonicalTimestamp(value: unknown, path: string, issues: ValidationIssue[]): value is string {
  if (typeof value !== "string") return issue(issues, path, "must be a string");
  const milliseconds = Date.parse(value);
  if (!Number.isFinite(milliseconds) || new Date(milliseconds).toISOString() !== value) {
    return issue(issues, path, "must be a canonical UTC RFC 3339 timestamp with milliseconds");
  }
  return true;
}

function isSafeIntegerInRange(
  value: unknown,
  min: number,
  max: number,
  path: string,
  issues: ValidationIssue[],
): value is number {
  return Number.isSafeInteger(value) && (value as number) >= min && (value as number) <= max
    ? true
    : issue(issues, path, `must be a safe integer between ${min} and ${max}`);
}

function isBoolean(value: unknown, path: string, issues: ValidationIssue[]): value is boolean {
  return typeof value === "boolean" ? true : issue(issues, path, "must be a boolean");
}

function decodedBase64UrlBytes(value: string): number {
  const remainder = value.length % 4;
  if (remainder === 1) return -1;
  const paddingBytes = remainder === 0 ? 0 : 4 - remainder;
  return Math.floor((value.length + paddingBytes) * 3 / 4) - paddingBytes;
}

function isBase64Url(
  value: unknown,
  minBytes: number,
  maxBytes: number,
  path: string,
  issues: ValidationIssue[],
): value is string {
  if (typeof value !== "string" || !BASE64URL_PATTERN.test(value)) {
    return issue(issues, path, "must be non-padded base64url");
  }
  const bytes = decodedBase64UrlBytes(value);
  return bytes >= minBytes && bytes <= maxBytes
    ? true
    : issue(issues, path, `must decode to between ${minBytes} and ${maxBytes} bytes`);
}

function isLiteral<T extends string | number | boolean>(
  value: unknown,
  expected: T,
  path: string,
  issues: ValidationIssue[],
): value is T {
  return value === expected ? true : issue(issues, path, `must equal ${String(expected)}`);
}

function isArrayOf<T>(
  value: unknown,
  validator: Validator<T>,
  maxLength: number,
  path: string,
  issues: ValidationIssue[],
): value is T[] {
  if (!Array.isArray(value)) return issue(issues, path, "must be an array");
  if (value.length > maxLength) return issue(issues, path, `must contain at most ${maxLength} items`);
  let valid = true;
  value.forEach((item, index) => {
    if (!validator(item, `${path}[${index}]`, issues)) valid = false;
  });
  return valid;
}

function validateEncryptedPayload(
  value: unknown,
  path: string,
  issues: ValidationIssue[],
): value is EncryptedPayloadV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["algorithm", "keyId", "nonce", "ciphertext"], path, issues);
  if (!isLiteral(value.algorithm, "AES-256-GCM", `${path}.algorithm`, issues)) valid = false;
  if (!isIdentifier(value.keyId, `${path}.keyId`, issues)) valid = false;
  if (!isBase64Url(value.nonce, 12, 12, `${path}.nonce`, issues)) valid = false;
  if (!isBase64Url(value.ciphertext, 17, SYNC_LIMITS.maxCiphertextBytes, `${path}.ciphertext`, issues)) valid = false;
  return valid;
}

function validateRecordVersion(
  value: unknown,
  path: string,
  issues: ValidationIssue[],
): value is RecordVersionV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["updatedAt", "revision", "deviceId", "mutationId"], path, issues);
  if (!isCanonicalTimestamp(value.updatedAt, `${path}.updatedAt`, issues)) valid = false;
  if (!isSafeIntegerInRange(value.revision, 1, Number.MAX_SAFE_INTEGER, `${path}.revision`, issues)) valid = false;
  if (!isIdentifier(value.deviceId, `${path}.deviceId`, issues)) valid = false;
  if (!isIdentifier(value.mutationId, `${path}.mutationId`, issues)) valid = false;
  return valid;
}

function validateRecord(value: unknown, path: string, issues: ValidationIssue[]): value is SyncRecordEnvelopeV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(
    value,
    ["protocolVersion", "recordId", "namespace", "version", "deleted", "payload"],
    path,
    issues,
  );
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (!isIdentifier(value.recordId, `${path}.recordId`, issues)) valid = false;
  if (!isNamespace(value.namespace, `${path}.namespace`, issues)) valid = false;
  if (!validateRecordVersion(value.version, `${path}.version`, issues)) valid = false;
  if (!isBoolean(value.deleted, `${path}.deleted`, issues)) valid = false;
  if (!validateEncryptedPayload(value.payload, `${path}.payload`, issues)) valid = false;
  return valid;
}

function validateServerInfo(value: unknown, path: string, issues: ValidationIssue[]): value is SyncServerInfoV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(
    value,
    ["protocol", "protocolVersion", "minSupportedProtocolVersion", "serverTime", "limits", "capabilities"],
    path,
    issues,
  );
  if (!isLiteral(value.protocol, SYNC_PROTOCOL, `${path}.protocol`, issues)) valid = false;
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (!isLiteral(value.minSupportedProtocolVersion, MIN_SUPPORTED_SYNC_PROTOCOL_VERSION, `${path}.minSupportedProtocolVersion`, issues)) valid = false;
  if (!isCanonicalTimestamp(value.serverTime, `${path}.serverTime`, issues)) valid = false;
  if (isObject(value.limits, `${path}.limits`, issues)) {
    const limits = value.limits;
    if (!hasOnlyKeys(limits, ["maxBatchRecords", "maxCiphertextBytes", "maxRequestBytes"], `${path}.limits`, issues)) valid = false;
    if (!isSafeIntegerInRange(limits.maxBatchRecords, 1, SYNC_LIMITS.maxBatchRecords, `${path}.limits.maxBatchRecords`, issues)) valid = false;
    if (!isSafeIntegerInRange(limits.maxCiphertextBytes, 1, SYNC_LIMITS.maxCiphertextBytes, `${path}.limits.maxCiphertextBytes`, issues)) valid = false;
    if (!isSafeIntegerInRange(limits.maxRequestBytes, 1, SYNC_LIMITS.maxRequestBytes, `${path}.limits.maxRequestBytes`, issues)) valid = false;
  } else valid = false;
  if (isObject(value.capabilities, `${path}.capabilities`, issues)) {
    const capabilities = value.capabilities;
    if (!hasOnlyKeys(capabilities, ["push", "pull", "tombstones"], `${path}.capabilities`, issues)) valid = false;
    if (!isLiteral(capabilities.push, true, `${path}.capabilities.push`, issues)) valid = false;
    if (!isLiteral(capabilities.pull, true, `${path}.capabilities.pull`, issues)) valid = false;
    if (!isLiteral(capabilities.tombstones, true, `${path}.capabilities.tombstones`, issues)) valid = false;
  } else valid = false;
  return valid;
}

function validatePushRequest(value: unknown, path: string, issues: ValidationIssue[]): value is SyncPushRequestV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["protocolVersion", "requestId", "deviceId", "records"], path, issues);
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (!isIdentifier(value.requestId, `${path}.requestId`, issues)) valid = false;
  if (!isIdentifier(value.deviceId, `${path}.deviceId`, issues)) valid = false;
  if (isArrayOf(value.records, validateRecord, SYNC_LIMITS.maxBatchRecords, `${path}.records`, issues)) {
    const firstIndexByRecordId = new Map<string, number>();
    value.records.forEach((record, index) => {
      const firstIndex = firstIndexByRecordId.get(record.recordId);
      if (firstIndex === undefined) {
        firstIndexByRecordId.set(record.recordId, index);
      } else {
        valid = issue(
          issues,
          `${path}.records[${index}].recordId`,
          `must be globally unique across namespaces in a push (already used at ${path}.records[${firstIndex}])`,
        );
      }
    });
  } else {
    valid = false;
  }
  return valid;
}

function validateRejected(value: unknown, path: string, issues: ValidationIssue[]): value is SyncRejectedRecordV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["recordId", "code", "message"], path, issues);
  if (!isIdentifier(value.recordId, `${path}.recordId`, issues)) valid = false;
  if (typeof value.code !== "string" || !REJECTION_CODES.includes(value.code as SyncRejectionCodeV1)) {
    valid = issue(issues, `${path}.code`, "must be a supported rejection code");
  }
  if (!isStringInRange(value.message, 1, SYNC_LIMITS.maxRejectionMessageLength, `${path}.message`, issues)) valid = false;
  return valid;
}

function validateIdentifierItem(value: unknown, path: string, issues: ValidationIssue[]): value is string {
  return isIdentifier(value, path, issues);
}

function validatePushResponse(value: unknown, path: string, issues: ValidationIssue[]): value is SyncPushResponseV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(
    value,
    ["protocolVersion", "requestId", "serverTime", "acceptedRecordIds", "conflicts", "rejected", "cursor"],
    path,
    issues,
  );
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (!isIdentifier(value.requestId, `${path}.requestId`, issues)) valid = false;
  if (!isCanonicalTimestamp(value.serverTime, `${path}.serverTime`, issues)) valid = false;
  if (!isArrayOf(value.acceptedRecordIds, validateIdentifierItem, SYNC_LIMITS.maxBatchRecords, `${path}.acceptedRecordIds`, issues)) valid = false;
  if (!isArrayOf(value.conflicts, validateRecord, SYNC_LIMITS.maxBatchRecords, `${path}.conflicts`, issues)) valid = false;
  if (!isArrayOf(value.rejected, validateRejected, SYNC_LIMITS.maxBatchRecords, `${path}.rejected`, issues)) valid = false;
  if (!isStringInRange(value.cursor, 1, SYNC_LIMITS.maxCursorLength, `${path}.cursor`, issues)) valid = false;
  return valid;
}

function validatePullRequest(value: unknown, path: string, issues: ValidationIssue[]): value is SyncPullRequestV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["protocolVersion", "cursor", "limit"], path, issues);
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (value.cursor !== undefined && !isStringInRange(value.cursor, 1, SYNC_LIMITS.maxCursorLength, `${path}.cursor`, issues)) valid = false;
  if (value.limit !== undefined && !isSafeIntegerInRange(value.limit, 1, SYNC_LIMITS.maxBatchRecords, `${path}.limit`, issues)) valid = false;
  return valid;
}

function validatePullResponse(value: unknown, path: string, issues: ValidationIssue[]): value is SyncPullResponseV1 {
  if (!isObject(value, path, issues)) return false;
  let valid = hasOnlyKeys(value, ["protocolVersion", "serverTime", "records", "cursor", "hasMore"], path, issues);
  if (!isLiteral(value.protocolVersion, SYNC_PROTOCOL_VERSION, `${path}.protocolVersion`, issues)) valid = false;
  if (!isCanonicalTimestamp(value.serverTime, `${path}.serverTime`, issues)) valid = false;
  if (!isArrayOf(value.records, validateRecord, SYNC_LIMITS.maxBatchRecords, `${path}.records`, issues)) valid = false;
  if (!isStringInRange(value.cursor, 1, SYNC_LIMITS.maxCursorLength, `${path}.cursor`, issues)) valid = false;
  if (!isBoolean(value.hasMore, `${path}.hasMore`, issues)) valid = false;
  return valid;
}

function runValidation<T>(value: unknown, validator: Validator<T>): ValidationResult<T> {
  const issues: ValidationIssue[] = [];
  if (validator(value, "$", issues)) return { success: true, value };
  return { success: false, issues };
}

function parse<T>(value: unknown, validator: Validator<T>): T {
  const result = runValidation(value, validator);
  if (!result.success) throw new ContractValidationError(result.issues);
  return result.value;
}

export const validateSyncServerInfoV1 = (value: unknown): ValidationResult<SyncServerInfoV1> =>
  runValidation(value, validateServerInfo);
export const validateSyncRecordEnvelopeV1 = (value: unknown): ValidationResult<SyncRecordEnvelopeV1> =>
  runValidation(value, validateRecord);
export const validateSyncPushRequestV1 = (value: unknown): ValidationResult<SyncPushRequestV1> =>
  runValidation(value, validatePushRequest);
export const validateSyncPushResponseV1 = (value: unknown): ValidationResult<SyncPushResponseV1> =>
  runValidation(value, validatePushResponse);
export const validateSyncPullRequestV1 = (value: unknown): ValidationResult<SyncPullRequestV1> =>
  runValidation(value, validatePullRequest);
export const validateSyncPullResponseV1 = (value: unknown): ValidationResult<SyncPullResponseV1> =>
  runValidation(value, validatePullResponse);

export const parseSyncServerInfoV1 = (value: unknown): SyncServerInfoV1 => parse(value, validateServerInfo);
export const parseSyncRecordEnvelopeV1 = (value: unknown): SyncRecordEnvelopeV1 => parse(value, validateRecord);
export const parseSyncPushRequestV1 = (value: unknown): SyncPushRequestV1 => parse(value, validatePushRequest);
export const parseSyncPushResponseV1 = (value: unknown): SyncPushResponseV1 => parse(value, validatePushResponse);
export const parseSyncPullRequestV1 = (value: unknown): SyncPullRequestV1 => parse(value, validatePullRequest);
export const parseSyncPullResponseV1 = (value: unknown): SyncPullResponseV1 => parse(value, validatePullResponse);

/**
 * Compare two versions using deterministic last-write-wins ordering.
 * Returns a negative number when `left` loses, a positive number when it wins,
 * and zero only when every version component is identical.
 */
export function compareRecordVersionsLww(left: RecordVersionV1, right: RecordVersionV1): number {
  const time = Date.parse(left.updatedAt) - Date.parse(right.updatedAt);
  if (time !== 0) return time < 0 ? -1 : 1;
  if (left.revision !== right.revision) return left.revision < right.revision ? -1 : 1;
  const device = compareCodeUnits(left.deviceId, right.deviceId);
  if (device !== 0) return device;
  return compareCodeUnits(left.mutationId, right.mutationId);
}

/** Select the deterministic winner. When identical, `left` is returned. */
export function selectLwwWinner<T extends { version: RecordVersionV1 }>(left: T, right: T): T {
  return compareRecordVersionsLww(left.version, right.version) >= 0 ? left : right;
}

function compareCodeUnits(left: string, right: string): number {
  if (left === right) return 0;
  return left < right ? -1 : 1;
}
