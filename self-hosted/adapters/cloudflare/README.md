# Cloudflare D1 deployment

From the `self-hosted` directory, create a D1 database and place its identifier
in `adapters/cloudflare/wrangler.jsonc`. Leave `CORS_ORIGINS` empty when the PWA
and API use the same Worker domain; otherwise list only the exact additional
browser origins. Then build the app, apply the migration, and configure the
bearer token without committing it:

```sh
npm run build
npx wrangler --config adapters/cloudflare/wrangler.jsonc d1 migrations apply fud-ai-sync --remote
npx wrangler --config adapters/cloudflare/wrangler.jsonc secret put SYNC_TOKEN
npx wrangler --config adapters/cloudflare/wrangler.jsonc deploy
```

The Worker serves the Web PWA and sync API from one domain. `CORS_ORIGINS` is
only needed for additional browser origins; clients that do not send an Origin
header do not need a CORS entry. A custom domain can be attached after
deployment. Encryption keys and AI-provider API keys stay on paired clients and
must not be added as Worker secrets.

Verify `https://your-domain.example/v1/health` and `/v1/info` after deployment.
Re-run `npm run types --workspace @fud-ai/adapter-cloudflare` after changing
bindings. Apply every new numbered D1 migration before deploying a release that
depends on it.
