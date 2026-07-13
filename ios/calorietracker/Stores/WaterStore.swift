import Foundation

enum WaterSettings {
    static let enabledKey = "waterTrackingEnabled"
    static let dailyGoalKey = "waterDailyGoalMl"
    static let reminderEnabledKey = "waterReminderEnabled"
    static let reminderHourKey = "waterReminderHour"
    static let reminderMinuteKey = "waterReminderMinute"
    static let entriesKey = "waterEntries"

    static let defaultDailyGoalMl = 2_000
    static let dailyGoalOptions = [1_500, 2_000, 2_500, 3_000, 3_500, 4_000]
}

struct WaterEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let milliliters: Int

    init(id: UUID = UUID(), date: Date = .now, milliliters: Int) {
        self.id = id
        self.date = date
        self.milliliters = milliliters
    }
}

@Observable
final class WaterStore {
    private(set) var entries: [WaterEntry] = []

    init() {
        guard let data = UserDefaults.standard.data(forKey: WaterSettings.entriesKey),
              let decoded = try? JSONDecoder().decode([WaterEntry].self, from: data) else { return }
        entries = decoded
    }

    @discardableResult
    func add(milliliters: Int, on date: Date) -> WaterEntry? {
        guard milliliters > 0 else { return nil }
        let entry = WaterEntry(date: date, milliliters: milliliters)
        entries.append(entry)
        save()
        return entry
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func clear() {
        entries = []
        UserDefaults.standard.removeObject(forKey: WaterSettings.entriesKey)
    }

    func total(on date: Date) -> Int {
        entries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.milliliters }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: WaterSettings.entriesKey)
    }
}
