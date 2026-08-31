# Fud AI sync contracts

Strict TypeScript types and dependency-free runtime validators for version 1 of
Fud AI's self-hosted sync protocol.

The sync service sees record identifiers, namespaces, version metadata and opaque
ciphertext. It never receives plaintext health data or encryption keys. Keys are
created, stored and used by clients only. Every record uses AES-256-GCM with a
unique 12-byte nonce. Deletion is an encrypted tombstone, so a server cannot
forge or remove the deletion flag without failing client authentication.

## Record identity

`recordId` is globally unique inside one sync workspace, across every namespace.
The namespace is authenticated metadata and is not part of the storage key.
Clients should use a UUID for new records; stable singleton identifiers such as
`profile` must be reserved globally. A push containing the same record ID more
than once is invalid, including when the duplicates claim different namespaces.

## Authenticated envelope metadata

All visible metadata that affects conflict resolution or record interpretation is
authenticated as AES-GCM additional authenticated data (AAD). The normative AAD
is the UTF-8 encoding of the JSON array returned by
`serializeSyncRecordAadV1`, in this exact order:

```text
[domain, protocolVersion, recordId, namespace, updatedAt, revision,
 deviceId, mutationId, deleted, keyId]
```

The domain is `fud-ai-e2ee-sync-record-v1`. Tombstones encrypt the exact JSON
object `{"tombstone":true}` and otherwise have the same required encrypted
payload shape as live records. Before decryption, clients must require the
payload `keyId` to match the configured pairing-key identifier. Modifying any
AAD field, substituting a key ID, or changing a live record into a tombstone
causes authentication to fail.

## Usage

```ts
import {
  parseSyncPushRequestV1,
  selectLwwWinner,
} from "@fud-ai/sync-contracts";

const request = parseSyncPushRequestV1(await httpRequest.json());
const winner = selectLwwWinner(storedRecord, request.records[0]);
```

All inbound network data must pass a `parse*` or `validate*` function before use.
Unknown fields, unsupported protocol versions, invalid encryption envelopes and
oversized batches are rejected. Last-write-wins comparison is deterministic and
uses timestamp, revision, device id, then mutation id.

Run `npm test` to compile under strict TypeScript and execute the unit suite.
