BEGIN;

CREATE TABLE IF NOT EXISTS sync_metadata (
  metadata_key TEXT COLLATE "C" PRIMARY KEY,
  metadata_value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_records (
  record_id TEXT COLLATE "C" PRIMARY KEY,
  namespace_name TEXT COLLATE "C" NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  revision BIGINT NOT NULL CHECK (revision >= 1),
  device_id TEXT COLLATE "C" NOT NULL,
  mutation_id TEXT COLLATE "C" NOT NULL,
  deleted BOOLEAN NOT NULL,
  algorithm TEXT NOT NULL CHECK (algorithm = 'AES-256-GCM'),
  key_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  ciphertext TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_mutations (
  mutation_id TEXT COLLATE "C" PRIMARY KEY,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sync_changes (
  sequence BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  record_id TEXT COLLATE "C" NOT NULL,
  namespace_name TEXT COLLATE "C" NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  revision BIGINT NOT NULL,
  device_id TEXT COLLATE "C" NOT NULL,
  mutation_id TEXT COLLATE "C" NOT NULL UNIQUE,
  deleted BOOLEAN NOT NULL,
  algorithm TEXT NOT NULL CHECK (algorithm = 'AES-256-GCM'),
  key_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  ciphertext TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_changes_sequence ON sync_changes(sequence);
CREATE INDEX IF NOT EXISTS idx_sync_records_namespace ON sync_records(namespace_name);
COMMIT;
