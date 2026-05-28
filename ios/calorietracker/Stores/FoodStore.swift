import Foundation
import SwiftUI

enum FoodLogSortOrder: String, CaseIterable, Identifiable {
    case standard
    case latestMealsFirst

    static let storageKey = "foodLogSortOrder"
    static let defaultOrder: FoodLogSortOrder = .standard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: "Breakfast → Lunch → Dinner"
        case .latestMealsFirst: "Latest Meals First"
        }
    }

    static func order(for rawValue: String) -> FoodLogSortOrder {
        FoodLogSortOrder(rawValue: rawValue) ?? defaultOrder
    }
}

struct FoodLogMealGroup: Identifiable {
    let id: String
    let meal: MealType
    let entries: [FoodEntry]
}

@MainActor
@Observable
class FoodStore {
    private(set) var entries: [FoodEntry] = []
    var onEntriesChanged: (() -> Void)?
    var onEntryAdded: ((FoodEntry) -> Void)?
    var onEntryDeleted: ((UUID) -> Void)?
    var onEntryUpdated: ((FoodEntry) -> Void)?

    private let storageKey = "foodEntries"
    private let favoritesKey = "favoriteFoodEntries"
    private(set) var favorites: [FoodEntry] = []

    init() {
        loadEntries()
        loadFavorites()
        observeExternalChanges()
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            CFNotificationName(FoodEntryStorage.didChangeNotification as CFString),
            nil
        )
    }

    /// Listen for writes made by App Intents (Siri / Shortcuts) in another
    /// process. On notification we reload from disk so our in-memory array
    /// includes the externally-added entry and won't overwrite it on next save.
    private func observeExternalChanges() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                // Cross the actor boundary with a Sendable bit-pattern, then
                // reconstruct the store on the main actor (strict concurrency).
                let raw = UInt(bitPattern: observer)
                Task { @MainActor in
                    guard let ptr = UnsafeRawPointer(bitPattern: raw) else { return }
                    Unmanaged<FoodStore>.fromOpaque(ptr).takeUnretainedValue()
                        .reloadFromExternalChange()
                }
            },
            FoodEntryStorage.didChangeNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Re-read from disk after an external (Siri/Shortcut) write and fan out the
    /// same side effects a normal add would (widget refresh, notifications).
    /// The intent path already indexed Spotlight, so we don't re-index here.
    private func reloadFromExternalChange() {
        loadEntries()
        onEntriesChanged?()
    }

    var todayEntries: [FoodEntry] {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var todayEntriesByMeal: [FoodLogMealGroup] {
        let calendar = Calendar.current
        let today = entries
            .filter { calendar.isDateInToday($0.timestamp) }
            .sorted { $0.timestamp > $1.timestamp }

        return groupedEntries(today, order: .standard)
    }

    var todayCalories: Int {
        todayEntries.reduce(0) { $0 + $1.calories }
    }

    var todayProtein: Double {
        todayEntries.reduce(0) { $0 + $1.protein }
    }

    var todayCarbs: Double {
        todayEntries.reduce(0) { $0 + $1.carbs }
    }

    var todayFat: Double {
        todayEntries.reduce(0) { $0 + $1.fat }
    }

    // MARK: - Date-parameterized queries

    func entries(for date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return entries
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func entriesByMeal(for date: Date, order: FoodLogSortOrder = .standard) -> [FoodLogMealGroup] {
        let dayEntries = entries(for: date)
        return groupedEntries(dayEntries, order: order)
    }

    private func groupedEntries(_ dayEntries: [FoodEntry], order: FoodLogSortOrder) -> [FoodLogMealGroup] {
        switch order {
        case .standard:
            return MealType.allCases.compactMap { meal in
                let mealEntries = dayEntries.filter { $0.mealType == meal }
                guard !mealEntries.isEmpty else { return nil }
                return FoodLogMealGroup(id: "standard-\(meal.rawValue)", meal: meal, entries: mealEntries)
            }
        case .latestMealsFirst:
            return latestMealRuns(dayEntries)
        }
    }

    private func latestMealRuns(_ dayEntries: [FoodEntry]) -> [FoodLogMealGroup] {
        var groups: [FoodLogMealGroup] = []
        var currentMeal: MealType?
        var currentEntries: [FoodEntry] = []

        func appendCurrentGroup() {
            guard let meal = currentMeal, !currentEntries.isEmpty else { return }
            let firstEntryID = currentEntries.first?.id.uuidString ?? UUID().uuidString
            groups.append(FoodLogMealGroup(
                id: "latest-\(groups.count)-\(meal.rawValue)-\(firstEntryID)",
                meal: meal,
                entries: currentEntries
            ))
        }

        for entry in dayEntries {
            if entry.mealType == currentMeal {
                currentEntries.append(entry)
            } else {
                appendCurrentGroup()
                currentMeal = entry.mealType
                currentEntries = [entry]
            }
        }

        appendCurrentGroup()
        return groups
    }

    func calories(for date: Date) -> Int {
        entries(for: date).reduce(0) { $0 + $1.calories }
    }

    func protein(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + $1.protein }
    }

    func carbs(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + $1.carbs }
    }

    func fat(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + $1.fat }
    }

    // MARK: - Micronutrient aggregation

    func sugar(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.sugar ?? 0) }
    }

    func addedSugar(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.addedSugar ?? 0) }
    }

    func fiber(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.fiber ?? 0) }
    }

    func saturatedFat(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.saturatedFat ?? 0) }
    }

    func monounsaturatedFat(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.monounsaturatedFat ?? 0) }
    }

    func polyunsaturatedFat(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.polyunsaturatedFat ?? 0) }
    }

    func cholesterol(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.cholesterol ?? 0) }
    }

    func sodium(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.sodium ?? 0) }
    }

    func potassium(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.potassium ?? 0) }
    }

    func transFat(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.transFat ?? 0) }
    }

    func calcium(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.calcium ?? 0) }
    }

    func iron(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.iron ?? 0) }
    }

    func magnesium(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.magnesium ?? 0) }
    }

    func zinc(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.zinc ?? 0) }
    }

    func vitaminA(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminA ?? 0) }
    }

    func vitaminC(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminC ?? 0) }
    }

    func vitaminD(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminD ?? 0) }
    }

    func vitaminB12(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminB12 ?? 0) }
    }

    func vitaminE(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminE ?? 0) }
    }

    func vitaminK(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.vitaminK ?? 0) }
    }

    func folate(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.folate ?? 0) }
    }

    func omega3(for date: Date) -> Double {
        entries(for: date).reduce(0) { $0 + ($1.omega3 ?? 0) }
    }

    // MARK: - Recents / Frequent

    func recentEntries(limit: Int = 50) -> [FoodEntry] {
        Array(entries.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func frequentGroups() -> [FrequentFoodGroup] {
        var aggregates: [String: (count: Int, template: FoodEntry)] = [:]
        for entry in entries {
            let key = "\(entry.name.lowercased())|\(entry.calories)"
            if let current = aggregates[key] {
                let newCount = current.count + 1
                let template = entry.timestamp > current.template.timestamp ? entry : current.template
                aggregates[key] = (newCount, template)
            } else {
                aggregates[key] = (1, entry)
            }
        }
        return aggregates.map { _, pair in
            FrequentFoodGroup(template: pair.template, count: pair.count)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    // MARK: - Favorites

    func isFavorite(_ entry: FoodEntry) -> Bool {
        favorites.contains { $0.favoriteKey == entry.favoriteKey }
    }

    func toggleFavorite(_ entry: FoodEntry) {
        if let index = favorites.firstIndex(where: { $0.favoriteKey == entry.favoriteKey }) {
            favorites.remove(at: index)
        } else {
            // Remove any existing entry with same id to prevent duplicates
            favorites.removeAll { $0.id == entry.id }
            // Make sure the favorite has its own on-disk JPEG before persisting.
            // Without this, favoriting an entry that hasn't been through
            // addEntry() yet (e.g. straight from the Food Result review screen)
            // would persist with imageData = bytes-in-memory-only — and since
            // FoodEntry.encode drops raw bytes by design, the favorite would
            // come back image-less on the next launch.
            var favorite = entry
            offloadImageToDiskIfNeeded(&favorite)
            favorites.append(favorite)
        }
        saveFavorites()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return }
        favorites = decoded
    }

    // MARK: - CRUD

    func addEntry(_ entry: FoodEntry) {
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)
        entries.append(entry)
        saveEntries()
        SpotlightIndexer.index(entry)
        onEntriesChanged?()
        onEntryAdded?(entry)
    }

    func updateEntry(_ entry: FoodEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        var entry = entry
        offloadImageToDiskIfNeeded(&entry)
        entries[index] = entry
        saveEntries()
        SpotlightIndexer.index(entry)
        onEntriesChanged?()
        // Single callback so HealthKit can serialize delete-then-write atomically.
        onEntryUpdated?(entry)
    }

    func deleteEntry(_ entry: FoodEntry) {
        let id = entry.id
        // Skip the disk-delete when a favorite (or another entry) still
        // references this filename. Without this guard, favoriting a meal,
        // deleting the log entry, and relaunching wipes the favorite's image
        // because both rows share the same fudai-image-<uuid>.jpg.
        if let filename = entry.imageFilename, !isImageStillReferenced(filename: filename, excludingEntryID: id) {
            FoodImageStore.shared.delete(filename: filename)
        }
        entries.removeAll { $0.id == id }
        saveEntries()
        SpotlightIndexer.remove(id: id)
        onEntriesChanged?()
        onEntryDeleted?(id)
    }

    func replaceAllEntries(_ newEntries: [FoodEntry]) {
        // Delete on-disk JPEGs for any entry that's about to be removed —
        // otherwise Clear Food Log / Delete All Data orphan files in
        // Application Support forever. Skip files that a favorite or a
        // surviving entry still references (same filename, different id).
        let surviving = Set(newEntries.map(\.id))
        let survivingFilenames = Set(newEntries.compactMap(\.imageFilename))
        let favoriteFilenames = Set(favorites.compactMap(\.imageFilename))
        for old in entries where !surviving.contains(old.id) {
            guard let filename = old.imageFilename else { continue }
            if survivingFilenames.contains(filename) || favoriteFilenames.contains(filename) { continue }
            FoodImageStore.shared.delete(filename: filename)
        }
        entries = newEntries.map { var e = $0; offloadImageToDiskIfNeeded(&e); return e }
        saveEntries()
        SpotlightIndexer.reindexAll(entries)
        onEntriesChanged?()
    }

    func mergeWithCloudEntries(_ cloudEntries: [FoodEntry]) {
        var merged = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        // Only add cloud entries that don't exist locally — preserves any local edits
        // made while offline. A proper last-write-wins merge requires a modifiedAt field.
        for cloudEntry in cloudEntries where merged[cloudEntry.id] == nil {
            merged[cloudEntry.id] = cloudEntry
        }
        entries = Array(merged.values)
        saveEntries()
        onEntriesChanged?()
    }

    /// If `entry` carries in-memory `imageData` but no `imageFilename`, write
    /// the bytes to disk and stamp the filename onto the entry. No-op when
    /// there are no bytes, or when a filename is already set (idempotent).
    /// The 4 MiB UserDefaults cap demands we never persist raw bytes.
    private func offloadImageToDiskIfNeeded(_ entry: inout FoodEntry) {
        guard entry.imageFilename == nil, let data = entry.imageData else { return }
        if let filename = FoodImageStore.shared.store(data: data, for: entry.id) {
            entry.imageFilename = filename
        }
    }

    /// Used by deleteEntry / replaceAllEntries to decide whether the on-disk
    /// JPEG can safely be removed. A filename can be shared by a logged entry
    /// + a favorite (same `id`, same generated `fudai-image-<uuid>.jpg`), or
    /// by two logged entries that came from the same favorite re-log.
    private func isImageStillReferenced(filename: String, excludingEntryID: UUID) -> Bool {
        if entries.contains(where: { $0.id != excludingEntryID && $0.imageFilename == filename }) {
            return true
        }
        return favorites.contains { $0.imageFilename == filename }
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([FoodEntry].self, from: data)
        else { return }
        entries = decoded

        // Legacy migration: rows written by pre-FoodImageStore builds embedded
        // JPEG bytes in the JSON blob. Offload any such rows to disk, stamp
        // the filename, and rewrite the UserDefaults blob — shrinking it from
        // multi-MB to ~a few KB so the 4 MiB cap stops silently swallowing
        // adds/deletes. Idempotent: runs only on entries that need it.
        var migrated = false
        for i in entries.indices {
            if entries[i].imageFilename == nil, let data = entries[i].imageData {
                if let filename = FoodImageStore.shared.store(data: data, for: entries[i].id) {
                    entries[i].imageFilename = filename
                    migrated = true
                }
            }
        }
        if migrated {
            saveEntries()
        }
    }
}

struct FrequentFoodGroup: Identifiable {
    let id: String
    let name: String
    let calories: Int
    let count: Int
    let template: FoodEntry

    init(template: FoodEntry, count: Int) {
        self.id = "\(template.name.lowercased())|\(template.calories)"
        self.name = template.name
        self.calories = template.calories
        self.count = count
        self.template = template
    }
}
