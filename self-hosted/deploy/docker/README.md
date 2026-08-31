# Docker deployment

Docker Compose runs PostgreSQL plus one Node process that serves both the Web PWA
and `/v1` API. From this directory, create the local environment file and
replace both secret placeholders:

```sh
cp .env.example .env
docker compose --env-file .env -f compose.yaml up --build -d
```

Generate URL-safe random values with `openssl rand -hex 32`. `CORS_ORIGINS` can
stay empty when the PWA and API use the same domain. Set it only to exact,
comma-separated origins for additional browser clients.

Open `http://localhost:8787` for a local check. In production, put a TLS reverse
proxy in front of port 8787 and point the chosen domain to it; service workers,
installation, and camera features require HTTPS outside localhost. PostgreSQL is
not published to the host.

Check the deployment with:

```sh
curl http://localhost:8787/v1/health
curl http://localhost:8787/v1/info
```

The initial migration is applied automatically only when Docker creates the
database volume for the first time. Apply later numbered migrations before
upgrading the application container. Rebuild with the checked-in lockfile by
running the same `up --build -d` command.

Back up the database regularly, for example:

```sh
docker compose --env-file .env -f compose.yaml exec -T postgres \
  pg_dump -U fud_ai -d fud_ai_sync > fud-ai-sync.sql
```

Also preserve the client pairing bundle securely. The database contains only
encrypted envelopes and cannot restore the pairing key.
