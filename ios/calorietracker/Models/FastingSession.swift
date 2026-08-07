import Foundation

enum FastingSettings {
    static let enabledKey = "fastingTrackingEnabled"
    static let defaultGoalMinutesKey = "fastingDefaultGoalMinutes"
    static let notificationEnabledKey = "fastingGoalNotificationEnabled"
    static let sessionsKey = "fastingSessions"

    static let defaultGoalMinutes = 16 * 60
    static let minimumGoalMinutes = 60
    static let maximumGoalMinutes = 7 * 24 * 60
    static let commonGoalHours = [12, 14, 16, 18, 20, 24]
}

struct FastingSession: Codable, Identifiable, Equatable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?
    var goalMinutes: Int

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        goalMinutes: Int = FastingSettings.defaultGoalMinutes
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.goalMinutes = min(
            max(goalMinutes, FastingSettings.minimumGoalMinutes),
            FastingSettings.maximumGoalMinutes
        )
    }

    var isActive: Bool { endedAt == nil }
    var goalDate: Date { startedAt.addingTimeInterval(TimeInterval(goalMinutes * 60)) }

    func duration(at now: Date = .now) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let endedAt else { return false }
        return calendar.isDate(endedAt, inSameDayAs: day)
    }
}

enum FastingDurationFormatter {
    static func compact(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    static func goal(minutes: Int) -> String {
        compact(seconds: TimeInterval(minutes * 60))
    }
}
