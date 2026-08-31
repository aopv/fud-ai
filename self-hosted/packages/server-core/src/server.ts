import {
  ContractValidationError,
  MIN_SUPPORTED_SYNC_PROTOCOL_VERSION,
  parseSyncPullRequestV1,
  parseSyncPushRequestV1,
  SYNC_LIMITS,
  SYNC_PROTOCOL,
  SYNC_PROTOCOL_VERSION,
  type SyncPullResponseV1,
  type SyncPushResponseV1,
  type SyncServerInfoV1,
} from "@fud-ai/sync-contracts";
import type { SyncServerLimits, SyncServerOptions } from "./types.js";

const DEFAULT_LIMITS: Required<SyncServerLimits> = {
  maxBodyBytes: 10 * 1024 * 1024,
  maxRecordBytes: 7 * 1024 * 1024,
  maxCiphertextBytes: SYNC_LIMITS.maxCiphertextBytes,
  maxRecordsPerPush: 250,
  maxPullLimit: 250,
};
const MAX_FUTURE_CLOCK_SKEW_MS = 10 * 60 * 1000;
const encoder = new TextEncoder();

interface ErrorBody { error: { code: string; message: string } }
class RequestValidationError extends Error {}

function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("content-type", "application/json; charset=utf-8");
  responseHeaders.set("cache-control", "no-store");
  return new Response(JSON.stringify(body), { status, headers: responseHeaders });
}

function error(code: string, message: string, status: number): Response {
  return json({ error: { code, message } } satisfies ErrorBody, status);
}

async function sha256(value: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", encoder.encode(value)));
}

/** Hashing normalizes lengths; the final comparison does not exit early. */
export async function constantTimeTokenEquals(actual: string, expected: string): Promise<boolean> {
  const [actualHash, expectedHash] = await Promise.all([sha256(actual), sha256(expected)]);
  let difference = 0;
  for (let index = 0; index < expectedHash.length; index += 1) {
    difference |= (actualHash[index] ?? 0) ^ (expectedHash[index] ?? 0);
  }
  return difference === 0;
}

async function isAuthorized(request: Request, expectedToken: string): Promise<boolean> {
  const authorization = request.headers.get("authorization");
  if (authorization === null || authorization.length > 8192) return false;
  const match = /^Bearer ([^\s]+)$/.exec(authorization);
  return match?.[1] !== undefined && constantTimeTokenEquals(match[1], expectedToken);
}

async function readJson(request: Request, maxBytes: number): Promise<unknown> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    const declared = Number(contentLength);
    if (!Number.isFinite(declared) || declared < 0 || declared > maxBytes) {
      throw new RequestValidationError("Request body exceeds the configured size limit");
    }
  }
  if (request.body === null) throw new RequestValidationError("A JSON request body is required");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      throw new RequestValidationError("Request body exceeds the configured size limit");
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)) as unknown;
  } catch {
    throw new RequestValidationError("Malformed JSON request body");
  }
}

function withCors(response: Response, request: Request, allowedOrigins: readonly string[]): Response {
  const origin = request.headers.get("origin");
  if (origin === null) return response;
  const wildcard = allowedOrigins.includes("*");
  if (!wildcard && !allowedOrigins.includes(origin)) return response;
  const headers = new Headers(response.headers);
  headers.set("access-control-allow-origin", wildcard ? "*" : origin);
  headers.append("vary", "Origin");
  headers.set("access-control-allow-headers", "Authorization, Content-Type");
  headers.set("access-control-allow-methods", "GET, POST, OPTIONS");
  headers.set("access-control-max-age", "86400");
  return new Response(response.body, { status: response.status, statusText: response.statusText, headers });
}

export function createSyncHandler(options: SyncServerOptions): (request: Request) => Promise<Response> {
  if (options.bearerToken.length < 32) throw new Error("SYNC_TOKEN must contain at least 32 characters");
  const limits = { ...DEFAULT_LIMITS, ...options.limits };
  if (limits.maxBodyBytes > SYNC_LIMITS.maxRequestBytes
      || limits.maxCiphertextBytes > SYNC_LIMITS.maxCiphertextBytes
      || limits.maxRecordsPerPush > SYNC_LIMITS.maxBatchRecords
      || limits.maxPullLimit > SYNC_LIMITS.maxBatchRecords) {
    throw new Error("Configured limits cannot exceed the sync protocol ceilings");
  }
  const allowedOrigins = options.allowedOrigins ?? [];
  const serviceName = options.serviceName ?? "Fud AI Self-Hosted Sync";
  const serviceVersion = options.serviceVersion ?? "0.1.0";

  return async (request: Request): Promise<Response> => {
    const respond = (response: Response): Response => withCors(response, request, allowedOrigins);
    const url = new URL(request.url);
    if (request.method === "OPTIONS") {
      const origin = request.headers.get("origin");
      if (origin === null || (!allowedOrigins.includes("*") && !allowedOrigins.includes(origin))) {
        return respond(error("origin_not_allowed", "Origin is not allowed", 403));
      }
      return respond(new Response(null, { status: 204 }));
    }
    if (request.method === "GET" && url.pathname === "/v1/health") {
      try {
        const healthy = await options.storage.health();
        return respond(json({ ok: healthy }, healthy ? 200 : 503));
      } catch {
        return respond(json({ ok: false }, 503));
      }
    }
    if (request.method === "GET" && url.pathname === "/v1/info") {
      const info: SyncServerInfoV1 = {
        protocol: SYNC_PROTOCOL,
        protocolVersion: SYNC_PROTOCOL_VERSION,
        minSupportedProtocolVersion: MIN_SUPPORTED_SYNC_PROTOCOL_VERSION,
        serverTime: new Date().toISOString(),
        limits: {
          maxBatchRecords: limits.maxRecordsPerPush,
          maxCiphertextBytes: limits.maxCiphertextBytes,
          maxRequestBytes: limits.maxBodyBytes,
        },
        capabilities: { push: true, pull: true, tombstones: true },
      };
      const response = json(info);
      response.headers.set("x-fud-ai-service", serviceName);
      response.headers.set("x-fud-ai-service-version", serviceVersion);
      return respond(response);
    }
    if (!(await isAuthorized(request, options.bearerToken))) {
      return respond(error("unauthorized", "A valid bearer token is required", 401));
    }

    try {
      if (request.method === "POST" && url.pathname === "/v1/sync/push") {
        const push = parseSyncPushRequestV1(await readJson(request, limits.maxBodyBytes));
        if (push.records.length > limits.maxRecordsPerPush) {
          throw new RequestValidationError("Too many records in one push");
        }
        const maxAcceptedUpdatedAt = Date.now() + MAX_FUTURE_CLOCK_SKEW_MS;
        const recordsToStore: typeof push.records = [];
        const clockRejected: SyncPushResponseV1["rejected"] = [];
        for (const record of push.records) {
          if (encoder.encode(JSON.stringify(record)).byteLength > limits.maxRecordBytes) {
            throw new RequestValidationError(`Record ${record.recordId} exceeds the configured size limit`);
          }
          if (Math.floor(record.payload.ciphertext.length * 3 / 4) > limits.maxCiphertextBytes) {
            throw new RequestValidationError(`Record ${record.recordId} ciphertext exceeds the configured size limit`);
          }
          if (Date.parse(record.version.updatedAt) > maxAcceptedUpdatedAt) {
            clockRejected.push({
              recordId: record.recordId,
              code: "invalid_record",
              message: "updatedAt is more than 10 minutes ahead of server time",
            });
          } else {
            recordsToStore.push(record);
          }
        }
        const stored = await options.storage.push(recordsToStore);
        const response: SyncPushResponseV1 = {
          protocolVersion: SYNC_PROTOCOL_VERSION,
          requestId: push.requestId,
          serverTime: new Date().toISOString(),
          ...stored,
          rejected: [...stored.rejected, ...clockRejected],
        };
        return respond(json(response));
      }
      if (request.method === "POST" && url.pathname === "/v1/sync/pull") {
        const pull = parseSyncPullRequestV1(await readJson(request, limits.maxBodyBytes));
        if (pull.cursor !== undefined
            && (!/^\d+$/.test(pull.cursor) || BigInt(pull.cursor) > BigInt(Number.MAX_SAFE_INTEGER))) {
          throw new RequestValidationError("Cursor is not valid for this server");
        }
        const stored = await options.storage.pull(
          pull.cursor ?? null,
          Math.min(pull.limit ?? limits.maxPullLimit, limits.maxPullLimit),
        );
        const response: SyncPullResponseV1 = {
          protocolVersion: SYNC_PROTOCOL_VERSION,
          serverTime: new Date().toISOString(),
          ...stored,
        };
        return respond(json(response));
      }
      return respond(error("not_found", "Route not found", 404));
    } catch (caught) {
      if (caught instanceof RequestValidationError || caught instanceof ContractValidationError) {
        return respond(error("invalid_request", caught.message, 400));
      }
      console.error(JSON.stringify({
        message: "Sync request failed",
        error: caught instanceof Error ? caught.message : "unknown error",
        path: url.pathname,
      }));
      return respond(error("internal_error", "The sync server could not complete the request", 500));
    }
  };
}
