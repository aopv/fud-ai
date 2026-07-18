import Foundation
import Testing
@testable import calorietracker

@MainActor
struct StrengthWorkoutStoreTests {
    @Test func modelsRoundTripThroughJSON() throws {
        let session = StrengthWorkoutSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            date: Date(timeIntervalSince1970: 1_000),
            name: "Push",
            exercises: [
                StrengthWorkoutExercise(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                    exerciseID: "bench-press",
                    exerciseName: "Bench Press",
                    sets: [
                        StrengthWorkoutSet(
                            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                            reps: 8,
                            weightKg: 60
                        )
                    ]
                )
            ]
        )

        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(StrengthWorkoutSession.self, from: data)

        #expect(decoded == session)
        #expect(decoded.setCount == 1)
        #expect(decoded.exercises[0].sets[0].isBodyweight == false)
    }

    @Test func crudPersistsAcrossStoreInstances() {
        withIsolatedDefaults { defaults, key in
            let first = makeSession(idSuffix: 1, time: 100, reps: 8, weight: 60)
            var updated = first
            updated.name = "Updated Push"
            let second = makeSession(idSuffix: 2, time: 200, reps: 6, weight: 70)

            let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            #expect(store.sessions.isEmpty)
            #expect(store.addSession(first))
            #expect(!store.addSession(first))
            #expect(store.addSession(second))
            #expect(store.sortedSessions.map(\.id) == [second.id, first.id])
            #expect(store.updateSession(updated))
            #expect(store.session(id: first.id)?.name == "Updated Push")
            #expect(!store.updateSession(makeSession(idSuffix: 99, time: 300, reps: 1)))

            let reloaded = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            #expect(reloaded.sessions.count == 2)
            #expect(reloaded.session(id: first.id)?.name == "Updated Push")
            #expect(reloaded.deleteSession(id: second.id))
            #expect(!reloaded.deleteSession(id: second.id))

            let afterDelete = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            #expect(afterDelete.sessions.map(\.id) == [first.id])
        }
    }

    @Test func replaceAllSessionsPersistsReplacement() {
        withIsolatedDefaults { defaults, key in
            let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            let replacement = makeSession(idSuffix: 3, time: 300, reps: 10)

            store.replaceAllSessions([replacement])

            let reloaded = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            #expect(reloaded.sessions == [replacement])
        }
    }

    @Test func exerciseHistoryAndPreviousSetsAreNewestFirst() {
        withIsolatedDefaults { defaults, key in
            let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            let oldest = makeSession(idSuffix: 1, time: 100, reps: 6, weight: nil)
            let middle = makeSession(idSuffix: 2, time: 200, reps: 8, weight: nil)
            let newest = StrengthWorkoutSession(
                id: stableUUID(3),
                date: Date(timeIntervalSince1970: 300),
                exercises: [
                    StrengthWorkoutExercise(
                        exerciseID: "squat",
                        exerciseName: "Squat",
                        sets: [StrengthWorkoutSet(reps: 5, weightKg: 100)]
                    )
                ]
            )
            store.replaceAllSessions([middle, newest, oldest])

            let history = store.exerciseHistory(for: "bench-press")
            #expect(history.map(\.sessionID) == [middle.id, oldest.id])
            #expect(store.previousSets(for: "bench-press").map(\.reps) == [8])
            #expect(
                store.previousSets(
                    for: "bench-press",
                    before: middle.date,
                    excludingSessionID: middle.id
                ).map(\.reps) == [6]
            )
            #expect(store.exerciseHistory(for: "missing").isEmpty)
        }
    }

    @Test func personalRecordComparisonUsesAllPriorSessions() throws {
        let suiteName = "StrengthWorkoutStoreTests.pr.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let key = "sessions"
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        store.replaceAllSessions([
            makeSession(idSuffix: 1, time: 100, reps: 8, weight: 60),
            makeSession(idSuffix: 2, time: 200, reps: 6, weight: 70),
            makeSession(idSuffix: 4, time: 400, reps: 20, weight: 100)
        ])
        let current = StrengthWorkoutSession(
            id: stableUUID(3),
            date: Date(timeIntervalSince1970: 300),
            exercises: [
                StrengthWorkoutExercise(
                    exerciseID: "bench-press",
                    exerciseName: "Bench Press",
                    sets: [
                        StrengthWorkoutSet(reps: 10, weightKg: 60),
                        StrengthWorkoutSet(reps: 5, weightKg: 75)
                    ]
                )
            ]
        )

        let comparison = try #require(store.personalRecordComparison(for: "bench-press", in: current))
        #expect(comparison.current.bestReps == 10)
        #expect(comparison.previous?.bestReps == 8)
        #expect(comparison.repetitionChange == 2)
        #expect(comparison.weightChangeKg == 5)
        #expect(comparison.isRepetitionPR)
        #expect(comparison.isWeightPR)
        #expect(comparison.hasPersonalRecord)
    }

    @Test func displayRoundingDoesNotCreateWeightPR() throws {
        try withIsolatedDefaults { defaults, key in
            let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            store.replaceAllSessions([
                makeSession(idSuffix: 1, time: 100, reps: 8, weight: 60)
            ])
            let roundedImperialRoundTrip = makeSession(
                idSuffix: 2,
                time: 200,
                reps: 8,
                weight: 60.01027
            )

            let comparison = try #require(
                store.personalRecordComparison(
                    for: "bench-press",
                    in: roundedImperialRoundTrip
                )
            )
            #expect(comparison.isWeightPR == false)
            #expect(comparison.hasPersonalRecord == false)
        }
    }

    @Test func firstBodyweightLogEstablishesBaselineWithoutPR() throws {
        withIsolatedDefaults { defaults, key in
            let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
            let current = makeSession(idSuffix: 1, time: 100, reps: 8, weight: nil)

            let comparison = store.personalRecordComparison(for: "bench-press", in: current)
            #expect(comparison?.current.bestReps == 8)
            #expect(comparison?.current.bestWeightKg == nil)
            #expect(comparison?.previous == nil)
            #expect(comparison?.hasPersonalRecord == false)
            #expect(current.exercises[0].sets[0].isBodyweight)
        }
    }

    private func withIsolatedDefaults(
        _ body: (UserDefaults, String) throws -> Void
    ) rethrows {
        let suiteName = "StrengthWorkoutStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults, "sessions")
    }

    private func makeSession(
        idSuffix: Int,
        time: TimeInterval,
        reps: Int,
        weight: Double? = nil
    ) -> StrengthWorkoutSession {
        StrengthWorkoutSession(
            id: stableUUID(idSuffix),
            date: Date(timeIntervalSince1970: time),
            name: "Session \(idSuffix)",
            exercises: [
                StrengthWorkoutExercise(
                    exerciseID: "bench-press",
                    exerciseName: "Bench Press",
                    sets: [StrengthWorkoutSet(reps: reps, weightKg: weight)]
                )
            ]
        )
    }

    private func stableUUID(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))!
    }
}
