import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import type { IncomingMessage, ServerResponse } from "node:http";
import { extname, resolve, sep } from "node:path";

const CONTENT_TYPES: Record<string, string> = {
  ".css": "text/css; charset=utf-8",
  ".html": "text/html; charset=utf-8",
  ".ico": "image/x-icon",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".webmanifest": "application/manifest+json",
};
const CONTENT_SECURITY_POLICY = [
  "default-src 'self'",
  "base-uri 'none'",
  "connect-src 'self' https: http:",
  "font-src 'self'",
  "form-action 'self'",
  "frame-ancestors 'none'",
  "img-src 'self' data: blob:",
  "manifest-src 'self'",
  "object-src 'none'",
  "script-src 'self'",
  "style-src 'self' 'unsafe-inline'",
  "worker-src 'self' blob:",
].join("; ");

function safePath(root: string, pathname: string): string | null {
  let decoded: string;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  const candidate = resolve(root, `.${decoded}`);
  const rootPrefix = root.endsWith(sep) ? root : `${root}${sep}`;
  return candidate === root || candidate.startsWith(rootPrefix) ? candidate : null;
}

async function isFile(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isFile();
  } catch {
    return false;
  }
}

export function createStaticHandler(directory: string) {
  const root = resolve(directory);
  const indexPath = resolve(root, "index.html");
  return async (request: IncomingMessage, response: ServerResponse): Promise<void> => {
    if (request.method !== "GET" && request.method !== "HEAD") {
      response.statusCode = 405;
      response.setHeader("allow", "GET, HEAD");
      response.end();
      return;
    }
    const pathname = new URL(request.url ?? "/", "http://localhost").pathname;
    const resolved = safePath(root, pathname);
    if (resolved === null) {
      response.statusCode = 400;
      response.end("Bad request");
      return;
    }
    const requestedFile = await isFile(resolved) ? resolved : indexPath;
    if (!(await isFile(requestedFile))) {
      response.statusCode = 404;
      response.end("Fud AI Web has not been built");
      return;
    }
    const extension = extname(requestedFile).toLowerCase();
    response.statusCode = 200;
    response.setHeader("content-type", CONTENT_TYPES[extension] ?? "application/octet-stream");
    response.setHeader("x-content-type-options", "nosniff");
    response.setHeader("referrer-policy", "no-referrer");
    response.setHeader("permissions-policy", "camera=(self), microphone=(self), geolocation=()");
    response.setHeader("cross-origin-opener-policy", "same-origin");
    response.setHeader("content-security-policy", CONTENT_SECURITY_POLICY);
    if (requestedFile.includes(`${sep}assets${sep}`)) {
      response.setHeader("cache-control", "public, max-age=31536000, immutable");
    } else {
      response.setHeader("cache-control", "no-cache");
    }
    if (request.method === "HEAD") {
      response.end();
      return;
    }
    await new Promise<void>((complete, reject) => {
      const stream = createReadStream(requestedFile);
      stream.once("error", reject);
      response.once("finish", complete);
      stream.pipe(response);
    });
  };
}
