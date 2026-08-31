import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from "react";
import { createDemoEntities } from "../data/demo";
import {
  DEFAULT_PROFILE,
  EMPTY_SYNC_CONFIGURATION,
  isSameSyncConnection,
  nextMutationTimestamp,
  resetSyncCursorWhenWorkspaceChanges,
  type AppNamespace,
  type BodyFatEntry,
  type ChatMessage,
  type FoodEntry,
  type LocalEntity,
  type NamespaceData,
  type SyncConfiguration,
  type UserProfile,
  type WaterEntry,
  type WeightEntry,
  type WorkoutEntry,
} from "../domain";
import { generateEncryptionMaterial } from "../sync/crypto";
import { synchronize } from "../sync/client";
import {
  clearRecords,
  getDeviceId,
  getSyncConfiguration,
  listRecords,
  mergeRemoteRecordsAtomically,
  putRecords,
  replaceRecordsAtomically,
  setSyncConfiguration as persistSyncConfiguration,
  updateRecordAtomically,
} from "./db";

export type SyncState = "local" | "syncing" | "synced" | "error";

interface AppStoreValue {
  ready: boolean;
  initializationError: string;
  records: LocalEntity[];
  profile: UserProfile;
  syncConfiguration: SyncConfiguration;
  syncState: SyncState;
  syncMessage: string;
  entities<N extends AppNamespace>(namespace: N): NamespaceData[N][];
  saveEntity<N extends AppNamespace>(namespace: N, recordId: string, data: NamespaceData[N]): Promise<void>;
  deleteEntity(namespace: AppNamespace, recordId: string): Promise<void>;
  updateProfile(profile: UserProfile): Promise<void>;
  saveSyncConfiguration(configuration: SyncConfiguration): Promise<SyncConfiguration>;
  createPairingKey(configuration?: SyncConfiguration): Promise<SyncConfiguration>;
  syncNow(configuration?: SyncConfiguration): Promise<void>;
  resetDemo(): Promise<void>;
  clearDiary(): Promise<void>;
}

const AppStoreContext = createContext<AppStoreValue | null>(null);

export function AppStoreProvider({ children }: PropsWithChildren) {
  const [ready, setReady] = useState(false);
  const [initializationError, setInitializationError] = useState("");
  const [records, setRecords] = useState<LocalEntity[]>([]);
  const [deviceId, setDeviceId] = useState("");
  const [syncConfiguration, setSyncConfiguration] = useState(EMPTY_SYNC_CONFIGURATION);
  const [syncState, setSyncState] = useState<SyncState>("local");
  const [syncMessage, setSyncMessage] = useState("All changes saved locally");
  const localMutationGeneration = useRef(0);
  const syncInFlight = useRef(false);

  const refresh = useCallback(async () => {
    setRecords(await listRecords());
  }, []);

  useEffect(() => {
    void (async () => {
      try {
        const resolvedDeviceId = await getDeviceId();
        const configuration = await getSyncConfiguration();
        let storedRecords = await listRecords();
        if (storedRecords.length === 0 && import.meta.env.DEV) {
          await putRecords(createDemoEntities(resolvedDeviceId));
          storedRecords = await listRecords();
        }
        setDeviceId(resolvedDeviceId);
        setSyncConfiguration(configuration);
        setRecords(storedRecords);
        // A browser restart cannot prove that every local mutation reached the
        // server, so never claim remote durability until this session syncs.
        setSyncState("local");
        setSyncMessage(configuration.enabled ? "Ready to sync" : "All changes saved locally");
      } catch (error) {
        setInitializationError(error instanceof Error ? error.message : "Browser storage could not be opened");
      } finally {
        setReady(true);
      }
    })();
  }, []);

  const saveEntity = useCallback(async <N extends AppNamespace>(
    namespace: N,
    recordId: string,
    data: NamespaceData[N],
  ) => {
    await updateRecordAtomically(recordId, (previous) => {
      assertRecordNamespaceIsStable(previous, namespace);
      return {
        recordId,
        namespace,
        deleted: false,
        data,
        version: {
          updatedAt: nextMutationTimestamp(previous?.version.updatedAt),
          revision: (previous?.version.revision ?? 0) + 1,
          deviceId,
          mutationId: crypto.randomUUID(),
        },
      } satisfies LocalEntity<NamespaceData[N]>;
    });
    localMutationGeneration.current += 1;
    setSyncState((current) => current === "syncing" ? current : "local");
    setSyncMessage(syncConfiguration.enabled ? "Changes waiting to sync" : "All changes saved locally");
    await refresh();
  }, [deviceId, refresh, syncConfiguration.enabled]);

  const deleteEntity = useCallback(async (namespace: AppNamespace, recordId: string) => {
    await updateRecordAtomically(recordId, (previous) => {
      assertRecordNamespaceIsStable(previous, namespace);
      return {
        recordId,
        namespace,
        deleted: true,
        data: null,
        version: {
          updatedAt: nextMutationTimestamp(previous?.version.updatedAt),
          revision: (previous?.version.revision ?? 0) + 1,
          deviceId,
          mutationId: crypto.randomUUID(),
        },
      };
    });
    localMutationGeneration.current += 1;
    setSyncState((current) => current === "syncing" ? current : "local");
    setSyncMessage(syncConfiguration.enabled ? "Changes waiting to sync" : "All changes saved locally");
    await refresh();
  }, [deviceId, refresh, syncConfiguration.enabled]);

  const entities = useCallback(<N extends AppNamespace>(namespace: N): NamespaceData[N][] => records
    .filter((record) => record.namespace === namespace && !record.deleted && record.data !== null)
    .map((record) => record.data as NamespaceData[N]), [records]);

  const profile = entities("profile")[0] ?? DEFAULT_PROFILE;

  const updateProfile = useCallback(async (nextProfile: UserProfile) => {
    await saveEntity("profile", "profile", nextProfile);
  }, [saveEntity]);

  const saveSyncConfiguration = useCallback(async (configuration: SyncConfiguration) => {
    const safeConfiguration = resetSyncCursorWhenWorkspaceChanges(syncConfiguration, configuration);
    await persistSyncConfiguration(safeConfiguration);
    setSyncConfiguration(safeConfiguration);
    setSyncState(configuration.enabled ? "local" : "local");
    setSyncMessage(configuration.enabled ? "Configuration saved — sync when ready" : "All changes saved locally");
    return safeConfiguration;
  }, [syncConfiguration]);

  const createPairingKey = useCallback(async (configuration = syncConfiguration) => {
    if (configuration.encryptionKey || configuration.keyId) {
      throw new Error("A pairing key already exists. Export it before changing sync servers.");
    }
    const material = await generateEncryptionMaterial();
    const updatedConfiguration = { ...configuration, ...material };
    return saveSyncConfiguration(updatedConfiguration);
  }, [saveSyncConfiguration, syncConfiguration]);

  const syncNow = useCallback(async (configuration = syncConfiguration) => {
    if (syncInFlight.current) return;
    syncInFlight.current = true;
    const startingMutationGeneration = localMutationGeneration.current;
    setSyncState("syncing");
    setSyncMessage("Encrypting and syncing…");
    try {
      const outgoingRecords = await listRecords();
      const result = await synchronize(outgoingRecords, configuration, deviceId);

      const latestConfiguration = await getSyncConfiguration();
      if (!isSameSyncConnection(latestConfiguration, configuration)) {
        throw new Error("Sync connection changed while the request was running; remote results were discarded");
      }

      // IndexedDB serializes this compare-and-write transaction with any local
      // edit, preventing a stale remote winner from overwriting a queued edit.
      await mergeRemoteRecordsAtomically(result.records);
      const updatedConfiguration = { ...latestConfiguration, cursor: result.cursor };
      await persistSyncConfiguration(updatedConfiguration);
      setSyncConfiguration(updatedConfiguration);
      await refresh();
      const newerLocalChanges = localMutationGeneration.current !== startingMutationGeneration;
      const needsAttention = result.rejectedCount > 0 || result.skippedCount > 0;
      setSyncState(needsAttention ? "error" : newerLocalChanges ? "local" : "synced");
      setSyncMessage(result.rejectedCount > 0
        ? `${result.rejectedCount} local record${result.rejectedCount === 1 ? " needs" : "s need"} attention; inbound sync completed. ${result.rejectionMessage}`
        : result.skippedCount > 0
          ? `${result.skippedCount} encrypted record${result.skippedCount === 1 ? " could" : "s could"} not be decrypted; cursor retained`
        : newerLocalChanges
        ? "Sync finished — newer changes are waiting for the next sync"
          : `Encrypted · ${result.acceptedCount} records accepted`);
    } catch (error) {
      setSyncState("error");
      setSyncMessage(error instanceof Error ? error.message : "Sync failed");
    } finally {
      syncInFlight.current = false;
    }
  }, [deviceId, refresh, syncConfiguration]);

  const resetDemo = useCallback(async () => {
    await clearRecords();
    await putRecords(createDemoEntities(deviceId));
    localMutationGeneration.current += 1;
    await refresh();
    setSyncState((current) => current === "syncing" ? current : "local");
    setSyncMessage("Demo data restored locally");
  }, [deviceId, refresh]);

  const clearDiary = useCallback(async () => {
    await replaceRecordsAtomically((currentRecords) => {
      const nextRecords: LocalEntity[] = currentRecords.flatMap((record) => {
        if (record.recordId === "profile") return record.deleted ? [] : [record];
        if (record.deleted) return [record];
        return [{
          ...record,
          deleted: true,
          data: null,
          version: {
            updatedAt: nextMutationTimestamp(record.version.updatedAt),
            revision: record.version.revision + 1,
            deviceId,
            mutationId: crypto.randomUUID(),
          },
        }];
      });
      if (!nextRecords.some((record) => record.recordId === "profile" && !record.deleted)) {
        const previousProfile = currentRecords.find((record) => record.recordId === "profile");
        nextRecords.push({
          recordId: "profile",
          namespace: "profile",
          deleted: false,
          data: profile,
          version: {
            updatedAt: nextMutationTimestamp(previousProfile?.version.updatedAt),
            revision: (previousProfile?.version.revision ?? 0) + 1,
            deviceId,
            mutationId: crypto.randomUUID(),
          },
        });
      }
      return nextRecords;
    });
    localMutationGeneration.current += 1;
    await refresh();
    setSyncState((current) => current === "syncing" ? current : "local");
    setSyncMessage(syncConfiguration.enabled
      ? "Diary cleared — deletion records are waiting to sync"
      : "Local diary cleared");
  }, [deviceId, profile, refresh, syncConfiguration.enabled]);

  const value = useMemo<AppStoreValue>(() => ({
    ready,
    initializationError,
    records,
    profile,
    syncConfiguration,
    syncState,
    syncMessage,
    entities,
    saveEntity,
    deleteEntity,
    updateProfile,
    saveSyncConfiguration,
    createPairingKey,
    syncNow,
    resetDemo,
    clearDiary,
  }), [
    clearDiary,
    createPairingKey,
    deleteEntity,
    entities,
    initializationError,
    profile,
    ready,
    records,
    resetDemo,
    saveEntity,
    saveSyncConfiguration,
    syncConfiguration,
    syncMessage,
    syncNow,
    syncState,
    updateProfile,
  ]);

  return <AppStoreContext.Provider value={value}>{children}</AppStoreContext.Provider>;
}

export function useAppStore(): AppStoreValue {
  const value = useContext(AppStoreContext);
  if (!value) throw new Error("useAppStore must be used inside AppStoreProvider");
  return value;
}

function assertRecordNamespaceIsStable(
  previous: LocalEntity | undefined,
  nextNamespace: AppNamespace,
): void {
  if (previous !== undefined && previous.namespace !== nextNamespace) {
    throw new Error(
      `Record ID ${previous.recordId} already belongs to ${previous.namespace}; record IDs are globally unique`,
    );
  }
}

export type { BodyFatEntry, ChatMessage, FoodEntry, WaterEntry, WeightEntry, WorkoutEntry };
