import Foundation

enum WatchWaterLogResult: String, Equatable {
    case added
    case duplicate
    case disabled
    case invalid
    case queued
}

struct WatchWaterLogRequest: Equatable {
    static let actionKey = "watch_action"
    static let actionValue = "log_water"
    static let requestIDKey = "watch_water_request_id"
    static let millilitersKey = "watch_water_milliliters"
    static let dateKey = "watch_water_date"
    static let resultKey = "watch_water_result"
    static let allowedAmounts = Set([250, 500, 750])

    let id: UUID
    let milliliters: Int
    let date: Date

    init(id: UUID, milliliters: Int, date: Date) {
        self.id = id
        self.milliliters = milliliters
        self.date = date
    }

    init?(payload: [String: Any]) {
        guard payload[Self.actionKey] as? String == Self.actionValue,
              let idString = payload[Self.requestIDKey] as? String,
              let id = UUID(uuidString: idString)
        else { return nil }

        let milliliters: Int?
        if let value = payload[Self.millilitersKey] as? Int {
            milliliters = value
        } else if let value = payload[Self.millilitersKey] as? NSNumber {
            milliliters = value.intValue
        } else {
            milliliters = nil
        }

        guard let milliliters, Self.allowedAmounts.contains(milliliters) else { return nil }

        self.init(
            id: id,
            milliliters: milliliters,
            date: payload[Self.dateKey] as? Date ?? .now
        )
    }
}
