import Foundation

/// Product-label details supplied by Open Food Facts for a barcode lookup.
/// Nutrition remains on `FoodEntry`; this type keeps optional product metadata
/// separate so legacy and non-barcode food logs stay lightweight.
struct FoodProductMetadata: Codable, Equatable, Sendable {
    var barcode: String
    var packageQuantity: String?
    var ingredientsText: String?
    var allergens: [String]
    var traces: [String]
    var nutriScore: String?
    var novaGroup: Int?
    var ecoScore: String?
    var labels: [String]
    var categories: [String]
    var imageURL: URL?

    var hasDisplayDetails: Bool {
        !barcode.isEmpty
            || packageQuantity != nil
            || ingredientsText != nil
            || !allergens.isEmpty
            || !traces.isEmpty
            || nutriScore != nil
            || novaGroup != nil
            || ecoScore != nil
            || !labels.isEmpty
            || !categories.isEmpty
    }
}
