import Foundation

/// Shared settings for the optional, local-only workout logger.
enum StrengthWorkoutSettings {
    /// UserDefaults returns `false` while this key is absent. Retaining the
    /// original key also preserves an explicit choice made in an earlier build.
    static let enabledKey = "strengthWorkoutLoggerEnabled"
}

/// Conversion and comparison rules shared by the logger's model, store, and UI.
enum StrengthWorkoutWeight {
    static let kilogramsPerPound = 0.45359237

    /// About one tenth of a pound. Smaller differences can be introduced by
    /// display rounding and must not be presented as a new weight record.
    static let comparisonToleranceKg = 0.05

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds * kilogramsPerPound
    }

    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms / kilogramsPerPound
    }

    static func isMeaningfullyGreater(_ candidateKg: Double, than baselineKg: Double) -> Bool {
        guard candidateKg.isFinite, baselineKg.isFinite else { return false }
        return candidateKg - baselineKg > comparisonToleranceKg
    }
}

/// One set in a workout. Weight is always stored canonically in kilograms.
/// `isBodyweight` distinguishes an intentional bodyweight set from a weighted
/// set whose optional load has not been entered yet.
struct StrengthWorkoutSet: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var reps: Int
    var weightKg: Double?
    var isBodyweight: Bool
    var isPerformed: Bool

    init(
        id: UUID = UUID(),
        reps: Int = 0,
        weightKg: Double? = nil,
        isBodyweight: Bool = false,
        isPerformed: Bool? = nil
    ) {
        self.id = id
        self.reps = max(0, reps)
        self.isBodyweight = isBodyweight
        self.weightKg = Self.validatedWeight(weightKg, isBodyweight: isBodyweight)
        self.isPerformed = isPerformed ?? (reps > 0)
    }

    var isRecorded: Bool {
        isPerformed && reps > 0
    }

    var isWeighted: Bool {
        !isBodyweight && weightKg != nil
    }

    func copiedForNewSession() -> StrengthWorkoutSet {
        StrengthWorkoutSet(
            reps: reps,
            weightKg: weightKg,
            isBodyweight: isBodyweight,
            isPerformed: false
        )
    }

    func sanitized() -> StrengthWorkoutSet {
        StrengthWorkoutSet(
            id: id,
            reps: reps,
            weightKg: weightKg,
            isBodyweight: isBodyweight,
            isPerformed: isPerformed
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weightKg
        case isBodyweight
        case isPerformed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let reps = try container.decode(Int.self, forKey: .reps)
        let weightKg = try container.decodeIfPresent(Double.self, forKey: .weightKg)
        let isBodyweight = try container.decode(Bool.self, forKey: .isBodyweight)
        let isPerformed = try container.decodeIfPresent(Bool.self, forKey: .isPerformed)

        self.init(
            id: id,
            reps: reps,
            weightKg: weightKg,
            isBodyweight: isBodyweight,
            // States written before this field existed contained completed sets.
            isPerformed: isPerformed ?? (reps > 0)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(weightKg, forKey: .weightKg)
        try container.encode(isBodyweight, forKey: .isBodyweight)
        try container.encode(isPerformed, forKey: .isPerformed)
    }

    private static func validatedWeight(_ weightKg: Double?, isBodyweight: Bool) -> Double? {
        guard !isBodyweight,
              let weightKg,
              weightKg.isFinite,
              weightKg > 0
        else { return nil }
        return weightKg
    }
}

/// An exercise inside a session. The catalog ID powers history queries, while
/// the name snapshot keeps old workouts readable if the bundled catalog changes.
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

    var recordedSets: [StrengthWorkoutSet] {
        sets.filter(\.isRecorded)
    }

    var hasRecordedSets: Bool {
        sets.contains(where: \.isRecorded)
    }
}

/// A workout is active while `completedAt` is nil and becomes immutable history
/// once completed. Only one active session is retained by the store.
struct StrengthWorkoutSession: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var startedAt: Date
    var completedAt: Date?
    var name: String?
    var exercises: [StrengthWorkoutExercise]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        name: String? = nil,
        exercises: [StrengthWorkoutExercise] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.name = Self.normalizedName(name)
        self.exercises = exercises
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var setCount: Int {
        exercises.reduce(0) { $0 + $1.recordedSets.count }
    }

    var exerciseCount: Int {
        exercises.filter(\.hasRecordedSets).count
    }

    var hasRecordedSets: Bool {
        exercises.contains(where: \.hasRecordedSets)
    }

    var duration: TimeInterval? {
        guard let completedAt else { return nil }
        let elapsed = completedAt.timeIntervalSince(startedAt)
        return elapsed > 0 ? elapsed : nil
    }

    static func normalizedName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

/// One occurrence of an exercise in completed workout history.
struct StrengthExerciseHistoryEntry: Identifiable, Equatable, Hashable {
    var id: UUID { exercise.id }

    let sessionID: UUID
    let startedAt: Date
    let completedAt: Date
    let sessionName: String?
    let exercise: StrengthWorkoutExercise
}

/// The only records the logger recognizes: most reps in a set and heaviest
/// explicit weighted set. It deliberately does not calculate volume or 1RM.
struct StrengthExercisePerformance: Equatable, Hashable {
    let bestReps: Int?
    let bestWeightKg: Double?

    init(sets: [StrengthWorkoutSet]) {
        let recordedSets = sets.filter(\.isRecorded)
        bestReps = recordedSets.map(\.reps).max()
        bestWeightKg = recordedSets
            .filter(\.isWeighted)
            .compactMap(\.weightKg)
            .max()
    }

    var hasRecordedValue: Bool {
        bestReps != nil || bestWeightKg != nil
    }
}

/// Compares a session with all completed performance that predates it. The
/// first log establishes a baseline; a PR is only claimed when a prior value
/// exists and is meaningfully exceeded.
struct StrengthPersonalRecordComparison: Equatable, Hashable {
    let current: StrengthExercisePerformance
    let previous: StrengthExercisePerformance?

    var repetitionChange: Int? {
        guard let current = current.bestReps,
              let previous = previous?.bestReps
        else { return nil }
        return current - previous
    }

    var weightChangeKg: Double? {
        guard let current = current.bestWeightKg,
              let previous = previous?.bestWeightKg
        else { return nil }
        return current - previous
    }

    var isRepetitionPR: Bool {
        guard let current = current.bestReps,
              let previous = previous?.bestReps
        else { return false }
        return current > previous
    }

    var isWeightPR: Bool {
        guard let current = current.bestWeightKg,
              let previous = previous?.bestWeightKg
        else { return false }
        return StrengthWorkoutWeight.isMeaningfullyGreater(current, than: previous)
    }

    var hasPersonalRecord: Bool {
        isRepetitionPR || isWeightPR
    }
}
