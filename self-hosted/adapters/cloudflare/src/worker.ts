import { createSyncHandler } from "@fud-ai/server-core";
import { D1SyncStorage } from "./index.js";

// Wrangler generates every declared binding. Secrets intentionally stay out of
// wrangler.jsonc, so the runtime-only secret is added as a narrow intersection.
type RuntimeEnv = Env & { SYNC_TOKEN: string };

export default {
  async fetch(request: Request, env: RuntimeEnv): Promise<Response> {
    const pathname = new URL(request.url).pathname;
    if (pathname !== "/v1" && !pathname.startsWith("/v1/")) return env.ASSETS.fetch(request);
    const handler = createSyncHandler({
      storage: new D1SyncStorage(env.SYNC_DB),
      bearerToken: env.SYNC_TOKEN,
      allowedOrigins: env.CORS_ORIGINS?.split(",").map((origin) => origin.trim()).filter(Boolean) ?? [],
      serviceVersion: env.SERVICE_VERSION ?? "0.1.0",
    });
    return handler(request);
  },
} satisfies ExportedHandler<RuntimeEnv>;
