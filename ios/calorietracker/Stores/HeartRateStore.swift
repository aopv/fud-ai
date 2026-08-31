import Foundation
import SwiftUI

@Observable
final class HeartRateStore {
    static let defaultStorageKey = "heartRateEntries.v1"
    static let validBPMRange = 30...250

    private(set) var entries: [HeartRateEntry] = []

    private let defaults: UserDefaults
    private let storageKey: String
    private var storageIsWritable = true

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = HeartRateStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    var latestEntry: HeartRateEntry? {
        entries.max { $0.date < $1.date }
    }

    func entries(in range: ClosedRange<Date>) -> [HeartRateEntry] {
        entries
            .filter { range.contains($0.date) }
            .sorted { $0.date < $1.date }
    }

    @discardableResult
    func add(_ entry: HeartRateEntry) -> Bool {
        guard storageIsWritable,
              isValid(entry),
              !entries.contains(where: { $0.id == entry.id }) else { return false }
        var updatedEntries = entries
        updatedEntries.append(entry)
        guard persist(updatedEntries) else { return false }
        entries = updatedEntries
        return true
    }

    @discardableResult
    func update(_ entry: HeartRateEntry) -> Bool {
        guard storageIsWritable,
              isValid(entry),
              let index = entries.firstIndex(where: { $0.id == entry.id }) else { return false }
        var updatedEntries = entries
        updatedEntries[index] = entry
        guard persist(updatedEntries) else { return false }
        entries = updatedEntries
        return true
    }

    @discardableResult
    func delete(_ entry: HeartRateEntry) -> Bool {
        guard storageIsWritable,
              entries.contains(where: { $0.id == entry.id }) else { return false }
        let updatedEntries = entries.filter { $0.id != entry.id }
        guard persist(updatedEntries) else { return false }
        entries = updatedEntries
        return true
    }

    func clear() {
        entries = []
        defaults.removeObject(forKey: storageKey)
        storageIsWritable = true
    }

    private func load() {
        guard let storedValue = defaults.object(forKey: storageKey) else { return }
        guard let data = storedValue as? Data,
              let decoded = try? JSONDecoder().decode([HeartRateEntry].self, from: data),
              decoded.allSatisfy(isValid),
              Set(decoded.map(\.id)).count == decoded.count
        else {
            // Preserve unknown or corrupted bytes for recovery instead of silently
            // replacing them with a newly added reading.
            storageIsWritable = false
            return
        }
        entries = decoded
    }

    private func persist(_ entries: [HeartRateEntry]) -> Bool {
        guard storageIsWritable,
              let data = try? JSONEncoder().encode(entries) else { return false }
        defaults.set(data, forKey: storageKey)
        return true
    }

    private func isValid(_ entry: HeartRateEntry) -> Bool {
        entry.date.timeIntervalSinceReferenceDate.isFinite
            && Self.validBPMRange.contains(entry.bpm)
            && (entry.quality.map { $0.isFinite && (0...1).contains($0) } ?? true)
    }
}
