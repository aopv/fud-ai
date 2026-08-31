import { createServer } from "node:http";
import { createNodeSyncHandler } from "./index.js";
import { createStaticHandler } from "./static.js";

const port = Number(process.env.PORT ?? "8787");
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("PORT must be a valid TCP port");
const { handler, storage } = createNodeSyncHandler();
const staticHandler = process.env.WEB_DIST_DIR ? createStaticHandler(process.env.WEB_DIST_DIR) : null;
const server = createServer((request, response) => {
  const pathname = new URL(request.url ?? "/", "http://localhost").pathname;
  const isApiRequest = pathname === "/v1" || pathname.startsWith("/v1/");
  const selectedHandler = isApiRequest || staticHandler === null ? handler : staticHandler;
  void selectedHandler(request, response).catch((error: unknown) => {
    console.error(JSON.stringify({
      message: "Request failed",
      error: error instanceof Error ? error.message : "unknown error",
      path: pathname,
    }));
    if (!response.headersSent) response.statusCode = 500;
    response.end();
  });
});
server.listen(port, "0.0.0.0", () => console.log(JSON.stringify({ message: "Fud AI listening", port })));

async function shutdown(): Promise<void> {
  server.close();
  await storage.close();
}
process.once("SIGINT", () => { void shutdown(); });
process.once("SIGTERM", () => { void shutdown(); });
