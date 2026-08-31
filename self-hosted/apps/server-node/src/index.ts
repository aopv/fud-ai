import { Readable } from "node:stream";
import type { IncomingMessage, ServerResponse } from "node:http";
import { PostgresSyncStorage } from "@fud-ai/adapter-postgres";
import { createSyncHandler } from "@fud-ai/server-core";

export interface NodeSyncEnvironment {
  DATABASE_URL: string;
  SYNC_TOKEN: string;
  CORS_ORIGINS?: string;
  PGPOOL_MAX?: string;
  PGSSL?: string;
  SERVICE_VERSION?: string;
}

function required(environment: Partial<NodeSyncEnvironment>, key: "DATABASE_URL" | "SYNC_TOKEN"): string {
  const value = environment[key];
  if (value === undefined || value.length === 0) throw new Error(`${key} is required`);
  return value;
}

function poolSize(value: string | undefined): number {
  if (value === undefined || value.length === 0) return 10;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 100) {
    throw new Error("PGPOOL_MAX must be an integer between 1 and 100");
  }
  return parsed;
}

export function createNodeSyncHandler(environment: Partial<NodeSyncEnvironment> = process.env) {
  const postgresConfig = {
    connectionString: required(environment, "DATABASE_URL"),
    max: poolSize(environment.PGPOOL_MAX),
    ...(environment.PGSSL === "true" ? { ssl: { rejectUnauthorized: true } } : {}),
  };
  const storage = new PostgresSyncStorage(postgresConfig);
  const fetchHandler = createSyncHandler({
    storage,
    bearerToken: required(environment, "SYNC_TOKEN"),
    allowedOrigins: environment.CORS_ORIGINS?.split(",").map((value) => value.trim()).filter(Boolean) ?? [],
    serviceVersion: environment.SERVICE_VERSION ?? "0.1.0",
  });
  return { handler: nodeHandler(fetchHandler), storage };
}

export function nodeHandler(fetchHandler: (request: Request) => Promise<Response>) {
  return async (incoming: IncomingMessage, outgoing: ServerResponse): Promise<void> => {
    try {
      const host = incoming.headers.host ?? "localhost";
      const forwardedProtocol = incoming.headers["x-forwarded-proto"];
      const protocol = typeof forwardedProtocol === "string" ? (forwardedProtocol.split(",", 1)[0] ?? "http") : "http";
      const headers = new Headers();
      for (const [name, value] of Object.entries(incoming.headers)) {
        if (Array.isArray(value)) value.forEach((item) => headers.append(name, item));
        else if (value !== undefined) headers.set(name, value);
      }
      const method = incoming.method ?? "GET";
      const init: RequestInit & { duplex?: "half" } = { method, headers };
      if (method !== "GET" && method !== "HEAD") {
        init.body = Readable.toWeb(incoming) as ReadableStream<Uint8Array>;
        init.duplex = "half";
      }
      const response = await fetchHandler(new Request(`${protocol}://${host}${incoming.url ?? "/"}`, init));
      outgoing.statusCode = response.status;
      response.headers.forEach((value, name) => outgoing.setHeader(name, value));
      if (response.body === null) outgoing.end();
      else Readable.fromWeb(response.body as import("node:stream/web").ReadableStream).pipe(outgoing);
    } catch {
      outgoing.statusCode = 500;
      outgoing.setHeader("content-type", "application/json; charset=utf-8");
      outgoing.end(JSON.stringify({ error: { code: "internal_error", message: "Request failed" } }));
    }
  };
}

export { createStaticHandler } from "./static.js";
