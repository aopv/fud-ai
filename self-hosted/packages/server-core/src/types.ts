import type { SyncRecordEnvelopeV1, SyncRejectedRecordV1 } from "@fud-ai/sync-contracts";

export interface StoragePushResult {
  acceptedRecordIds: string[];
  conflicts: SyncRecordEnvelopeV1[];
  rejected: SyncRejectedRecordV1[];
  cursor: string;
}

export interface StoragePullResult {
  records: SyncRecordEnvelopeV1[];
  cursor: string;
  hasMore: boolean;
}

export interface SyncStorage {
  /** Returns false when the backing store is not ready. */
  health(): Promise<boolean>;
  push(records: readonly SyncRecordEnvelopeV1[]): Promise<StoragePushResult>;
  pull(cursor: string | null, limit: number): Promise<StoragePullResult>;
  close?(): Promise<void>;
}

export interface SyncServerLimits {
  maxBodyBytes?: number;
  maxRecordBytes?: number;
  maxCiphertextBytes?: number;
  maxRecordsPerPush?: number;
  maxPullLimit?: number;
}

export interface SyncServerOptions {
  storage: SyncStorage;
  bearerToken: string;
  /** Exact origins or `*`. Empty means same-origin/non-browser clients only. */
  allowedOrigins?: readonly string[];
  limits?: SyncServerLimits;
  serviceName?: string;
  serviceVersion?: string;
}
