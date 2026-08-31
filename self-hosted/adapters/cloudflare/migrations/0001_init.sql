PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS sync_metadata (
  metadata_key TEXT COLLATE BINARY PRIMARY KEY,
  metadata_value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_records (
  record_id TEXT COLLATE BINARY PRIMARY KEY,
  namespace_name TEXT COLLATE BINARY NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL CHECK (revision >= 1),
  device_id TEXT COLLATE BINARY NOT NULL,
  mutation_id TEXT COLLATE BINARY NOT NULL,
  deleted INTEGER NOT NULL CHECK (deleted IN (0, 1)),
  algorithm TEXT NOT NULL CHECK (algorithm = 'AES-256-GCM'),
  key_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  ciphertext TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_mutations (
  mutation_id TEXT COLLATE BINARY PRIMARY KEY,
  received_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sync_changes (
  sequence INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id TEXT COLLATE BINARY NOT NULL,
  namespace_name TEXT COLLATE BINARY NOT NULL,
  updated_at TEXT NOT NULL,
  revision INTEGER NOT NULL,
  device_id TEXT COLLATE BINARY NOT NULL,
  mutation_id TEXT COLLATE BINARY NOT NULL UNIQUE,
  deleted INTEGER NOT NULL CHECK (deleted IN (0, 1)),
  algorithm TEXT NOT NULL CHECK (algorithm = 'AES-256-GCM'),
  key_id TEXT NOT NULL,
  nonce TEXT NOT NULL,
  ciphertext TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sync_changes_sequence ON sync_changes(sequence);
CREATE INDEX IF NOT EXISTS idx_sync_records_namespace ON sync_records(namespace_name);
