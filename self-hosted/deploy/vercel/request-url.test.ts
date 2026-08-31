import assert from "node:assert/strict";
import test from "node:test";
import { restorePublicSyncUrl } from "../../api/sync.js";

test("restores a rewritten nested sync route and preserves other query parameters", () => {
  assert.equal(
    restorePublicSyncUrl("/api/sync?cursor=opaque%20cursor&path=sync%2Fpull&limit=50"),
    "/v1/sync/pull?cursor=opaque+cursor&limit=50",
  );
});

test("restores the API namespace root when a rewrite has no path parameter", () => {
  assert.equal(restorePublicSyncUrl("/api/sync"), "/v1");
});

test("leaves an original public sync URL intact", () => {
  assert.equal(restorePublicSyncUrl("/v1/info?detail=full"), "/v1/info?detail=full");
});
