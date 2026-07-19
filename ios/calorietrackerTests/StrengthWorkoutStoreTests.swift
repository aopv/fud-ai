import Foundation
import Testing
@testable import calorietracker

struct StrengthWorkoutStoreTests {
    @Test func featureSettingIsOffByDefault() {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }

        #expect(defaults.object(forKey: StrengthWorkoutSettings.enabledKey) == nil)
        #expect(defaults.bool(forKey: StrengthWorkoutSettings.enabledKey) == false)
    }

    @Test func completedAndActiveSessionsSurviveReload() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let key = uniqueStorageKey()
        let baselineStart = Date(timeIntervalSince1970: 1_700_000_000)

        var store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        store.startSession(name: " Push Day ", at: baselineStart)
        let benchID = try #require(
            store.addExercise(exerciseID: "bench-press", exerciseName: "Bench Press")
        )
        _ = store.addSet(to: benchID, reps: 8, weightKg: 80)
        let completed = try #require(
            store.completeActiveSession(at: baselineStart.addingTimeInterval(3_600))
        )

        let activeStart = baselineStart.addingTimeInterval(86_400)
        store.startSession(name: "Pull Day", at: activeStart)
        let pullUpID = try #require(
            store.addExercise(exerciseID: "pull-up", exerciseName: "Pull-Up")
        )
        _ = store.addSet(to: pullUpID, reps: 10, isBodyweight: true)

        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)

        #expect(store.completedSessions.count == 1)
        #expect(store.completedSessions.first?.id == completed.id)
        #expect(store.completedSessions.first?.name == "Push Day")
        #expect(store.completedSessions.first?.exercises.first?.sets.first?.weightKg == 80)
        #expect(store.activeSession?.startedAt == activeStart)
        #expect(store.activeSession?.exercises.first?.sets.first?.isBodyweight == true)
        #expect(store.activeSession?.exercises.first?.sets.first?.weightKg == nil)
    }

    @Test func finishDiscardAndClearHaveSeparateScopes() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: uniqueStorageKey())
        let start = Date(timeIntervalSince1970: 1_700_100_000)

        store.startSession(at: start)
        #expect(store.completeActiveSession(at: start.addingTimeInterval(60)) == nil)
        #expect(store.activeSession != nil)

        let exerciseID = try #require(
            store.addExercise(exerciseID: "row", exerciseName: "Barbell Row")
        )
        _ = store.addSet(to: exerciseID, reps: 8, weightKg: 60)
        _ = store.addSet(to: exerciseID) // unfinished UI placeholder
        let completed = try #require(
            store.completeActiveSession(at: start.addingTimeInterval(1_200))
        )

        #expect(completed.setCount == 1)
        #expect(completed.exercises.first?.sets.count == 1)
        #expect(store.activeSession == nil)
        #expect(store.completedSessions.count == 1)

        store.startSession(at: start.addingTimeInterval(86_400))
        let discarded = store.discardActiveSession()
        #expect(discarded != nil)
        #expect(store.activeSession == nil)
        #expect(store.completedSessions.count == 1)

        store.clearCompletedSessions()
        #expect(store.completedSessions.isEmpty)

        store.startSession(at: start.addingTimeInterval(172_800))
        defaults.set(Data("unmigrated-legacy".utf8), forKey: StrengthWorkoutStore.legacyStorageKey)
        store.clearAll()
        #expect(store.activeSession == nil)
        #expect(store.completedSessions.isEmpty)
        #expect(defaults.data(forKey: StrengthWorkoutStore.legacyStorageKey) == nil)
    }

    @Test func historyAndPreviousSetAutofillUseLatestCompletedWorkout() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: uniqueStorageKey())
        let firstStart = Date(timeIntervalSince1970: 1_700_200_000)

        store.startSession(name: "Upper", at: firstStart)
        let firstExerciseID = try #require(
            store.addExercise(exerciseID: "incline-press", exerciseName: "Incline Press")
        )
        let firstSetID = try #require(store.addSet(to: firstExerciseID, reps: 10, weightKg: 30))
        _ = store.addSet(to: firstExerciseID, reps: 8, weightKg: 32.5)
        let firstSession = try #require(
            store.completeActiveSession(at: firstStart.addingTimeInterval(2_000))
        )

        let secondStart = firstStart.addingTimeInterval(86_400)
        store.startSession(at: secondStart)
        let secondExerciseID = try #require(
            store.addExercise(
                exerciseID: "incline-press",
                exerciseName: "Incline Dumbbell Press",
                autofillFromHistory: true
            )
        )
        let copiedSets = try #require(
            store.activeSession?.exercises.first(where: { $0.id == secondExerciseID })?.sets
        )

        #expect(copiedSets.map(\.reps) == [10, 8])
        #expect(copiedSets.map(\.weightKg) == [30, 32.5])
        #expect(copiedSets.first?.id != firstSetID)
        #expect(copiedSets.allSatisfy { !$0.isPerformed })
        let copiedSecondSet = try #require(copiedSets.last)
        #expect(store.updateSet(
            exerciseID: secondExerciseID,
            setID: copiedSecondSet.id,
            reps: 9,
            weightKg: copiedSecondSet.weightKg,
            isBodyweight: copiedSecondSet.isBodyweight
        ))
        let editedSuggestion = store.activeSession?.exercises
            .first(where: { $0.id == secondExerciseID })?.sets
            .first(where: { $0.id == copiedSecondSet.id })
        #expect(editedSuggestion?.reps == 9)
        #expect(editedSuggestion?.isPerformed == false)
        #expect(store.activeSession?.hasRecordedSets == false)
        #expect(store.completeActiveSession(at: secondStart.addingTimeInterval(600)) == nil)

        let copiedFirstSet = try #require(copiedSets.first)
        #expect(store.setPerformed(
            exerciseID: secondExerciseID,
            setID: copiedFirstSet.id,
            isPerformed: true
        ))
        #expect(store.activeSession?.hasRecordedSets == true)

        let history = store.exerciseHistory(for: "incline-press")
        #expect(history.count == 1)
        #expect(history.first?.sessionID == firstSession.id)
        #expect(history.first?.sessionName == "Upper")
        #expect(store.previousSets(for: "incline-press", before: secondStart).count == 2)
    }

    @Test func bodyweightRepsAndExplicitWeightProduceOnlyTheirOwnPRs() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: uniqueStorageKey())
        let baselineStart = Date(timeIntervalSince1970: 1_700_300_000)

        store.startSession(at: baselineStart)
        let pullUpID = try #require(
            store.addExercise(exerciseID: "pull-up", exerciseName: "Pull-Up")
        )
        _ = store.addSet(to: pullUpID, reps: 8, isBodyweight: true)
        let squatID = try #require(
            store.addExercise(exerciseID: "back-squat", exerciseName: "Back Squat")
        )
        _ = store.addSet(to: squatID, reps: 5, weightKg: 100)
        _ = try #require(store.completeActiveSession(at: baselineStart.addingTimeInterval(2_000)))

        store.startSession(at: baselineStart.addingTimeInterval(86_400))
        let currentPullUpID = try #require(
            store.addExercise(exerciseID: "pull-up", exerciseName: "Pull-Up")
        )
        _ = store.addSet(to: currentPullUpID, reps: 10, isBodyweight: true)
        let currentSquatID = try #require(
            store.addExercise(exerciseID: "back-squat", exerciseName: "Back Squat")
        )
        _ = store.addSet(to: currentSquatID, reps: 5, weightKg: 105)
        let draft = try #require(store.activeSession)

        let bodyweightPR = try #require(
            store.personalRecordComparison(for: "pull-up", in: draft)
        )
        #expect(bodyweightPR.isRepetitionPR)
        #expect(!bodyweightPR.isWeightPR)
        #expect(bodyweightPR.current.bestWeightKg == nil)

        let weightedPR = try #require(
            store.personalRecordComparison(for: "back-squat", in: draft)
        )
        #expect(!weightedPR.isRepetitionPR)
        #expect(weightedPR.isWeightPR)
        #expect(weightedPR.weightChangeKg == 5)
        #expect(store.allTimeRecords(for: "back-squat")?.bestWeightKg == 100)
    }

    @Test func weightPRIgnoresConversionScaleRounding() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let store = StrengthWorkoutStore(userDefaults: defaults, storageKey: uniqueStorageKey())
        let start = Date(timeIntervalSince1970: 1_700_400_000)
        let baselineKg = StrengthWorkoutWeight.kilograms(fromPounds: 220)

        store.startSession(at: start)
        let exerciseID = try #require(
            store.addExercise(exerciseID: "deadlift", exerciseName: "Deadlift")
        )
        _ = store.addSet(to: exerciseID, reps: 5, weightKg: baselineKg)
        _ = try #require(store.completeActiveSession(at: start.addingTimeInterval(1_000)))

        store.startSession(at: start.addingTimeInterval(86_400))
        let currentExerciseID = try #require(
            store.addExercise(exerciseID: "deadlift", exerciseName: "Deadlift")
        )
        let currentSetID = try #require(
            store.addSet(to: currentExerciseID, reps: 5, weightKg: baselineKg + 0.04)
        )
        var draft = try #require(store.activeSession)
        var comparison = try #require(
            store.personalRecordComparison(for: "deadlift", in: draft)
        )
        #expect(!comparison.isWeightPR)

        _ = store.updateSet(
            exerciseID: currentExerciseID,
            setID: currentSetID,
            reps: 5,
            weightKg: baselineKg + StrengthWorkoutWeight.comparisonToleranceKg + 0.001,
            isBodyweight: false
        )
        draft = try #require(store.activeSession)
        comparison = try #require(
            store.personalRecordComparison(for: "deadlift", in: draft)
        )
        #expect(comparison.isWeightPR)

        let roundTripKg = StrengthWorkoutWeight.kilograms(
            fromPounds: StrengthWorkoutWeight.pounds(fromKilograms: baselineKg)
        )
        #expect(abs(roundTripKg - baselineKg) < 0.000_000_1)
    }

    @Test func corruptOrUnsupportedPersistenceFailsClosed() {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }

        let corruptKey = uniqueStorageKey()
        let corruptData = Data("not-json".utf8)
        defaults.set(corruptData, forKey: corruptKey)
        let corruptStore = StrengthWorkoutStore(userDefaults: defaults, storageKey: corruptKey)
        #expect(corruptStore.completedSessions.isEmpty)
        #expect(corruptStore.activeSession == nil)
        #expect(defaults.data(forKey: corruptKey) == nil)
        let corruptBackup = defaults.data(forKey: corruptKey + StrengthWorkoutStore.unreadableBackupSuffix)
            .flatMap { try? JSONDecoder().decode(QuarantinedPayloadsFixture.self, from: $0) }
        #expect(corruptBackup?.payloads.contains(corruptData) == true)
        corruptStore.clearAll()
        #expect(defaults.data(forKey: corruptKey) == nil)
        #expect(defaults.data(forKey: corruptKey + StrengthWorkoutStore.unreadableBackupSuffix) == nil)

        let futureKey = uniqueStorageKey()
        let futureState = FuturePersistedState(
            schemaVersion: 99,
            completedSessions: [],
            activeSession: nil
        )
        let futureData = try? JSONEncoder().encode(futureState)
        defaults.set(futureData, forKey: futureKey)
        let futureStore = StrengthWorkoutStore(userDefaults: defaults, storageKey: futureKey)
        #expect(futureStore.completedSessions.isEmpty)
        #expect(futureStore.activeSession == nil)
        #expect(defaults.data(forKey: futureKey) == nil)
        let futureBackup = defaults.data(forKey: futureKey + StrengthWorkoutStore.unreadableBackupSuffix)
            .flatMap { try? JSONDecoder().decode(QuarantinedPayloadsFixture.self, from: $0) }
        #expect(futureBackup?.payloads.contains(where: { $0 == futureData }) == true)
    }

    @Test func readableQuarantineMergesWithCurrentState() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let key = uniqueStorageKey()
        let firstStart = Date(timeIntervalSince1970: 1_700_450_000)

        var store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        store.startSession(name: "Recovered", at: firstStart)
        let recoveredExerciseID = try #require(
            store.addExercise(exerciseID: "recovered-row", exerciseName: "Recovered Row")
        )
        _ = store.addSet(to: recoveredExerciseID, reps: 8, weightKg: 50)
        let recoveredSession = try #require(
            store.completeActiveSession(at: firstStart.addingTimeInterval(900))
        )
        let recoverablePayload = try #require(defaults.data(forKey: key))

        defaults.removeObject(forKey: key)
        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        let currentStart = firstStart.addingTimeInterval(86_400)
        store.startSession(name: "Current", at: currentStart)
        let currentExerciseID = try #require(
            store.addExercise(exerciseID: "current-press", exerciseName: "Current Press")
        )
        _ = store.addSet(to: currentExerciseID, reps: 6, weightKg: 70)
        let currentSession = try #require(
            store.completeActiveSession(at: currentStart.addingTimeInterval(1_200))
        )

        // The first backup format stored one raw state payload directly.
        defaults.set(recoverablePayload, forKey: key + StrengthWorkoutStore.unreadableBackupSuffix)
        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)

        #expect(Set(store.completedSessions.map(\.id)) == Set([recoveredSession.id, currentSession.id]))
        #expect(defaults.data(forKey: key + StrengthWorkoutStore.unreadableBackupSuffix) == nil)
        #expect(StrengthWorkoutStore(userDefaults: defaults, storageKey: key).completedSessions.count == 2)
    }

    @Test func conflictingRecoveredActiveDraftStaysQuarantinedUntilCurrentDraftEnds() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let key = uniqueStorageKey()
        let recoveredStart = Date(timeIntervalSince1970: 1_700_470_000)

        var store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        let recoveredDraft = store.startSession(name: "Recovered Draft", at: recoveredStart)
        let recoveredPayload = try #require(defaults.data(forKey: key))

        defaults.removeObject(forKey: key)
        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        let currentDraft = store.startSession(
            name: "Current Draft",
            at: recoveredStart.addingTimeInterval(3_600)
        )
        defaults.set(recoveredPayload, forKey: key + StrengthWorkoutStore.unreadableBackupSuffix)

        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        #expect(store.activeSession?.id == currentDraft.id)
        #expect(defaults.data(forKey: key + StrengthWorkoutStore.unreadableBackupSuffix) != nil)

        store.discardActiveSession()
        store = StrengthWorkoutStore(userDefaults: defaults, storageKey: key)
        #expect(store.activeSession?.id == recoveredDraft.id)
        #expect(defaults.data(forKey: key + StrengthWorkoutStore.unreadableBackupSuffix) == nil)
    }

    @Test @MainActor func prePerformedFieldPayloadTreatsLoggedRepsAsPerformed() throws {
        let fixture = PrePerformedSetFixture(
            id: UUID(),
            reps: 7,
            weightKg: 42.5,
            isBodyweight: false
        )
        let decoded = try JSONDecoder().decode(
            StrengthWorkoutSet.self,
            from: JSONEncoder().encode(fixture)
        )

        #expect(decoded.isPerformed)
        #expect(decoded.isRecorded)
    }

    @Test func legacyCompletedSessionsMigrateWithoutLosingBodyweightMeaning() throws {
        let defaults = makeUserDefaults()
        defer { clear(defaults) }
        let date = Date(timeIntervalSince1970: 1_700_500_000)
        let legacySetID = UUID()
        let legacySession = LegacySessionFixture(
            id: UUID(),
            date: date,
            name: "Legacy Pull",
            exercises: [
                LegacyExerciseFixture(
                    id: UUID(),
                    exerciseID: "pull-up",
                    exerciseName: "Pull-Up",
                    sets: [
                        LegacySetFixture(
                            id: legacySetID,
                            reps: 9,
                            weightKg: nil,
                            isBodyweight: true
                        )
                    ]
                )
            ]
        )
        defaults.set(
            try JSONEncoder().encode([legacySession]),
            forKey: StrengthWorkoutStore.legacyStorageKey
        )

        let store = StrengthWorkoutStore(userDefaults: defaults)
        let migrated = try #require(store.completedSessions.first)

        #expect(store.completedSessions.count == 1)
        #expect(migrated.id == legacySession.id)
        #expect(migrated.startedAt == date)
        #expect(migrated.completedAt == date)
        #expect(migrated.duration == nil)
        #expect(migrated.exercises.first?.sets.first?.id == legacySetID)
        #expect(migrated.exercises.first?.sets.first?.isBodyweight == true)
        #expect(migrated.exercises.first?.sets.first?.isPerformed == true)
        #expect(defaults.data(forKey: StrengthWorkoutStore.defaultStorageKey) != nil)
        #expect(defaults.data(forKey: StrengthWorkoutStore.legacyStorageKey) == nil)
    }
}

private struct FuturePersistedState: Codable {
    let schemaVersion: Int
    let completedSessions: [StrengthWorkoutSession]
    let activeSession: StrengthWorkoutSession?
}

private struct QuarantinedPayloadsFixture: Codable {
    let payloads: [Data]
}

private struct PrePerformedSetFixture: Codable {
    let id: UUID
    let reps: Int
    let weightKg: Double?
    let isBodyweight: Bool
}

private struct LegacySessionFixture: Codable {
    let id: UUID
    let date: Date
    let name: String?
    let exercises: [LegacyExerciseFixture]
}

private struct LegacyExerciseFixture: Codable {
    let id: UUID
    let exerciseID: String
    let exerciseName: String
    let sets: [LegacySetFixture]
}

private struct LegacySetFixture: Codable {
    let id: UUID
    let reps: Int
    let weightKg: Double?
    let isBodyweight: Bool?
}

private func makeUserDefaults() -> UserDefaults {
    let suiteName = "StrengthWorkoutStoreTests.\(UUID().uuidString)"
    return UserDefaults(suiteName: suiteName)!
}

private func uniqueStorageKey() -> String {
    "strengthWorkoutTests.\(UUID().uuidString)"
}

private func clear(_ defaults: UserDefaults) {
    for key in defaults.dictionaryRepresentation().keys {
        defaults.removeObject(forKey: key)
    }
}
