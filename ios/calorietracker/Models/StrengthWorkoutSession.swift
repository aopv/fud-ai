import Foundation

/// Feature-level settings for the optional iOS workout diary.
enum StrengthWorkoutSettings {
    /// Deliberately new: previously-reverted experimental builds used a different key.
    static let enabledKey = "fudai.workouts.diary.enabled.v1"
}

enum StrengthWorkoutDate {
    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static func date(for key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

enum StrengthWorkoutRPEScale: String, Codable, CaseIterable, Identifiable {
    case strength
    case cr10
    case borg

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: return "Strength 1–10"
        case .cr10: return "CR10 0–10"
        case .borg: return "Borg 6–20"
        }
    }

    var subtitle: String {
        switch self {
        case .strength: return "1–10 effort, with 10 as maximum"
        case .cr10: return "0–10 perceived exertion, decimals allowed"
        case .borg: return "6–20 perceived exertion, whole numbers"
        }
    }

    var shortTitle: String {
        switch self {
        case .strength: return "1–10"
        case .cr10: return "CR10"
        case .borg: return "Borg"
        }
    }

    var inputPlaceholder: String {
        switch self {
        case .strength: return "1–10"
        case .cr10: return "0–10"
        case .borg: return "6–20"
        }
    }

    var allowsDecimalInput: Bool { self != .borg }

    var inputRange: ClosedRange<Double> {
        switch self {
        case .strength: return 1...10
        case .cr10: return 0...10
        case .borg: return 6...20
        }
    }

    /// Keeps valid in-progress input such as `7.` so decimal RPE values remain
    /// typeable. This matches the final Delts diary behavior.
    func sanitized(_ proposedValue: String, previousValue: String = "") -> String {
        let normalized = proposedValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return "" }

        var filtered = ""
        var hasDecimal = false
        var fractionalDigits = 0
        for character in normalized {
            if character.isNumber {
                if hasDecimal {
                    guard allowsDecimalInput, fractionalDigits < 1 else { continue }
                    fractionalDigits += 1
                }
                filtered.append(character)
            } else if character == ".", allowsDecimalInput, !hasDecimal, !filtered.isEmpty {
                hasDecimal = true
                filtered.append(character)
            }
        }
        guard !filtered.isEmpty else { return previousValue }

        let numericText = filtered.hasSuffix(".") ? String(filtered.dropLast()) : filtered
        guard let value = Double(numericText) else { return previousValue }
        if value > inputRange.upperBound { return String(Int(inputRange.upperBound)) }
        if value < inputRange.lowerBound, !isPossibleRangePrefix(filtered) { return previousValue }
        return filtered
    }

    private func isPossibleRangePrefix(_ value: String) -> Bool {
        let integerPrefix = value.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? value
        guard !integerPrefix.isEmpty else { return false }
        let lower = Int(inputRange.lowerBound.rounded(.up))
        let upper = Int(inputRange.upperBound.rounded(.down))
        return (lower...upper).contains { String($0).hasPrefix(integerPrefix) }
    }
}

enum StrengthWorkoutSplit: String, Codable, CaseIterable, Identifiable {
    case pushPullLegs
    case upperLower
    case broSplit
    case arnold
    case pushPull
    case antagonistSplit
    case hybridSplit
    case fullBody
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pushPullLegs: return "Push / Pull / Legs"
        case .upperLower: return "Upper / Lower"
        case .broSplit: return "Body-part split"
        case .arnold: return "Arnold split"
        case .pushPull: return "Push / Pull"
        case .antagonistSplit: return "Antagonist split"
        case .hybridSplit: return "Hybrid split"
        case .fullBody: return "Full body"
        case .custom: return "Custom"
        }
    }
}

enum StrengthWorkoutDuration: Int, Codable, CaseIterable, Identifiable {
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    case seventyFive = 75
    case ninety = 90

    var id: Int { rawValue }
    var title: String { "\(rawValue) min" }
}

enum StrengthWorkoutIssue: String, Codable, CaseIterable, Identifiable {
    case shoulder = "Shoulder"
    case elbow = "Elbow"
    case wrist = "Wrist"
    case lowerBack = "Lower back"
    case hip = "Hip"
    case knee = "Knee"
    case ankle = "Ankle"
    case other = "Other"

    var id: String { rawValue }
}

struct StrengthWorkoutNumbers: Codable, Equatable {
    var benchPressKg: Double?
    var squatKg: Double?
    var deadliftKg: Double?
    var overheadPressKg: Double?
}

struct StrengthWorkoutPreferences: Codable, Equatable {
    var targetMuscles: Set<String> = []
    var issues: Set<StrengthWorkoutIssue> = []
    var additionalIssues = ""
    var frequencyDays = 3
    var duration: StrengthWorkoutDuration = .sixty
    var split: StrengthWorkoutSplit = .pushPullLegs
    var customSplit = ""
    var equipment: Set<String> = []
    var rpeScale: StrengthWorkoutRPEScale = .strength
    var strength = StrengthWorkoutNumbers()

    mutating func sanitize() {
        frequencyDays = min(max(frequencyDays, 1), 7)
        additionalIssues = additionalIssues.trimmingCharacters(in: .whitespacesAndNewlines)
        customSplit = customSplit.trimmingCharacters(in: .whitespacesAndNewlines)
        if !issues.contains(.other) { additionalIssues = "" }
        if split != .custom { customSplit = "" }
        strength.benchPressKg = Self.validLoad(strength.benchPressKg)
        strength.squatKg = Self.validLoad(strength.squatKg)
        strength.deadliftKg = Self.validLoad(strength.deadliftKg)
        strength.overheadPressKg = Self.validLoad(strength.overheadPressKg)
    }

    private static func validLoad(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }
}

struct StrengthPlannedSet: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var weight = ""
    /// The unit used when this load was entered. Optional for compatibility
    /// with the first diary build, before planned loads carried their unit.
    var weightUnit: String?
    var reps = ""
    var rpe = ""
    /// RPE values are meaningful only together with their selected scale.
    var rpeScale: StrengthWorkoutRPEScale?

    var hasLoggedValue: Bool {
        !weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !rpe.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func blankCopy(carryingWeight: Bool) -> StrengthPlannedSet {
        StrengthPlannedSet(
            weight: carryingWeight ? weight : "",
            weightUnit: carryingWeight ? weightUnit : nil
        )
    }
}

struct StrengthPlannedExercise: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    let itemID: String
    var name: String
    var rawLevel: String
    var imagePaths: [String]
    var force: String
    var mechanic: String
    var category: String
    var rawEquipment: String
    var primaryMuscles: [String]
    var secondaryMuscles: [String]
    var instructions: [String]
    var sets: [StrengthPlannedSet]

    init(item: ExerciseLibraryItem) {
        itemID = item.id
        name = item.name
        rawLevel = item.rawLevel
        imagePaths = item.imagePaths
        force = item.force
        mechanic = item.mechanic
        category = item.category
        rawEquipment = item.rawEquipment
        primaryMuscles = item.primaryMuscles
        secondaryMuscles = item.secondaryMuscles
        instructions = item.instructions
        sets = [StrengthPlannedSet()]
    }

    var libraryItem: ExerciseLibraryItem {
        ExerciseLibraryItem(
            id: itemID,
            name: name,
            rawLevel: rawLevel,
            imagePaths: imagePaths,
            force: force,
            mechanic: mechanic,
            category: category,
            rawEquipment: rawEquipment,
            primaryMuscles: primaryMuscles,
            secondaryMuscles: secondaryMuscles,
            instructions: instructions
        )
    }

    func copiedForNewDay() -> StrengthPlannedExercise {
        var copy = self
        copy.id = UUID()
        copy.sets = [StrengthPlannedSet()]
        return copy
    }
}

struct StrengthWorkoutDayPlan: Identifiable, Codable, Equatable {
    var id: String { dateKey }
    let dateKey: String
    var exercises: [StrengthPlannedExercise] = []
}

struct StrengthCompletedSet: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    let setNumber: Int
    let weight: String
    let weightUnit: String
    let reps: String
    let rpe: String
    /// Optional so version-one workout records continue to decode.
    var rpeScale: StrengthWorkoutRPEScale?

    var isPerformed: Bool {
        // Delts treats a set as performed once reps are entered; a load or RPE
        // by itself remains a planned/incomplete set.
        !reps.isEmpty
    }
}

struct StrengthCompletedExercise: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    let itemID: String
    let name: String
    let targetMuscles: [String]
    let equipment: String
    let sets: [StrengthCompletedSet]
}

struct StrengthWorkoutSession: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    let diaryDate: Date
    /// A stable calendar-day identity that does not move when the user changes
    /// time zones. Optional so records from the first diary build still load.
    var diaryDateKey: String? = nil
    let startedAt: Date
    let completedAt: Date
    let durationSeconds: Int
    let exercises: [StrengthCompletedExercise]

    var durationMinutes: Int { max(1, Int(ceil(Double(durationSeconds) / 60))) }
    var exerciseCount: Int { exercises.count }
    var performedSetCount: Int { exercises.flatMap(\.sets).filter(\.isPerformed).count }
    var repCount: Int {
        exercises.flatMap(\.sets).reduce(0) { $0 + (Int($1.reps) ?? 0) }
    }

    var stableDiaryDateKey: String {
        diaryDateKey ?? StrengthWorkoutDate.key(for: diaryDate)
    }

    var calendarDiaryDate: Date {
        StrengthWorkoutDate.date(for: stableDiaryDateKey) ?? diaryDate
    }

    var displayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(calendarDiaryDate) { return "Today Workout" }
        return "\(calendarDiaryDate.formatted(.dateTime.weekday(.wide))) Workout"
    }
}

struct StrengthWorkoutSplitGroup: Identifiable, Hashable {
    let title: String
    let muscles: Set<String>
    var id: String { title }

    static func groups(for split: StrengthWorkoutSplit, availableMuscles: [String]) -> [StrengthWorkoutSplitGroup] {
        func matching(_ candidates: [String]) -> Set<String> {
            let lowered = Dictionary(uniqueKeysWithValues: availableMuscles.map { ($0.lowercased(), $0) })
            return Set(candidates.compactMap { lowered[$0.lowercased()] })
        }

        switch split {
        case .pushPullLegs:
            return [
                .init(title: "Push", muscles: matching(["Chest", "Shoulders", "Triceps"])),
                .init(title: "Pull", muscles: matching(["Biceps", "Forearms", "Lats", "Middle Back", "Traps", "Neck"])),
                .init(title: "Legs", muscles: matching(["Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Lower Back", "Quadriceps"])),
                .init(title: "Core", muscles: matching(["Abdominals"]))
            ]
        case .upperLower:
            return [
                .init(title: "Upper", muscles: matching(["Biceps", "Chest", "Forearms", "Lats", "Middle Back", "Neck", "Shoulders", "Traps", "Triceps"])),
                .init(title: "Lower", muscles: matching(["Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Lower Back", "Quadriceps"])),
                .init(title: "Core", muscles: matching(["Abdominals"]))
            ]
        case .broSplit:
            return [
                .init(title: "Chest", muscles: matching(["Chest"])),
                .init(title: "Back", muscles: matching(["Lats", "Middle Back", "Lower Back", "Traps"])),
                .init(title: "Shoulders", muscles: matching(["Shoulders", "Traps"])),
                .init(title: "Arms", muscles: matching(["Biceps", "Triceps", "Forearms"])),
                .init(title: "Legs", muscles: matching(["Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Quadriceps"])),
                .init(title: "Core", muscles: matching(["Abdominals"]))
            ]
        case .arnold:
            return [
                .init(title: "Chest + Back", muscles: matching(["Chest", "Lats", "Middle Back", "Lower Back", "Traps"])),
                .init(title: "Shoulders + Arms", muscles: matching(["Shoulders", "Biceps", "Triceps", "Forearms", "Neck"])),
                .init(title: "Legs", muscles: matching(["Abductors", "Adductors", "Calves", "Glutes", "Hamstrings", "Quadriceps"])),
                .init(title: "Core", muscles: matching(["Abdominals"]))
            ]
        case .pushPull:
            return [
                .init(title: "Push", muscles: matching(["Chest", "Shoulders", "Triceps", "Quadriceps", "Calves"])),
                .init(title: "Pull", muscles: matching(["Biceps", "Forearms", "Lats", "Middle Back", "Traps", "Glutes", "Hamstrings", "Lower Back"])),
                .init(title: "Accessory/Core", muscles: matching(["Abdominals", "Abductors", "Adductors", "Neck"]))
            ]
        case .antagonistSplit:
            return [
                .init(title: "Chest + Back", muscles: matching(["Chest", "Lats", "Middle Back", "Lower Back", "Traps"])),
                .init(title: "Biceps + Triceps", muscles: matching(["Biceps", "Triceps", "Forearms"])),
                .init(title: "Quads + Hamstrings/Glutes", muscles: matching(["Quadriceps", "Hamstrings", "Glutes"])),
                .init(title: "Shoulders + Lats/Traps", muscles: matching(["Shoulders", "Lats", "Traps"])),
                .init(title: "Core/Accessory", muscles: matching(["Abdominals", "Abductors", "Adductors", "Calves", "Neck"]))
            ]
        case .hybridSplit:
            return [
                .init(title: "Strength/Compound", muscles: matching(["Chest", "Lats", "Middle Back", "Lower Back", "Glutes", "Hamstrings", "Quadriceps", "Shoulders", "Traps"])),
                .init(title: "Accessory/Hypertrophy", muscles: matching(["Biceps", "Triceps", "Forearms", "Calves", "Abductors", "Adductors", "Abdominals", "Neck"]))
            ]
        case .fullBody, .custom:
            return []
        }
    }
}
