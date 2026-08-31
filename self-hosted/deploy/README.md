# Deployment guides

Each supported deployment serves both the installable Web PWA and the encrypted
`/v1` sync API from one domain:

- [Docker Compose](docker/README.md) for a single host with PostgreSQL included.
- [Vercel](vercel/README.md) for static hosting and a Node function backed by an
  external PostgreSQL database.
- [Cloudflare](../adapters/cloudflare/README.md) for Workers Static Assets and
  D1.

Start with the [workspace README](../README.md) for the shared security model,
environment variables, and production checklist.
