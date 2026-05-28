import Foundation
import SwiftUI

@MainActor
@Observable
class WeightStore {
    private(set) var entries: [WeightEntry] = []
    var onEntryAdded: ((WeightEntry) -> Void)?
    var onEntryDeleted: ((UUID) -> Void)?

    private let storageKey = "weightEntries"

    init() {
        loadEntries()
        observeExternalChanges()
        // No default seed — WeightStore.init runs before onboarding finishes on a fresh
        // install, so `UserProfile.load()` is nil and the old seed fell back to .default
        // (70 kg), dropping a phantom 70 kg entry onto every new user's chart even if
        // their real weight was different. Onboarding now seeds the first WeightEntry
        // via `seedInitialWeightFromProfileIfEmpty(_:)` once the profile is real.
    }

    /// Add the first WeightEntry from the user's onboarding-set profile weight.
    /// Safe to call multiple times — no-op if any entries already exist, so subsequent
    /// scene-active firings or re-onboarding paths can't duplicate.
    func seedInitialWeightFromProfileIfEmpty(_ weightKg: Double) {
        guard entries.isEmpty else { return }
        addEntry(WeightEntry(date: .now, weightKg: weightKg))
    }

    var latestEntry: WeightEntry? {
        entries.max(by: { $0.date < $1.date })
    }

    func entries(in range: ClosedRange<Date>) -> [WeightEntry] {
        entries
            .filter { range.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    func addEntry(_ entry: WeightEntry) {
        let previousLatest = entries.max(by: { $0.date < $1.date })
        entries.append(entry)
        saveEntries()
        onEntryAdded?(entry)

        syncProfileWeightToLatest()

        // Detect goal-weight crossing — fire only on the transition, not on every weight past goal.
        if let profile = UserProfile.load(), let goalKg = profile.goalWeightKg, let previous = previousLatest {
            let crossed: Bool
            switch profile.goal {
            case .lose:    crossed = previous.weightKg > goalKg && entry.weightKg <= goalKg
            case .gain:    crossed = previous.weightKg < goalKg && entry.weightKg >= goalKg
            case .maintain: crossed = false
            }
            if crossed {
                NotificationCenter.default.post(name: .weightGoalReached, object: nil)
            }
        }
    }

    func deleteEntry(_ entry: WeightEntry) {
        let id = entry.id
        entries.removeAll { $0.id == id }
        saveEntries()
        onEntryDeleted?(id)
        syncProfileWeightToLatest()
    }

    /// Keep UserProfile.weightKg aligned with the most recent weight entry so Settings (Weight row)
    /// and Progress (Current badge) never disagree. If the store is empty, leave the profile as-is
    /// — we still need some weightKg for BMR/TDEE math; user can log a new one.
    private func syncProfileWeightToLatest() {
        guard var profile = UserProfile.load(),
              let newest = entries.max(by: { $0.date < $1.date }) else { return }
        if abs(profile.weightKg - newest.weightKg) > 0.01 {
            profile.weightKg = newest.weightKg
            profile.save()
        }
    }

    func replaceAllEntries(_ newEntries: [WeightEntry]) {
        entries = newEntries
        saveEntries()
    }

    /// Bulk-import weight samples discovered from HealthKit (e.g. years of
    /// scale history that predate Fud AI). Bypasses onEntryAdded so the
    /// imported externals don't echo back to HK as fresh writes — these
    /// samples already exist there. Saves + syncs profile once at the end.
    func importExternalEntries(_ external: [WeightEntry]) {
        guard !external.isEmpty else { return }
        entries.append(contentsOf: external)
        saveEntries()
        syncProfileWeightToLatest()
    }

    func mergeWithCloudEntries(_ cloudEntries: [WeightEntry]) {
        var merged = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        for cloudEntry in cloudEntries where merged[cloudEntry.id] == nil {
            merged[cloudEntry.id] = cloudEntry
        }
        entries = Array(merged.values)
        saveEntries()
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WeightEntry].self, from: data)
        else { return }
        entries = decoded
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(WeightEntryStorage.didChangeNotification as CFString),
            nil
        )
    }

    /// Listen for weight writes made by App Intents (Siri / Shortcuts) in
    /// another process and reload from disk so we don't overwrite them.
    private func observeExternalChanges() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let raw = UInt(bitPattern: observer)
                Task { @MainActor in
                    guard let ptr = UnsafeRawPointer(bitPattern: raw) else { return }
                    Unmanaged<WeightStore>.fromOpaque(ptr).takeUnretainedValue()
                        .reloadFromExternalChange()
                }
            },
            WeightEntryStorage.didChangeNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func reloadFromExternalChange() {
        loadEntries()
        syncProfileWeightToLatest()
    }
}
