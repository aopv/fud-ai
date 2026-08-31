# Fud AI self-hosted Web

This workspace contains the optional Fud AI Web PWA and its opt-in encrypted
sync service. The browser keeps the working copy in IndexedDB and encrypts sync
records before upload. A self-hosted server stores opaque envelopes; it does not
receive the pairing key, decrypted diary data, or AI-provider credentials.

The PWA works without a sync server. Enable sync in **Settings → Encrypted
Sync** only when you want to copy encrypted changes between browsers.

## Current scope

- The Web app includes the nutrition diary, water logs, weight/body-fat trends,
  workout logs, a private local Coach summary, goals, export, and offline PWA
  installation.
- Encrypted sync currently connects Web browsers that share the same pairing
  bundle. The iOS and Android apps are not sync clients yet, so this release
  does not claim native-to-Web synchronization.
- HealthKit and Health Connect remain native-only. Browsers cannot read either
  store directly.
- Connecting this directory to a hosting provider gives normal Git-triggered
  redeploys for future Web changes. SwiftUI and Compose screens cannot be
  converted into React automatically; equivalent Web UI changes still need to
  be implemented in this workspace.

## Choose a deployment

| Target | Web PWA | Sync storage | Guide |
| --- | --- | --- | --- |
| Docker Compose | Served by the Node process | Bundled PostgreSQL | [Docker](deploy/docker/README.md) |
| Vercel | Vercel static deployment | External PostgreSQL | [Vercel](deploy/vercel/README.md) |
| Cloudflare | Workers Static Assets | D1 | [Cloudflare](adapters/cloudflare/README.md) |

All three targets serve the PWA and `/v1` API from one origin. This is the
simplest privacy-preserving setup: point a custom domain at the deployment and
leave `CORS_ORIGINS` empty. Add exact comma-separated origins only when a
separately hosted browser client must call the API.

## Local development

Node.js 22 or newer is required.

```sh
npm ci
npm run build
```

Start PostgreSQL, apply
`adapters/postgres/migrations/0001_init.sql`, and run the sync service:

```sh
DATABASE_URL=postgresql://localhost/fud_ai_sync \
SYNC_TOKEN=replace-with-at-least-32-random-characters \
npm run dev:server
```

In another terminal, run the PWA. Vite proxies `/v1` to the local sync service.

```sh
npm run dev
```

## Runtime configuration

| Variable | Used by | Meaning |
| --- | --- | --- |
| `SYNC_TOKEN` | Every sync server | Shared bearer token, at least 32 characters. Treat it like a password. |
| `DATABASE_URL` | Node/Vercel | PostgreSQL connection string. |
| `PGSSL` | Node/Vercel | Set to `true` when PostgreSQL requires verified TLS. |
| `PGPOOL_MAX` | Node/Vercel | Maximum connections per process or warm function. Node defaults to 10; the Vercel entry point defaults to 2. |
| `CORS_ORIGINS` | Every sync server | Optional comma-separated list of additional exact browser origins. Avoid `*` in production. |
| `SERVICE_VERSION` | Every sync server | Version reported by `/v1/info`; defaults to `0.1.0`. |
| `PORT` | Standalone Node | Listening port; defaults to `8787`. |
| `WEB_DIST_DIR` | Standalone Node | Built PWA directory. The Docker image sets this automatically. |

Cloudflare uses the `SYNC_DB`, `ASSETS`, and secret `SYNC_TOKEN` bindings
instead of `DATABASE_URL`.

## Production checklist

- Use HTTPS. Browser installation, service workers, and camera features require
  a secure context outside localhost.
- Generate an independent random `SYNC_TOKEN`; do not reuse a login or API key.
- Apply database migrations before switching traffic to a new server release.
- Put the Node deployment behind a TLS reverse proxy and keep PostgreSQL private.
- Back up PostgreSQL or D1, and separately preserve the pairing bundle. A
  database backup cannot recover data without the client-held pairing key.
- Check `GET /v1/health` after deployment and `GET /v1/info` when diagnosing a
  protocol mismatch.

One sync deployment is one trust boundary: anyone with its bearer token can
read and write encrypted envelopes, although decryption still requires the
pairing key. Use separate deployments or tokens for unrelated groups.
