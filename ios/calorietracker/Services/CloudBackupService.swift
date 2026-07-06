import Foundation
import CloudKit
import CryptoKit
import SwiftUI

/// Everything worth keeping if the phone dies, minus photos. Food photos and
/// Coach image attachments are deliberately excluded — they dominate the size
/// and add nothing to a restore. Entry UUIDs are preserved, so a cloud restore
/// and the Apple Health restore merge cleanly instead of duplicating, and
/// HealthKit edits/deletes keep targeting the right samples afterwards.
struct BackupSnapshot: Codable {
    var version: Int = 1
    var createdAt: Date
    var foodEntries: [FoodEntry]
    var favorites: [FoodEntry]
    var weightEntries: [WeightEntry]
    var bodyFatEntries: [BodyFatEntry]
    var bodyMeasurements: [BodyMeasurement]
    var chatMessages: [ChatMessage]
    var profile: UserProfile?
    var optionalNutrientGoals: OptionalNutrientGoals?
    /// Simple preference values keyed by their UserDefaults key. Bools are
    /// stored as "true"/"false"; the kind table below restores the right type.
    var settings: [String: String]
}

/// One-blob iCloud backup: the whole snapshot is a single CKRecord in the
/// user's private CloudKit database, overwritten on every backup. Snapshot
/// semantics mean deletions propagate naturally — an entry deleted in-app is
/// simply absent from the next backup. No accounts, no servers of ours; the
/// data lives in the user's own iCloud. API keys are NOT included (iCloud
/// Keychain already syncs those securely).
@Observable
final class CloudBackupService {
    static let shared = CloudBackupService()

    static let enabledKey = "iCloudBackupEnabled"
    static let lastBackupDateKey = "iCloudBackupLastDate"
    private static let lastBackupHashKey = "iCloudBackupLastHash"
    private static let containerID = "iCloud.com.apoorvdarshan.calorietracker"
    private static let recordType = "FudAIBackup"
    private static let recordName = "current-backup"

    var isWorking = false

    enum BackupError: Error {
        case accountUnavailable
        case noBackupFound
    }

    /// (key, isBool) pairs of the simple preferences worth carrying to a new
    /// phone. Notification toggles stay out — they're tied to a per-device
    /// permission grant and restoring them without it would just confuse.
    private static let settingsKeys: [(key: String, isBool: Bool)] = [
        (AppThemeColor.storageKey, false),
        ("appearanceMode", false),
        (HeightUnit.storageKey, false),
        (WeightUnit.storageKey, false),
        ("weekStartsOnMonday", true),
        (FoodLogSortOrder.storageKey, false),
        (HomeTopNutrient.storageKey, false),
        (FoodMeasurementSettings.preferGramsByDefaultKey, true),
        (AdaptiveGoalSettings.enabledKey, true),
        (EnergyBurnSettings.enabledKey, true),
    ]

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Stored as timeIntervalSinceReferenceDate (Double) so the Settings
    /// footer can observe it directly through @AppStorage.
    static var lastBackupDate: Date? {
        let interval = UserDefaults.standard.double(forKey: lastBackupDateKey)
        return interval > 0 ? Date(timeIntervalSinceReferenceDate: interval) : nil
    }

    // MARK: - Snapshot build / apply

    func makeSnapshot(
        foodStore: FoodStore,
        weightStore: WeightStore,
        bodyFatStore: BodyFatStore,
        bodyMeasurementStore: BodyMeasurementStore,
        chatStore: ChatStore
    ) -> BackupSnapshot {
        var settings: [String: String] = [:]
        let defaults = UserDefaults.standard
        for entry in Self.settingsKeys {
            if entry.isBool {
                if defaults.object(forKey: entry.key) != nil {
                    settings[entry.key] = defaults.bool(forKey: entry.key) ? "true" : "false"
                }
            } else if let value = defaults.string(forKey: entry.key) {
                settings[entry.key] = value
            }
        }
        return BackupSnapshot(
            createdAt: .now,
            foodEntries: foodStore.entries.map(Self.strippedOfImages),
            favorites: foodStore.favorites.map(Self.strippedOfImages),
            weightEntries: weightStore.entries,
            bodyFatEntries: bodyFatStore.entries,
            bodyMeasurements: bodyMeasurementStore.entries,
            chatMessages: chatStore.messages.map { message in
                ChatMessage(id: message.id, role: message.role, content: message.content, timestamp: message.timestamp)
            },
            profile: UserProfile.load(),
            optionalNutrientGoals: OptionalNutrientGoals.current,
            settings: settings
        )
    }

    /// Merge a fetched snapshot into the live stores. Entries merge by UUID
    /// (backup wins for the same id — it can only be richer, never staler for
    /// a same-id record; anything logged after the backup has a new id and is
    /// untouched). Nothing here echoes back to HealthKit — merge paths bypass
    /// the per-entry-added callbacks; the nutrition/weight samples for backed
    /// up entries already exist in Health.
    func apply(
        _ snapshot: BackupSnapshot,
        foodStore: FoodStore,
        weightStore: WeightStore,
        bodyFatStore: BodyFatStore,
        bodyMeasurementStore: BodyMeasurementStore,
        chatStore: ChatStore
    ) {
        foodStore.mergeWithCloudEntries(snapshot.foodEntries)
        foodStore.mergeWithCloudFavorites(snapshot.favorites)
        weightStore.mergeWithCloudEntries(snapshot.weightEntries)

        let existingBodyFat = Set(bodyFatStore.entries.map(\.id))
        let missingBodyFat = snapshot.bodyFatEntries.filter { !existingBodyFat.contains($0.id) }
        if !missingBodyFat.isEmpty {
            bodyFatStore.replaceAllEntries((bodyFatStore.entries + missingBodyFat).sorted { $0.date < $1.date })
        }

        let existingMeasurements = Set(bodyMeasurementStore.entries.map(\.id))
        let missingMeasurements = snapshot.bodyMeasurements.filter { !existingMeasurements.contains($0.id) }
        if !missingMeasurements.isEmpty {
            bodyMeasurementStore.replaceAllEntries((bodyMeasurementStore.entries + missingMeasurements).sorted { $0.date < $1.date })
        }

        chatStore.mergeWithCloudMessages(snapshot.chatMessages)

        if let profile = snapshot.profile {
            profile.save()
        }
        if let goals = snapshot.optionalNutrientGoals {
            OptionalNutrientGoals.save(goals)
        }
        let defaults = UserDefaults.standard
        for entry in Self.settingsKeys {
            guard let raw = snapshot.settings[entry.key] else { continue }
            if entry.isBool {
                defaults.set(raw == "true", forKey: entry.key)
            } else {
                defaults.set(raw, forKey: entry.key)
            }
        }
    }

    private static func strippedOfImages(_ entry: FoodEntry) -> FoodEntry {
        var stripped = entry
        stripped.imageData = nil
        stripped.imageFilename = nil
        return stripped
    }

    // MARK: - CloudKit I/O

    /// Uploads the current snapshot, skipping the network round trip entirely
    /// when nothing changed since the last successful backup (content hash).
    /// Called from the scene-background hook; `force` is the Back Up Now button.
    func backUp(
        force: Bool = false,
        foodStore: FoodStore,
        weightStore: WeightStore,
        bodyFatStore: BodyFatStore,
        bodyMeasurementStore: BodyMeasurementStore,
        chatStore: ChatStore
    ) async throws {
        guard Self.isEnabled else { return }
        var snapshot = makeSnapshot(
            foodStore: foodStore, weightStore: weightStore, bodyFatStore: bodyFatStore,
            bodyMeasurementStore: bodyMeasurementStore, chatStore: chatStore
        )
        // Hash with a fixed createdAt so the timestamp itself never counts as a
        // change. SHA256, not hashValue — Swift's hashValue is seeded per launch
        // and would report "changed" on every cold start.
        snapshot.createdAt = Date(timeIntervalSince1970: 0)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let hashData = try encoder.encode(snapshot)
        let hash = SHA256.hash(data: hashData).map { String(format: "%02x", $0) }.joined()
        if !force, hash == UserDefaults.standard.string(forKey: Self.lastBackupHashKey) { return }

        guard await accountAvailable() else { throw BackupError.accountUnavailable }
        isWorking = true
        defer { isWorking = false }

        snapshot.createdAt = .now
        let data = try encoder.encode(snapshot)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fudai-backup-upload.json")
        try data.write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: Self.recordName))
        record["snapshot"] = CKAsset(fileURL: fileURL)
        record["createdAt"] = snapshot.createdAt as NSDate

        let database = CKContainer(identifier: Self.containerID).privateCloudDatabase
        let results = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        for (_, result) in results.saveResults {
            if case .failure(let error) = result { throw error }
        }
        UserDefaults.standard.set(hash, forKey: Self.lastBackupHashKey)
        UserDefaults.standard.set(Date.now.timeIntervalSinceReferenceDate, forKey: Self.lastBackupDateKey)
    }

    func fetchSnapshot() async throws -> BackupSnapshot {
        guard await accountAvailable() else { throw BackupError.accountUnavailable }
        isWorking = true
        defer { isWorking = false }
        let database = CKContainer(identifier: Self.containerID).privateCloudDatabase
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: Self.recordName))
            guard let asset = record["snapshot"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else {
                throw BackupError.noBackupFound
            }
            return try JSONDecoder().decode(BackupSnapshot.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            throw BackupError.noBackupFound
        }
    }

    private func accountAvailable() async -> Bool {
        let status = try? await CKContainer(identifier: Self.containerID).accountStatus()
        return status == .available
    }
}

// MARK: - Settings UI

/// The "Backup" section in Settings. Self-contained so ContentView only has
/// to drop it in after Health & Data.
struct CloudBackupSettingsSection: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(BodyMeasurementStore.self) private var bodyMeasurementStore
    @Environment(ChatStore.self) private var chatStore
    @AppStorage(CloudBackupService.enabledKey) private var backupEnabled = false
    @AppStorage(CloudBackupService.lastBackupDateKey) private var lastBackupTimestamp = 0.0
    @State private var statusMessage: String?
    @State private var showStatusAlert = false

    private var service: CloudBackupService { .shared }

    var body: some View {
        Section {
            HStack {
                Label {
                    Text("iCloud Backup")
                } icon: {
                    Image(systemName: "icloud.fill")
                        .foregroundStyle(.blue)
                }
                Spacer()
                Toggle("", isOn: $backupEnabled)
                    .labelsHidden()
                    .onChange(of: backupEnabled) { _, enabled in
                        if enabled { runBackup(force: true) }
                    }
            }

            if backupEnabled {
                Button {
                    runBackup(force: true)
                } label: {
                    Label {
                        Text("Back Up Now")
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(service.isWorking)

                Button {
                    runRestore()
                } label: {
                    Label {
                        Text("Restore from Backup")
                    } icon: {
                        Image(systemName: "icloud.and.arrow.down")
                            .foregroundStyle(.green)
                    }
                }
                .buttonStyle(.plain)
                .disabled(service.isWorking)
            }
        } header: {
            Text("Backup")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("Backs up your food log, weight, goals, Coach chat, and settings to your iCloud. Photos are not included.")
                if backupEnabled {
                    if lastBackupTimestamp > 0 {
                        Text("Last backup: \(Date(timeIntervalSinceReferenceDate: lastBackupTimestamp).formatted(date: .abbreviated, time: .shortened))")
                    } else {
                        Text("No backup yet")
                    }
                }
            }
        }
        .alert(statusMessage ?? "", isPresented: $showStatusAlert) {
            Button("OK", role: .cancel) {}
        }
    }

    private func runBackup(force: Bool) {
        Task {
            do {
                try await service.backUp(
                    force: force,
                    foodStore: foodStore, weightStore: weightStore, bodyFatStore: bodyFatStore,
                    bodyMeasurementStore: bodyMeasurementStore, chatStore: chatStore
                )
                if force { show(String(localized: "Backup complete")) }
            } catch CloudBackupService.BackupError.accountUnavailable {
                show(String(localized: "iCloud unavailable — check that you're signed in to iCloud."))
            } catch {
                show(String(localized: "Backup failed"))
            }
        }
    }

    private func runRestore() {
        Task {
            do {
                let snapshot = try await service.fetchSnapshot()
                service.apply(
                    snapshot,
                    foodStore: foodStore, weightStore: weightStore, bodyFatStore: bodyFatStore,
                    bodyMeasurementStore: bodyMeasurementStore, chatStore: chatStore
                )
                show(String(localized: "Restore complete"))
            } catch CloudBackupService.BackupError.noBackupFound {
                show(String(localized: "No backup found"))
            } catch CloudBackupService.BackupError.accountUnavailable {
                show(String(localized: "iCloud unavailable — check that you're signed in to iCloud."))
            } catch {
                show(String(localized: "Restore failed"))
            }
        }
    }

    private func show(_ message: String) {
        statusMessage = message
        showStatusAlert = true
    }
}
