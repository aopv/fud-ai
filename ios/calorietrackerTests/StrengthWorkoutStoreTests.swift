import CoreGraphics
import Foundation
import Testing
@testable import calorietracker

@MainActor
struct StrengthWorkoutStoreTests {
    @Test func workoutTabModeUsesModeSpecificIconsAndSafeFallback() {
        #expect(WorkoutTabMode.mode(for: WorkoutTabMode.library.rawValue) == .library)
        #expect(WorkoutTabMode.mode(for: WorkoutTabMode.log.rawValue) == .log)
        #expect(WorkoutTabMode.mode(for: "unknown") == .log)
        #expect(WorkoutTabMode.defaultMode == .log)
        #expect(WorkoutTabMode.storageKey == "fudai.workouts.tab.mode.v2")
        #expect(WorkoutTabMode.library.tabIcon == "dumbbell.fill")
        #expect(WorkoutTabMode.log.tabIcon == "figure.strengthtraining.traditional")
    }

    @Test func workoutPreferencesDefaultToFullBodyAndMigrateLegacyCustomSplits() {
        var preferences = StrengthWorkoutPreferences()

        #expect(preferences.split == .fullBody)
        #expect(StrengthWorkoutSplit.selectableCases.first == .fullBody)
        #expect(!StrengthWorkoutSplit.selectableCases.contains(.custom))

        preferences.split = .custom
        preferences.customSplit = "Chest + back / Legs / Arms"
        preferences.sanitize()

        #expect(preferences.split == .fullBody)
        #expect(preferences.customSplit.isEmpty)
    }

    @Test func workoutLogStatePreservesSelectedDayUntilFullReset() {
        let selectedDate = WorkoutTestFixture.date(2026, 7, 12)
        let session = WorkoutLogSessionState()
        session.selectedDate = selectedDate

        #expect(session.selectedDate == selectedDate)
    }

    @Test func workoutLogFullResetReturnsToToday() {
        let session = WorkoutLogSessionState()
        session.selectedDate = WorkoutTestFixture.date(2026, 7, 12)

        session.reset()

        #expect(Calendar.current.isDateInToday(session.selectedDate))
    }

    @Test func workoutLogDayNavigationMovesOneDayAndStopsAtToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let today = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 20,
            hour: 12
        )))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let session = WorkoutLogSessionState()
        session.selectedDate = yesterday

        #expect(session.moveSelectedDay(by: 1, now: today, calendar: calendar))
        #expect(calendar.isDate(session.selectedDate, inSameDayAs: today))

        #expect(!session.moveSelectedDay(by: 1, now: today, calendar: calendar))
        #expect(calendar.isDate(session.selectedDate, inSameDayAs: today))

        #expect(session.moveSelectedDay(by: -1, now: today, calendar: calendar))
        #expect(calendar.isDate(session.selectedDate, inSameDayAs: yesterday))
    }

    @Test func workoutLogDaySwipeRequiresADeliberateHorizontalFlick() {
        #expect(WorkoutLogDaySwipeNavigation.dayDelta(for: CGSize(width: -61, height: 10)) == 1)
        #expect(WorkoutLogDaySwipeNavigation.dayDelta(for: CGSize(width: 61, height: -10)) == -1)
        #expect(WorkoutLogDaySwipeNavigation.dayDelta(for: CGSize(width: 60, height: 0)) == nil)
        #expect(WorkoutLogDaySwipeNavigation.dayDelta(for: CGSize(width: 100, height: 70)) == nil)
    }

    @Test func workoutLogKeyboardDismissesOnlyOutsideWorkoutCards() {
        let cardFrames = [
            CGRect(x: 16, y: 300, width: 320, height: 240),
            CGRect(x: 16, y: 554, width: 320, height: 280)
        ]

        #expect(!WorkoutLogKeyboardDismissal.shouldDismiss(
            at: CGPoint(x: 120, y: 420),
            cardFrames: cardFrames
        ))
        #expect(!WorkoutLogKeyboardDismissal.shouldDismiss(
            at: CGPoint(x: 300, y: 700),
            cardFrames: cardFrames
        ))
        #expect(WorkoutLogKeyboardDismissal.shouldDismiss(
            at: CGPoint(x: 120, y: 180),
            cardFrames: cardFrames
        ))
        #expect(WorkoutLogKeyboardDismissal.shouldDismiss(
            at: CGPoint(x: 8, y: 420),
            cardFrames: cardFrames
        ))
        #expect(!WorkoutLogKeyboardDismissal.shouldDismiss(
            at: CGPoint(x: 120, y: 180),
            cardFrames: []
        ))
    }

    @Test func persistenceReloadRestoresDiarySavedExercisesAndPreferences() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let workoutDate = WorkoutTestFixture.date(2026, 7, 12)
        let exercise = WorkoutTestFixture.exercise(
            id: "barbell-bench-press",
            name: "Barbell Bench Press",
            equipment: "barbell",
            muscles: ["chest", "triceps"]
        )
        let store = fixture.makeStore()

        store.toggleExercise(exercise, on: workoutDate)
        let planned = try #require(store.exercises(for: workoutDate).first)
        let plannedSet = try #require(planned.sets.first)
        store.updateSet(
            exerciseID: planned.id,
            setID: plannedSet.id,
            on: workoutDate,
            weight: "82,5 kg",
            weightUnit: .kg,
            reps: "8 reps",
            rpe: "7.5"
        )
        store.toggleSaved(exercise.id)
        store.updatePreferences { preferences in
            preferences.targetMuscles = ["Chest", "Triceps"]
            preferences.issues = [.shoulder, .other]
            preferences.additionalIssues = "  Avoid deep dips  "
            preferences.frequencyDays = 10
            preferences.duration = .seventyFive
            preferences.split = .upperLower
            preferences.equipment = ["Barbell", "Bench"]
            preferences.rpeScale = .cr10
            preferences.strength.benchPressKg = 100
            preferences.strength.squatKg = -5
        }

        let reloaded = fixture.makeStore()
        let restoredExercise = try #require(reloaded.exercises(for: workoutDate).first)
        let restoredSet = try #require(restoredExercise.sets.first)

        #expect(restoredExercise.itemID == exercise.id)
        #expect(restoredSet.weight == "82.5")
        #expect(restoredSet.weightUnit == WeightUnit.kg.rawValue)
        #expect(restoredSet.reps == "8")
        #expect(restoredSet.rpe == "7.5")
        #expect(restoredSet.rpeScale == .strength)
        #expect(reloaded.savedExerciseIDs == [exercise.id])
        #expect(reloaded.preferences.targetMuscles == ["Chest", "Triceps"])
        #expect(reloaded.preferences.issues == [.shoulder, .other])
        #expect(reloaded.preferences.additionalIssues == "Avoid deep dips")
        #expect(reloaded.preferences.frequencyDays == 7)
        #expect(reloaded.preferences.duration == .seventyFive)
        #expect(reloaded.preferences.split == .upperLower)
        #expect(reloaded.preferences.rpeScale == .cr10)
        #expect(reloaded.preferences.strength.benchPressKg == 100)
        #expect(reloaded.preferences.strength.squatKg == nil)
    }

    @Test func toggleAndCopyPlanDeduplicateExercisesAndResetCopiedSets() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let sourceDate = WorkoutTestFixture.date(2026, 7, 10)
        let targetDate = WorkoutTestFixture.date(2026, 7, 11)
        let bench = WorkoutTestFixture.exercise(id: "bench", name: "Bench Press")
        let row = WorkoutTestFixture.exercise(
            id: "row",
            name: "Barbell Row",
            equipment: "barbell",
            muscles: ["middle back"]
        )
        let store = fixture.makeStore()

        store.toggleExercise(bench, on: sourceDate)
        #expect(store.containsExercise(bench.id, on: sourceDate))
        store.toggleExercise(bench, on: sourceDate)
        #expect(!store.containsExercise(bench.id, on: sourceDate))
        #expect(store.plan(for: sourceDate).exercises.isEmpty)

        store.toggleExercise(bench, on: sourceDate)
        store.toggleExercise(row, on: sourceDate)
        let sourceRow = try #require(store.exercises(for: sourceDate).first { $0.itemID == row.id })
        let sourceSet = try #require(sourceRow.sets.first)
        store.updateSet(
            exerciseID: sourceRow.id,
            setID: sourceSet.id,
            on: sourceDate,
            weight: "70",
            weightUnit: .kg,
            reps: "10",
            rpe: "8"
        )
        store.setSetCount(3, exerciseID: sourceRow.id, on: sourceDate)

        store.toggleExercise(bench, on: targetDate)
        store.copyPlan(from: sourceDate, to: targetDate)
        store.copyPlan(from: sourceDate, to: targetDate)

        let copied = store.exercises(for: targetDate)
        #expect(copied.map(\.itemID) == [bench.id, row.id])
        #expect(Set(copied.map(\.itemID)).count == copied.count)
        let copiedRow = try #require(copied.first { $0.itemID == row.id })
        #expect(copiedRow.id != sourceRow.id)
        #expect(copiedRow.sets.count == 1)
        #expect(copiedRow.sets[0].weight.isEmpty)
        #expect(copiedRow.sets[0].weightUnit == nil)
        #expect(copiedRow.sets[0].reps.isEmpty)
        #expect(copiedRow.sets[0].rpe.isEmpty)
        #expect(store.previousPlanDates(before: targetDate) == [sourceDate])
    }

    @Test func setLimitsAddBlankRowsAndSanitizeLoadRepsAndRPEScales() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 13)
        let exercise = WorkoutTestFixture.exercise(id: "squat", name: "Back Squat")
        let store = fixture.makeStore()
        store.toggleExercise(exercise, on: date)

        var planned = try #require(store.exercises(for: date).first)
        var firstSet = try #require(planned.sets.first)
        store.updateSet(
            exerciseID: planned.id,
            setID: firstSet.id,
            on: date,
            weight: "100,5 kg",
            weightUnit: .kg,
            reps: "12a345",
            rpe: "7.5"
        )
        store.setSetCount(99, exerciseID: planned.id, on: date)

        planned = try #require(store.exercises(for: date).first)
        #expect(planned.sets.count == 12)
        #expect(planned.sets[0].weight == "100.5")
        #expect(planned.sets[0].weightUnit == WeightUnit.kg.rawValue)
        #expect(planned.sets[0].reps == "1234")
        #expect(planned.sets[0].rpe == "7.5")
        #expect(planned.sets.dropFirst().allSatisfy {
            $0.weight.isEmpty
                && $0.weightUnit == nil
                && $0.reps.isEmpty
                && $0.rpe.isEmpty
                && $0.rpeScale == nil
        })

        store.setSetCount(-4, exerciseID: planned.id, on: date)
        planned = try #require(store.exercises(for: date).first)
        #expect(planned.sets.count == 1)

        store.updatePreferences { $0.rpeScale = .cr10 }
        firstSet = try #require(planned.sets.first)
        store.updateSet(exerciseID: planned.id, setID: firstSet.id, on: date, rpe: "8,6")
        #expect(store.exercises(for: date)[0].sets[0].rpe == "8.6")

        store.updatePreferences { $0.rpeScale = .borg }
        store.updateSet(exerciseID: planned.id, setID: firstSet.id, on: date, rpe: "18")
        #expect(store.exercises(for: date)[0].sets[0].rpe == "18")
        store.updateSet(exerciseID: planned.id, setID: firstSet.id, on: date, rpe: "99")
        #expect(store.exercises(for: date)[0].sets[0].rpe == "20")
        store.updateSet(exerciseID: planned.id, setID: firstSet.id, on: date, rpe: "5")
        #expect(store.exercises(for: date)[0].sets[0].rpe == "20")
    }

    @Test func plannedSetWeightDisplayFollowsGlobalUnitWithoutMutatingStoredLoad() {
        let metricSet = StrengthPlannedSet(weight: "100", weightUnit: WeightUnit.kg.rawValue)
        #expect(metricSet.displayWeight(in: .kg) == "100")
        #expect(metricSet.displayWeight(in: .lbs) == "220.46")
        #expect(metricSet.weight == "100")
        #expect(metricSet.weightUnit == WeightUnit.kg.rawValue)

        let imperialSet = StrengthPlannedSet(weight: "220.46", weightUnit: WeightUnit.lbs.rawValue)
        #expect(imperialSet.displayWeight(in: .kg) == "100")
        #expect(imperialSet.displayWeight(in: .lbs) == "220.46")

        let legacySet = StrengthPlannedSet(weight: "75")
        #expect(legacySet.displayWeight(in: .kg) == "75")
        #expect(legacySet.displayWeight(in: .lbs) == "75")
    }

    @Test func completionBuildsStatisticsFiltersDatesDeletesAndPersistsSessions() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let firstDate = WorkoutTestFixture.date(2026, 7, 8)
        let secondDate = WorkoutTestFixture.date(2026, 7, 10)
        let thirdDate = WorkoutTestFixture.date(2026, 7, 12)
        let bench = WorkoutTestFixture.exercise(
            id: "bench",
            name: "Bench Press",
            equipment: "barbell",
            muscles: ["chest"]
        )
        let store = fixture.makeStore()

        #expect(
            store.completeWorkout(
                on: firstDate,
                startedAt: firstDate,
                completedAt: firstDate,
                elapsedSeconds: 60,
                weightUnit: .kg
            ) == nil
        )

        func addCompletedWorkout(on date: Date, weight: String, reps: String, elapsed: Int) throws -> StrengthWorkoutSession {
            store.toggleExercise(bench, on: date)
            let exercise = try #require(store.exercises(for: date).first)
            let firstSet = try #require(exercise.sets.first)
            store.updateSet(
                exerciseID: exercise.id,
                setID: firstSet.id,
                on: date,
                weight: weight,
                weightUnit: .lbs,
                reps: reps,
                rpe: "8.5"
            )
            store.setSetCount(2, exerciseID: exercise.id, on: date)
            return try #require(
                store.completeWorkout(
                    on: date,
                    startedAt: date.addingTimeInterval(-Double(elapsed)),
                    completedAt: date,
                    elapsedSeconds: elapsed,
                    weightUnit: .kg
                )
            )
        }

        let first = try addCompletedWorkout(on: firstDate, weight: "80", reps: "8", elapsed: 61)
        let second = try addCompletedWorkout(on: secondDate, weight: "82.5", reps: "6", elapsed: 600)
        let third = try addCompletedWorkout(on: thirdDate, weight: "85", reps: "5", elapsed: 900)

        #expect(first.exerciseCount == 1)
        #expect(first.exercises[0].sets.count == 2)
        #expect(first.performedSetCount == 1)
        #expect(first.repCount == 8)
        #expect(first.durationSeconds == 61)
        #expect(first.durationMinutes == 2)
        #expect(first.exercises[0].sets[0].weightUnit == WeightUnit.lbs.rawValue)
        #expect(first.exercises[0].sets[0].rpeScale == .strength)
        #expect(first.stableDiaryDateKey == "2026-07-08")
        #expect(StrengthWorkoutStore.dateKey(for: first.calendarDiaryDate) == "2026-07-08")
        #expect(!first.exercises[0].sets[1].isPerformed)
        #expect(store.latestSession(on: secondDate)?.id == second.id)

        let middleRange = store.sessions(from: firstDate, through: secondDate)
        #expect(middleRange.map(\.id) == [first.id, second.id])
        #expect(!middleRange.contains { $0.id == third.id })
        #expect(fixture.makeStore().completedSessions.count == 3)

        store.deleteSession(second.id)
        let remainingIDs = Set(store.completedSessions.map(\.id))
        let expectedIDs: Set<UUID> = [first.id, third.id]
        #expect(remainingIDs == expectedIDs)
        #expect(fixture.makeStore().completedSessions.count == 2)
    }

    @Test func burnEstimatorRequiresPerformedSetsAndRespondsToEffortAndLoad() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 18)
        let store = fixture.makeStore()
        store.toggleExercise(
            WorkoutTestFixture.exercise(id: "curl", name: "Dumbbell Curl", equipment: "dumbbell", muscles: ["biceps"]),
            on: date
        )

        var exercise = try #require(store.exercises(for: date).first)
        var set = try #require(exercise.sets.first)
        #expect(
            StrengthWorkoutBurnEstimator.estimate(
                exercises: [exercise],
                bodyWeightKg: 75,
                defaultWeightUnit: .kg,
                defaultRPEScale: .strength
            ) == nil
        )

        store.updateSet(
            exerciseID: exercise.id,
            setID: set.id,
            on: date,
            weight: "8",
            weightUnit: .kg,
            reps: "12",
            rpe: "3"
        )
        exercise = try #require(store.exercises(for: date).first)
        let easier = try #require(
            StrengthWorkoutBurnEstimator.estimate(
                exercises: [exercise],
                bodyWeightKg: 75,
                defaultWeightUnit: .kg,
                defaultRPEScale: .strength
            )
        )

        set = try #require(exercise.sets.first)
        store.updateSet(
            exerciseID: exercise.id,
            setID: set.id,
            on: date,
            weight: "40",
            weightUnit: .kg,
            rpe: "10"
        )
        exercise = try #require(store.exercises(for: date).first)
        let harder = try #require(
            StrengthWorkoutBurnEstimator.estimate(
                exercises: [exercise],
                bodyWeightKg: 75,
                defaultWeightUnit: .kg,
                defaultRPEScale: .strength
            )
        )

        #expect(easier.performedSetCount == 1)
        #expect(easier.repCount == 12)
        #expect(harder.calories > easier.calories)
        #expect((1...5_000).contains(harder.calories))
    }

    @Test func calculatedBurnUpsertsOneStableDailyRecordAndDeletesHealthByExactID() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 19)
        let store = fixture.makeStore()
        store.toggleExercise(WorkoutTestFixture.exercise(id: "squat", name: "Back Squat"), on: date)
        let exercise = try #require(store.exercises(for: date).first)
        let set = try #require(exercise.sets.first)
        store.updateSet(
            exerciseID: exercise.id,
            setID: set.id,
            on: date,
            weight: "100",
            weightUnit: .kg,
            reps: "8",
            rpe: "8"
        )

        var exported: [StrengthWorkoutSession] = []
        var deletedIDs: [UUID] = []
        store.onWorkoutBurnUpserted = { exported.append($0) }
        store.onWorkoutBurnDeleted = { deletedIDs.append($0) }

        let first = try #require(store.upsertCalculatedWorkout(on: date, caloriesBurned: 180, weightUnit: .kg))
        let second = try #require(store.upsertCalculatedWorkout(on: date, caloriesBurned: 225, weightUnit: .kg))

        #expect(first.id == second.id)
        #expect(first.healthSyncVersion == 1)
        #expect(second.healthSyncVersion == 2)
        #expect(second.caloriesBurned == 225)
        #expect(second.durationSeconds == 0)
        #expect(second.durationMinutes == 0)
        #expect(store.workoutBurnSessions.count == 1)
        #expect(store.caloriesBurned(on: date) == 225)
        #expect(exported.map(\.id) == [first.id, first.id])
        #expect(fixture.makeStore().workoutBurnSessions.first?.caloriesBurned == 225)

        store.deleteSession(second.id)
        #expect(store.workoutBurnSessions.isEmpty)
        #expect(store.exercises(for: date).count == 1)
        #expect(deletedIDs == [second.id])
    }

    @Test func timerEraSessionJSONWithoutBurnFieldsStillDecodes() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 17)
        let store = fixture.makeStore()
        store.toggleExercise(WorkoutTestFixture.exercise(id: "row", name: "Barbell Row"), on: date)
        _ = try #require(
            store.completeWorkout(
                on: date,
                startedAt: date,
                completedAt: date.addingTimeInterval(600),
                elapsedSeconds: 600,
                weightUnit: .kg
            )
        )

        let encoded = try #require(fixture.defaults.data(forKey: fixture.storageKey))
        var root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var sessions = try #require(root["completedSessions"] as? [[String: Any]])
        sessions[0].removeValue(forKey: "caloriesBurned")
        sessions[0].removeValue(forKey: "healthSyncVersion")
        root["completedSessions"] = sessions
        fixture.defaults.set(try JSONSerialization.data(withJSONObject: root), forKey: fixture.storageKey)

        let restored = try #require(fixture.makeStore().completedSessions.first)
        #expect(restored.caloriesBurned == nil)
        #expect(restored.healthSyncVersion == nil)
        #expect(restored.durationSeconds == 600)
    }

    @Test func burnCalculationPreservesLegacySessionsAndHealthMergePreservesSetDetails() throws {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 16)
        let store = fixture.makeStore()
        store.toggleExercise(WorkoutTestFixture.exercise(id: "press", name: "Shoulder Press"), on: date)
        let exercise = try #require(store.exercises(for: date).first)
        let set = try #require(exercise.sets.first)
        store.updateSet(
            exerciseID: exercise.id,
            setID: set.id,
            on: date,
            weight: "30",
            weightUnit: .kg,
            reps: "10",
            rpe: "8"
        )

        let legacy = try #require(
            store.completeWorkout(
                on: date,
                startedAt: date,
                completedAt: date.addingTimeInterval(600),
                elapsedSeconds: 600,
                weightUnit: .kg
            )
        )
        let burn = try #require(
            store.upsertCalculatedWorkout(
                on: date,
                caloriesBurned: 160,
                weightUnit: .kg,
                calculatedAt: date.addingTimeInterval(1_200)
            )
        )

        #expect(store.completedSessions.contains(where: { $0.id == legacy.id }))
        #expect(store.completedSessions.count == 2)
        #expect(store.workoutBurnSessions.map(\.id) == [burn.id])

        let healthVersion = StrengthWorkoutSession(
            id: burn.id,
            diaryDate: date,
            diaryDateKey: burn.stableDiaryDateKey,
            startedAt: date.addingTimeInterval(1_800),
            completedAt: date.addingTimeInterval(1_800),
            durationSeconds: 0,
            exercises: [],
            caloriesBurned: 190,
            healthSyncVersion: 2
        )
        store.importWorkoutBurnSessions([healthVersion])

        let merged = try #require(store.workoutBurnSessions.first)
        #expect(merged.caloriesBurned == 190)
        #expect(merged.healthSyncVersion == 2)
        #expect(merged.exercises.first?.name == "Shoulder Press")
        #expect(merged.performedSetCount == 1)
    }

    @Test func clearAllResetsMemoryAndRemovesPersistedWorkoutState() {
        let fixture = WorkoutTestFixture()
        defer { fixture.cleanUp() }

        let date = WorkoutTestFixture.date(2026, 7, 14)
        let exercise = WorkoutTestFixture.exercise(id: "deadlift", name: "Deadlift")
        let store = fixture.makeStore()
        store.toggleExercise(exercise, on: date)
        store.toggleSaved(exercise.id)
        store.updatePreferences {
            $0.frequencyDays = 6
            $0.targetMuscles = ["Hamstrings"]
        }

        #expect(fixture.defaults.data(forKey: fixture.storageKey) != nil)
        store.clearAll()

        #expect(store.dayPlans.isEmpty)
        #expect(store.completedSessions.isEmpty)
        #expect(store.savedExerciseIDs.isEmpty)
        #expect(store.preferences == StrengthWorkoutPreferences())
        #expect(fixture.defaults.object(forKey: fixture.storageKey) == nil)

        let reloaded = fixture.makeStore()
        #expect(reloaded.dayPlans.isEmpty)
        #expect(reloaded.completedSessions.isEmpty)
        #expect(reloaded.savedExerciseIDs.isEmpty)
        #expect(reloaded.preferences == StrengthWorkoutPreferences())
    }
}

@MainActor
final class WorkoutTestFixture {
    let suiteName: String
    let storageKey: String
    let defaults: UserDefaults

    init() {
        let identifier = UUID().uuidString
        suiteName = "StrengthWorkoutStoreTests.\(identifier)"
        storageKey = "strength-workout-state.\(identifier)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    func makeStore() -> StrengthWorkoutStore {
        StrengthWorkoutStore(defaults: defaults, storageKey: storageKey)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func exercise(
        id: String,
        name: String,
        equipment: String = "barbell",
        muscles: [String] = ["chest"]
    ) -> ExerciseLibraryItem {
        ExerciseLibraryItem(
            id: id,
            name: name,
            rawLevel: "intermediate",
            force: "push",
            mechanic: "compound",
            category: "strength",
            rawEquipment: equipment,
            primaryMuscles: muscles,
            secondaryMuscles: ["triceps"],
            instructions: ["Control the repetition."]
        )
    }
}
