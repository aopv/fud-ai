import SwiftUI

enum MuscleGlyphAsset {
    static func name(title: String, muscles: Set<String>) -> String {
        MuscleGlyphKind(title: title, muscles: muscles).assetName
    }
}

private enum MuscleGlyphKind {
    case abs
    case abductors
    case adductors
    case biceps
    case triceps
    case forearms
    case calves
    case chest
    case glutes
    case hamstrings
    case lats
    case lowerBack
    case middleBack
    case neck
    case quadriceps
    case shoulders
    case traps
    case groupUpper
    case groupLower
    case groupPush
    case groupPull
    case groupLegs
    case groupArms
    case groupBack
    case generic

    var assetName: String {
        switch self {
        case .abs:
            return "muscle_icon_abs"
        case .abductors:
            return "muscle_icon_abductors"
        case .adductors:
            return "muscle_icon_adductors"
        case .biceps:
            return "muscle_icon_biceps"
        case .triceps:
            return "muscle_icon_triceps"
        case .forearms:
            return "muscle_icon_forearms"
        case .calves:
            return "muscle_icon_calves"
        case .chest:
            return "muscle_icon_chest"
        case .glutes:
            return "muscle_icon_glutes"
        case .hamstrings:
            return "muscle_icon_hamstrings"
        case .lats:
            return "muscle_icon_lats"
        case .lowerBack:
            return "muscle_icon_lower_back"
        case .middleBack:
            return "muscle_icon_middle_back"
        case .neck:
            return "muscle_icon_neck"
        case .quadriceps:
            return "muscle_icon_quadriceps"
        case .shoulders:
            return "muscle_icon_shoulders"
        case .traps:
            return "muscle_icon_traps"
        case .groupUpper:
            return "muscle_icon_group_upper"
        case .groupLower:
            return "muscle_icon_group_lower"
        case .groupPush:
            return "muscle_icon_group_push"
        case .groupPull:
            return "muscle_icon_group_pull"
        case .groupLegs:
            return "muscle_icon_group_legs"
        case .groupArms:
            return "muscle_icon_group_arms"
        case .groupBack:
            return "muscle_icon_group_back"
        case .generic:
            return "muscle_icon_generic"
        }
    }

    init(title: String, muscles: Set<String>) {
        let normalizedTitle = title.lowercased()

        if muscles.count == 1, let muscle = muscles.first {
            self = MuscleGlyphKind(muscleName: muscle)
            return
        }

        if normalizedTitle.contains("push") {
            self = .groupPush
        } else if normalizedTitle.contains("pull") {
            self = .groupPull
        } else if normalizedTitle.contains("upper") {
            self = .groupUpper
        } else if normalizedTitle.contains("lower") || normalizedTitle.contains("leg") || normalizedTitle.contains("quad") || normalizedTitle.contains("hamstring") {
            self = .groupLower
        } else if normalizedTitle.contains("core") || normalizedTitle.contains("ab") {
            self = .abs
        } else if normalizedTitle.contains("arm") || normalizedTitle.contains("bicep") || normalizedTitle.contains("tricep") {
            self = .groupArms
        } else if normalizedTitle.contains("back") || normalizedTitle.contains("lat") || normalizedTitle.contains("trap") {
            self = .groupBack
        } else if normalizedTitle.contains("chest") {
            self = .chest
        } else if normalizedTitle.contains("shoulder") {
            self = .shoulders
        } else {
            self = MuscleGlyphKind(muscleName: title)
        }
    }

    private init(muscleName: String) {
        switch muscleName.lowercased() {
        case "abdominals":
            self = .abs
        case "abductors":
            self = .abductors
        case "adductors":
            self = .adductors
        case "biceps":
            self = .biceps
        case "triceps":
            self = .triceps
        case "forearms":
            self = .forearms
        case "calves":
            self = .calves
        case "chest":
            self = .chest
        case "glutes":
            self = .glutes
        case "hamstrings":
            self = .hamstrings
        case "lats":
            self = .lats
        case "lower back":
            self = .lowerBack
        case "middle back":
            self = .middleBack
        case "neck":
            self = .neck
        case "quadriceps":
            self = .quadriceps
        case "shoulders":
            self = .shoulders
        case "traps":
            self = .traps
        default:
            self = .generic
        }
    }
}
