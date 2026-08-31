# Vercel deployment

This target publishes the complete PWA and the `/v1` sync API. The authoritative
Vercel configuration and function entry point are `vercel.json` and
`api/sync.ts` at the workspace root; the former backend-only nested
configuration has been removed.

## Prerequisites

Create a managed PostgreSQL database reachable from Vercel, then apply the
schema before the first deployment:

```sh
psql "$DATABASE_URL" -f adapters/postgres/migrations/0001_init.sql
```

Use the provider's pooled connection URL when it offers one. Keep the Vercel
function region close to the database and confirm that the provider's connection
limit can support the deployment's concurrency.

Configure these Vercel environment variables for Production and any Preview
environment you intend to use:

- `DATABASE_URL`: the PostgreSQL connection string.
- `SYNC_TOKEN`: an independent random value of at least 32 characters.
- `PGSSL=true`: when the provider requires verified TLS.
- `PGPOOL_MAX`: optional; the Vercel entry point defaults to 2 connections per
  warm function.
- `CORS_ORIGINS`: optional exact comma-separated origins for separately hosted
  browser clients. Leave it unset for the PWA served by this deployment.
- `SERVICE_VERSION`: optional release label reported by `/v1/info`.

The server never needs the client pairing key or an AI-provider key. Do not add
either one to Vercel.

## Deploy

When importing the repository in Vercel, set **Root Directory** to
`self-hosted`. Do not override the checked-in Build Command or Output Directory;
the root configuration builds the ordered workspace dependencies, emits
`apps/web/dist`, and deploys `api/sync.ts` as a Node function.

For a CLI deployment, run from `self-hosted`:

```sh
npx vercel
npx vercel --prod
```

Attach the custom domain in Vercel after the first successful deployment. Then
open the PWA at that domain and use the same origin as the sync server URL in
Settings. Verify both surfaces:

```sh
curl https://your-domain.example/v1/health
curl https://your-domain.example/v1/info
```

Vercel does not run PostgreSQL migrations automatically. Apply every new
numbered migration before deploying a release that depends on it.
