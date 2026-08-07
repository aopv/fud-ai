import Foundation

enum SupplementalNutrient: String, CaseIterable, Identifiable, Codable {
    case creatine
    case betaAlanine
    case lCitrulline
    case lCarnitine
    case lArginine
    case taurine
    case betaine
    case hmb

    var id: String { rawValue }

    var jsonKey: String {
        switch self {
        case .creatine: "creatine"
        case .betaAlanine: "beta_alanine"
        case .lCitrulline: "l_citrulline"
        case .lCarnitine: "l_carnitine"
        case .lArginine: "l_arginine"
        case .taurine: "taurine"
        case .betaine: "betaine"
        case .hmb: "hmb"
        }
    }

    var displayName: String {
        switch self {
        case .creatine: "Creatine"
        case .betaAlanine: "Beta-Alanine"
        case .lCitrulline: "L-Citrulline"
        case .lCarnitine: "L-Carnitine"
        case .lArginine: "L-Arginine"
        case .taurine: "Taurine"
        case .betaine: "Betaine"
        case .hmb: "HMB"
        }
    }

    var optionalNutrient: OptionalNutrient {
        OptionalNutrient(rawValue: rawValue)!
    }
}
