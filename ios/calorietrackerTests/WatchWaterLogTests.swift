import Foundation
import Testing
@testable import calorietracker

@MainActor
struct WatchWaterLogTests {
    @Test func requestParsesOnlySupportedPresetAmounts() throws {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1_786_000_000)
        let valid: [String: Any] = [
            WatchWaterLogRequest.actionKey: WatchWaterLogRequest.actionValue,
            WatchWaterLogRequest.requestIDKey: id.uuidString,
            WatchWaterLogRequest.millilitersKey: 500,
            WatchWaterLogRequest.dateKey: date,
        ]

        let request = try #require(WatchWaterLogRequest(payload: valid))
        #expect(request == WatchWaterLogRequest(id: id, milliliters: 500, date: date))

        var unsupported = valid
        unsupported[WatchWaterLogRequest.millilitersKey] = 333
        #expect(WatchWaterLogRequest(payload: unsupported) == nil)

        var unrelated = valid
        unrelated[WatchWaterLogRequest.actionKey] = "unknown"
        #expect(WatchWaterLogRequest(payload: unrelated) == nil)
    }

    @Test func watchRequestIDDeduplicatesPersistedWaterEntries() throws {
        let suiteName = "WatchWaterLogTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let requestID = UUID()
        let date = Date(timeIntervalSince1970: 1_786_000_000)
        let store = WaterStore(defaults: defaults)

        #expect(store.add(id: requestID, milliliters: 250, on: date) != nil)
        #expect(store.add(id: requestID, milliliters: 250, on: date) != nil)
        #expect(store.entries.count == 1)
        #expect(store.total(on: date) == 250)

        let reloaded = WaterStore(defaults: defaults)
        #expect(reloaded.entries.count == 1)
        #expect(reloaded.entries.first?.id == requestID)
    }
}
