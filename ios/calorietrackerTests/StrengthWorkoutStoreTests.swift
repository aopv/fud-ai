import Foundation
import Testing
@testable import calorietracker

@MainActor
struct StrengthWorkoutStoreTests {
    @Test func workoutTabModeUsesModeSpecificIconsAndSafeFallback() {
        #expect(WorkoutTabMode.mode(for: WorkoutTabMode.library.rawValue) == .library)
        #expect(WorkoutTabMode.mode(for: WorkoutTabMode.log.rawValue) == .log)
        #expect(WorkoutTabMode.mode(for: "unknown") == .library)
        #expect(WorkoutTabMode.mode(for: WorkoutTabMode.log.rawValue, isLoggingEnabled: false) == .library)
        #expect(WorkoutTabMode.library.tabIcon == "dumbbell.fill")
        #expect(WorkoutTabMode.log.tabIcon == "figure.strengthtraining.traditional")
    }

    @Test func workoutLogTimerResetPreservesSelectedDay() {
        let selectedDate = WorkoutTestFixture.date(2026, 7, 12)
        let session = WorkoutLogSessionState()
        session.selectedDate = selectedDate
        session.activeSessionDate = selectedDate
        session.activeSessionDateKey = StrengthWorkoutStore.dateKey(for: selectedDate)
        session.workoutStartedAt = selectedDate
        session.runningSegmentStartedAt = selectedDate
        session.accumulatedElapsedSeconds = 90

        session.resetTimer()

        #expect(session.selectedDate == selectedDate)
        #expect(session.activeSessionDate == nil)
        #expect(session.activeSessionDateKey == nil)
        #expect(session.workoutStartedAt == nil)
        #expect(session.runningSegmentStartedAt == nil)
        #expect(session.accumulatedElapsedSeconds == 0)
    }

    @Test func workoutLogFullResetReturnsToToday() {
        let session = WorkoutLogSessionState()
        session.selectedDate = WorkoutTestFixture.date(2026, 7, 12)
        session.activeSessionDate = session.selectedDate

        session.reset()

        #expect(Calendar.current.isDateInToday(session.selectedDate))
        #expect(session.activeSessionDate == nil)
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

    @Test func setLimitsCarryWeightAndSanitizeLoadRepsAndRPEScales() throws {
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
            reps: "12a345",
            rpe: "7.5"
        )
        store.setSetCount(99, exerciseID: planned.id, on: date)

        planned = try #require(store.exercises(for: date).first)
        #expect(planned.sets.count == 12)
        #expect(planned.sets[0].weight == "100.5")
        #expect(planned.sets[0].reps == "1234")
        #expect(planned.sets[0].rpe == "7.5")
        #expect(planned.sets.dropFirst().allSatisfy { $0.weight == "100.5" })
        #expect(planned.sets.dropFirst().allSatisfy { $0.reps.isEmpty && $0.rpe.isEmpty })

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
