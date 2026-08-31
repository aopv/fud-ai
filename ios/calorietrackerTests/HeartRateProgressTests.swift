import Foundation
import Testing
@testable import calorietracker

@MainActor
struct HeartRateProgressTests {
    @Test func heartRateChartAxisAdaptsToReadingSpan() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 31,
            hour: 9
        ))!

        #expect(HeartRateChartAxisStyle.resolve(dates: [], calendar: calendar) == .date)
        #expect(HeartRateChartAxisStyle.resolve(dates: [start], calendar: calendar) == .time)
        #expect(HeartRateChartAxisStyle.resolve(
            dates: [start, start.addingTimeInterval(90)],
            calendar: calendar
        ) == .timeWithSeconds)
        #expect(HeartRateChartAxisStyle.resolve(
            dates: [start, start.addingTimeInterval(2 * 60 * 60)],
            calendar: calendar
        ) == .time)
        #expect(HeartRateChartAxisStyle.resolve(
            dates: [start, start.addingTimeInterval(24 * 60 * 60)],
            calendar: calendar
        ) == .date)
    }

    @Test func progressMetricsKeepApprovedOrderAndVisibility() {
        #expect(
            ProgressMetric.available(bodyFatAvailable: false, workoutBurnAvailable: false)
                == [.weight, .heartRate]
        )
        #expect(
            ProgressMetric.available(bodyFatAvailable: true, workoutBurnAvailable: false)
                == [.weight, .bodyFat, .heartRate]
        )
        #expect(
            ProgressMetric.available(bodyFatAvailable: false, workoutBurnAvailable: true)
                == [.weight, .workouts, .heartRate]
        )
        #expect(
            ProgressMetric.available(bodyFatAvailable: true, workoutBurnAvailable: true)
                == [.weight, .bodyFat, .workouts, .heartRate]
        )
    }

    @Test func heartRateStorePersistsFiltersAndDeletesWithoutTouchingOtherDefaults() throws {
        let suite = "HeartRateStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("preserve", forKey: "unrelated")

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let camera = HeartRateEntry(date: start, bpm: 72, source: .camera, quality: 0.91)
        let manual = HeartRateEntry(date: start.addingTimeInterval(86_400), bpm: 84, source: .manual)
        let store = HeartRateStore(defaults: defaults)

        #expect(store.add(camera))
        #expect(store.add(manual))
        #expect(!store.add(camera))
        #expect(!store.add(HeartRateEntry(bpm: 280, source: .manual)))
        #expect(store.latestEntry == manual)

        let persistedBeforeInvalidAdd = defaults.data(forKey: HeartRateStore.defaultStorageKey)
        let invalidDateEntry = HeartRateEntry(
            date: Date(timeIntervalSinceReferenceDate: .infinity),
            bpm: 72,
            source: .manual
        )
        #expect(!store.add(invalidDateEntry))
        #expect(store.entries == [camera, manual])
        #expect(defaults.data(forKey: HeartRateStore.defaultStorageKey) == persistedBeforeInvalidAdd)

        let correctedManual = HeartRateEntry(
            id: manual.id,
            date: manual.date,
            bpm: 82,
            source: .manual
        )
        #expect(store.update(correctedManual))
        #expect(!store.update(HeartRateEntry(bpm: 70, source: .manual)))

        let restored = HeartRateStore(defaults: defaults)
        #expect(restored.entries == [camera, correctedManual])
        #expect(restored.entries(in: start...start).map(\.id) == [camera.id])

        restored.delete(camera)
        #expect(HeartRateStore(defaults: defaults).entries == [correctedManual])
        restored.clear()
        #expect(HeartRateStore(defaults: defaults).entries.isEmpty)
        #expect(defaults.string(forKey: "unrelated") == "preserve")
    }

    @Test func heartRateStoreDoesNotOverwriteUndecodableExistingData() throws {
        let suite = "HeartRateStoreCorruptionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let corrupted = Data([0xFF, 0x00, 0xCA, 0xFE])
        defaults.set(corrupted, forKey: HeartRateStore.defaultStorageKey)

        let store = HeartRateStore(defaults: defaults)
        #expect(store.entries.isEmpty)
        #expect(!store.add(HeartRateEntry(bpm: 72, source: .manual)))
        #expect(!store.delete(HeartRateEntry(bpm: 72, source: .manual)))
        #expect(defaults.data(forKey: HeartRateStore.defaultStorageKey) == corrupted)

        // Explicit Delete All Data remains the safe recovery route.
        store.clear()
        #expect(store.add(HeartRateEntry(bpm: 72, source: .manual)))
        #expect(defaults.data(forKey: HeartRateStore.defaultStorageKey) != corrupted)
    }

    @Test func heartRateStoreRejectsDuplicatePersistedIdentifiersWithoutOverwriting() throws {
        let suite = "HeartRateStoreDuplicateTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let id = UUID()
        let first = HeartRateEntry(id: id, bpm: 64, source: .manual)
        let duplicate = HeartRateEntry(id: id, bpm: 82, source: .camera, quality: 0.8)
        let encoded = try JSONEncoder().encode([first, duplicate])
        defaults.set(encoded, forKey: HeartRateStore.defaultStorageKey)

        let store = HeartRateStore(defaults: defaults)
        #expect(store.entries.isEmpty)
        #expect(!store.add(HeartRateEntry(bpm: 72, source: .manual)))
        #expect(defaults.data(forKey: HeartRateStore.defaultStorageKey) == encoded)
    }

    @Test func workoutBurnAggregationUsesOnePreferredCalculatedReadingPerDay() throws {
        let calendar = Calendar.current
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 20)))
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let end = try #require(calendar.date(byAdding: .day, value: 2, to: day))

        let old = burnSession(date: day, calories: 300, version: 1, completedOffset: 1)
        let preferred = burnSession(date: day, calories: 340, version: 2, completedOffset: 2)
        let second = burnSession(date: nextDay, calories: 410, version: 1, completedOffset: 1)
        let invalidZero = burnSession(date: nextDay, calories: 0, version: 3, completedOffset: 3)
        let invalidHigh = burnSession(date: nextDay, calories: 5_001, version: 4, completedOffset: 4)
        let unmeasured = StrengthWorkoutSession(
            diaryDate: nextDay,
            diaryDateKey: StrengthWorkoutDate.key(for: nextDay, calendar: calendar),
            startedAt: nextDay,
            completedAt: nextDay.addingTimeInterval(300),
            durationSeconds: 300,
            exercises: [],
            caloriesBurned: nil
        )

        let days = WorkoutBurnAggregation.daily(
            sessions: [old, unmeasured, invalidZero, invalidHigh, second, preferred],
            in: day...end,
            calendar: calendar
        )

        #expect(days.map(\.calories) == [340, 410])
        #expect(days.reduce(0) { $0 + $1.calories } == 750)
        #expect(!WorkoutBurnAggregation.isReliable(0))
        #expect(WorkoutBurnAggregation.isReliable(5_000))
        #expect(!WorkoutBurnAggregation.isReliable(5_001))
    }

    private func burnSession(
        date: Date,
        calories: Int,
        version: Int,
        completedOffset: TimeInterval
    ) -> StrengthWorkoutSession {
        StrengthWorkoutSession(
            diaryDate: date,
            diaryDateKey: StrengthWorkoutDate.key(for: date),
            startedAt: date,
            completedAt: date.addingTimeInterval(completedOffset),
            durationSeconds: 0,
            exercises: [],
            caloriesBurned: calories,
            healthSyncVersion: version
        )
    }
}
