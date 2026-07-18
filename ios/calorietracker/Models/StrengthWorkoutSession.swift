import Foundation

/// Shared keys for the optional, local-only strength logger.
enum StrengthWorkoutSettings {
    /// The feature remains disabled until the user explicitly enables it.
    static let enabledKey = "strengthWorkoutLoggerEnabled"
}

/// One completed set. Load is stored canonically in kilograms while bodyweight
/// remains explicit so the history stays semantically clear.
struct StrengthWorkoutSet: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var reps: Int
    var weightKg: Double?
    var isBodyweight: Bool

    init(
        id: UUID = UUID(),
        reps: Int,
        weightKg: Double? = nil,
        isBodyweight: Bool? = nil
    ) {
        self.id = id
        self.reps = reps
        self.weightKg = weightKg
        self.isBodyweight = isBodyweight ?? (weightKg == nil)
    }
}

/// An exercise performed during a session. Both the database ID and a name
/// snapshot are stored so old logs stay readable if the bundled catalog changes.
struct StrengthWorkoutExercise: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let exerciseID: String
    var exerciseName: String
    var sets: [StrengthWorkoutSet]

    init(
        id: UUID = UUID(),
        exerciseID: String,
        exerciseName: String,
        sets: [StrengthWorkoutSet] = []
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
    }
}

/// A locally logged strength-training session.
struct StrengthWorkoutSession: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var date: Date
    var name: String?
    var exercises: [StrengthWorkoutExercise]

    init(
        id: UUID = UUID(),
        date: Date = .now,
        name: String? = nil,
        exercises: [StrengthWorkoutExercise] = []
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.exercises = exercises
    }

    var setCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }
}

/// One exercise occurrence in session history.
struct StrengthExerciseHistoryEntry: Identifiable, Equatable {
    var id: UUID { exercise.id }

    let sessionID: UUID
    let date: Date
    let sessionName: String?
    let exercise: StrengthWorkoutExercise
}

/// Best values calculated from any collection of sets.
struct StrengthExercisePerformance: Equatable {
    let bestReps: Int?
    let bestWeightKg: Double?

    init(sets: [StrengthWorkoutSet]) {
        bestReps = sets
            .map(\.reps)
            .filter { $0 > 0 }
            .max()
        bestWeightKg = sets
            .compactMap(\.weightKg)
            .filter { $0 > 0 }
            .max()
    }

    var hasRecordedValue: Bool {
        bestReps != nil || bestWeightKg != nil
    }
}

/// Compares the current session's best set values with all earlier sessions.
/// A first-ever log establishes the baseline and is not presented as an
/// improvement PR until there is previous performance to beat.
struct StrengthPersonalRecordComparison: Equatable {
    let current: StrengthExercisePerformance
    let previous: StrengthExercisePerformance?

    var repetitionChange: Int? {
        guard let current = current.bestReps, let previous = previous?.bestReps else { return nil }
        return current - previous
    }

    var weightChangeKg: Double? {
        guard let current = current.bestWeightKg, let previous = previous?.bestWeightKg else { return nil }
        return current - previous
    }

    var isRepetitionPR: Bool { (repetitionChange ?? 0) > 0 }
    /// Ignore sub-display-unit floating-point drift from kg/lb conversion.
    var isWeightPR: Bool { (weightChangeKg ?? 0) > 0.05 }
    var hasPersonalRecord: Bool { isRepetitionPR || isWeightPR }
}
