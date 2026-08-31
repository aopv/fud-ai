import type { IncomingMessage, ServerResponse } from "node:http";
import { createNodeSyncHandler } from "@fud-ai/server-node";

type NodeHandler = ReturnType<typeof createNodeSyncHandler>["handler"];
let cachedHandler: NodeHandler | undefined;

function getHandler(): NodeHandler {
  cachedHandler ??= createNodeSyncHandler({
    ...process.env,
    // Keep each warm function's pool deliberately small. Override only when the
    // database connection budget and Vercel concurrency are understood together.
    PGPOOL_MAX: process.env.PGPOOL_MAX ?? "2",
  }).handler;
  return cachedHandler;
}

/** Restore the public API path after Vercel rewrites its catch-all parameter. */
export function restorePublicSyncUrl(rawUrl: string | undefined): string {
  const url = new URL(rawUrl ?? "/api/sync", "http://localhost");
  if (url.pathname === "/v1" || url.pathname.startsWith("/v1/")) {
    return `${url.pathname}${url.search}`;
  }

  const route = url.searchParams.get("path")?.replace(/^\/+|\/+$/g, "") ?? "";
  url.searchParams.delete("path");
  const encodedRoute = route
    .split("/")
    .filter(Boolean)
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  const publicPath = encodedRoute.length > 0 ? `/v1/${encodedRoute}` : "/v1";
  return `${publicPath}${url.search}`;
}

export default function sync(request: IncomingMessage, response: ServerResponse): Promise<void> {
  request.url = restorePublicSyncUrl(request.url);
  return getHandler()(request, response);
}
