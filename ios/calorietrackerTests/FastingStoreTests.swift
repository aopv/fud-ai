import Foundation
import Testing
@testable import calorietracker

struct FastingStoreTests {
    @Test func activeFastPersistsAndCompletesWithoutTouchingFoodData() throws {
        let suite = "FastingStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FastingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let active = try #require(store.start(goalMinutes: 16 * 60, at: start))
        #expect(active.isActive)
        #expect(store.activeSession?.id == active.id)

        let restored = FastingStore(defaults: defaults)
        #expect(restored.activeSession?.id == active.id)

        let end = start.addingTimeInterval(17 * 60 * 60)
        let completed = try #require(restored.endActive(at: end))
        #expect(!completed.isActive)
        #expect(Int(completed.duration() / 3600) == 17)
        #expect(restored.activeSession == nil)
    }

    @Test func sessionsCanBeEditedDeletedAndAccidentalActiveFastCancelled() throws {
        let suite = "FastingStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FastingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        let session = try #require(store.start(goalMinutes: 14 * 60, at: start))
        var completed = try #require(store.endActive(at: start.addingTimeInterval(15 * 3600)))
        completed.goalMinutes = 16 * 60
        #expect(store.update(completed))
        #expect(store.sessions.first?.goalMinutes == 16 * 60)

        store.delete(id: session.id)
        #expect(store.sessions.isEmpty)

        #expect(store.start(goalMinutes: 12 * 60, at: start) != nil)
        store.cancelActive()
        #expect(store.sessions.isEmpty)
    }

    @Test func overlappingSessionsAreRejected() throws {
        let suite = "FastingStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FastingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_800_000_000)

        var first = try #require(store.start(goalMinutes: 16 * 60, at: start))
        first = try #require(store.endActive(at: start.addingTimeInterval(16 * 3600)))
        let touchingStart = first.endedAt ?? start
        let second = try #require(store.start(goalMinutes: 12 * 60, at: touchingStart))
        #expect(store.endActive(at: touchingStart.addingTimeInterval(12 * 3600)) != nil)

        var overlap = second
        overlap.startedAt = start.addingTimeInterval(15 * 3600)
        #expect(!store.update(overlap))
        #expect(store.sessions.first { $0.id == second.id }?.startedAt == touchingStart)
    }

    @Test func activeFastBlocksFoodUntilItEnds() throws {
        let suite = "FastingStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let fastingStore = FastingStore(defaults: defaults)
        let foodStore = FoodStore(observesExternalChanges: false, defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = FoodEntry(
            name: "Blocked meal",
            calories: 420,
            protein: 30,
            carbs: 45,
            fat: 12,
            timestamp: start,
            source: .manual,
            mealType: .lunch
        )

        #expect(fastingStore.start(goalMinutes: 16 * 60, at: start) != nil)
        #expect(!foodStore.addEntry(entry))
        #expect(foodStore.entries.isEmpty)

        #expect(fastingStore.endActive(at: start.addingTimeInterval(16 * 3600)) != nil)
        #expect(foodStore.addEntry(entry))
        #expect(foodStore.entries.map(\.id) == [entry.id])
    }
}
