import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable, Codable, Hashable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case fullBody = "Full Body"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.pullup"
        case .legs: return "figure.run"
        case .shoulders: return "figure.strengthtraining.functional"
        case .arms: return "dumbbell.fill"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.highintensity.intervaltraining"
        }
    }
}

enum Equipment: String, CaseIterable, Identifiable, Codable, Hashable {
    case dumbbells = "Dumbbells"
    case barbell = "Barbell"
    case cableMachine = "Cable Machine"
    case smithMachine = "Smith Machine"
    case bench = "Bench"
    case chestPress = "Chest Press"
    case shoulderPress = "Shoulder Press"
    case latPulldown = "Lat Pulldown"
    case rowMachine = "Row Machine"
    case legPress = "Leg Press"
    case legExtension = "Leg Extension"
    case legCurl = "Leg Curl"
    case pullUpBar = "Pull-up Bar"
    case treadmill = "Treadmill"
    case bodyweight = "Bodyweight"

    var id: String { rawValue }
    var title: String { rawValue }

    var icon: String {
        switch self {
        case .dumbbells: return "dumbbell.fill"
        case .barbell: return "scalemass.fill"
        case .cableMachine: return "point.3.connected.trianglepath.dotted"
        case .smithMachine: return "rectangle.connected.to.line.below"
        case .bench: return "rectangle.and.hand.point.up.left"
        case .chestPress: return "figure.strengthtraining.traditional"
        case .shoulderPress: return "figure.strengthtraining.functional"
        case .latPulldown: return "figure.pullup"
        case .rowMachine: return "figure.rower"
        case .legPress: return "figure.run"
        case .legExtension: return "figure.kickboxing"
        case .legCurl: return "figure.flexibility"
        case .pullUpBar: return "figure.pullup"
        case .treadmill: return "figure.run.treadmill"
        case .bodyweight: return "figure.cooldown"
        }
    }
}
