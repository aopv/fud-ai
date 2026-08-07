#if canImport(FoundationModels)
import Foundation
import FoundationModels

/// On-device food analysis using Apple Intelligence (iOS 26+, iPhone 15 Pro / iPhone 16+).
/// Last-resort text analysis fallback after the selected cloud provider and configured
/// fallback provider have failed.
@available(iOS 26.0, *)
struct OnDeviceFoodService {

    // MARK: - Structured output schema

    @Generable
    struct FoodResult {
        @Guide(description: "Short common name of the food or meal (e.g. 'Grilled chicken breast', 'Big Mac', 'Oatmeal with milk')")
        var name: String

        @Guide(description: "Total calories in kcal for the entire analyzed amount (integer)")
        var calories: Int

        @Guide(description: "Total protein in grams for the entire analyzed amount")
        var proteinGrams: Double

        @Guide(description: "Total carbohydrates in grams for the entire analyzed amount")
        var carbsGrams: Double

        @Guide(description: "Total fat in grams for the entire analyzed amount")
        var fatGrams: Double

        @Guide(description: "Total analyzed amount in grams (e.g. 150 for '150g chicken', 100 for '2 eggs')")
        var servingSizeGrams: Double

        @Guide(description: "Single food emoji that best represents this food (e.g. '🍗', '🥚', '🍔'). Empty string if no clear emoji.")
        var emoji: String

        @Guide(description: "Sugar content in grams. Use -1 if you cannot reliably estimate.")
        var sugarGrams: Double

        @Guide(description: "Dietary fiber in grams. Use -1 if you cannot reliably estimate.")
        var fiberGrams: Double

        @Guide(description: "Saturated fat in grams. Use -1 if you cannot reliably estimate.")
        var saturatedFatGrams: Double

        @Guide(description: "Sodium in milligrams. Use -1 if you cannot reliably estimate.")
        var sodiumMg: Double

        @Guide(description: "Natural serving unit label when a non-gram unit is obvious: 'piece' or 'slice' for discrete solids (pizza, cake, bread, egg, banana), 'cup' or 'ml' for liquids and volumes, 'tbsp' or 'tsp' for spooned condiments. Leave empty string when grams is the most natural unit.")
        var servingUnit: String

        @Guide(description: "How many servingUnits equal the entire analyzed amount (e.g. 2 if the user described 2 eggs). Use 0 when servingUnit is empty.")
        var servingUnitQuantity: Double

        @Guide(description: "Grams per one servingUnit (e.g. 50 if one egg weighs 50 g). Use 0 when servingUnit is empty.")
        var gramsPerUnit: Double
    }

    // MARK: - Availability

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    /// Returns false when the input contains scripts not supported by Apple Intelligence
    /// (e.g. Cyrillic, Arabic, Hebrew). Russian is not in the iOS 26.1 supported language list.
    static func canHandle(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            let value = scalar.value
            // Cyrillic: U+0400–U+04FF
            if value >= 0x0400 && value <= 0x04FF { return false }
            // Arabic: U+0600–U+06FF
            if value >= 0x0600 && value <= 0x06FF { return false }
            // Hebrew: U+0590–U+05FF
            if value >= 0x0590 && value <= 0x05FF { return false }
        }
        return true
    }

    // MARK: - Analysis

    static func analyzeTextInput(description: String) async throws -> GeminiService.FoodAnalysis {
        let session = LanguageModelSession(
            instructions: """
            You are a precise nutrition database. Given a food description in any language, \
            return accurate nutritional values using these rules:

            QUANTITY PARSING
            - Parse the quantity stated or clearly implied in the description.
            - "2 eggs" means 2 × ~50 g = 100 g total; calories and all nutrients must reflect the full amount.
            - "bowl of oatmeal" implies a typical 250 g cooked serving.
            - If no quantity is given, use the most common single serving.

            BRAND NAMES
            - When a brand or product name is mentioned (Big Mac, Chobani, Snickers, etc.), \
              use commonly known product values when you know them; otherwise estimate from \
              the closest generic food.

            MULTIPLE ITEMS
            - When multiple distinct foods are listed, sum all nutrients into a single total.

            ACCURACY
            - Use common nutrition reference values where known.
            - Calories must be mathematically consistent: ≈ protein×4 + carbs×4 + fat×9 (±5%).
            - serving_size_grams is the total weight of the entire analyzed amount.

            UNKNOWNS
            - Use -1 for sugar, fiber, saturated fat, or sodium when you cannot estimate reliably.

            SERVING UNIT
            - Provide a natural non-gram unit only when it is obvious from context.
            - Examples: slice for pizza/bread/cake, piece for fruit/cookie/egg, cup for oatmeal/soup, \
              tbsp for peanut butter/sauces.
            - Leave servingUnit empty ("") when grams is the clearest unit.
            """
        )

        let response = try await session.respond(
            to: "Provide nutrition data for: \(description)",
            generating: FoodResult.self
        )

        return buildFoodAnalysis(from: response.content)
    }

    // MARK: - Build FoodAnalysis from structured result

    private static func buildFoodAnalysis(from r: FoodResult) -> GeminiService.FoodAnalysis {
        let unitOptions: [ServingUnitOption]
        if !r.servingUnit.isEmpty && r.gramsPerUnit > 0 {
            unitOptions = [ServingUnitOption(
                unit: r.servingUnit,
                gramsPerUnit: r.gramsPerUnit,
                quantity: r.servingUnitQuantity > 0 ? r.servingUnitQuantity : nil
            )]
        } else {
            unitOptions = []
        }

        let selectedOption = unitOptions.first
        let emojiValue: String? = r.emoji.isEmpty ? nil : r.emoji

        return GeminiService.FoodAnalysis(
            name: r.name,
            calories: r.calories,
            protein: r.proteinGrams,
            carbs: r.carbsGrams,
            fat: r.fatGrams,
            servingSizeGrams: r.servingSizeGrams,
            emoji: emojiValue,
            sugar: r.sugarGrams >= 0 ? r.sugarGrams : nil,
            addedSugar: nil,
            fiber: r.fiberGrams >= 0 ? r.fiberGrams : nil,
            saturatedFat: r.saturatedFatGrams >= 0 ? r.saturatedFatGrams : nil,
            monounsaturatedFat: nil,
            polyunsaturatedFat: nil,
            cholesterol: nil,
            caffeine: nil,
            sodium: r.sodiumMg >= 0 ? r.sodiumMg : nil,
            potassium: nil,
            transFat: nil,
            calcium: nil,
            iron: nil,
            magnesium: nil,
            zinc: nil,
            vitaminA: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminB12: nil,
            vitaminE: nil,
            vitaminK: nil,
            folate: nil,
            omega3: nil,
            servingUnitOptions: unitOptions,
            selectedServingUnit: selectedOption?.unit,
            selectedServingQuantity: selectedOption.map { $0.quantity(for: r.servingSizeGrams) }
        )
    }
}
#endif
