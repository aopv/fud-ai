import Foundation
import UIKit

struct GeminiService {
    struct FoodAnalysis {
        var name: String
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double
        var servingSizeGrams: Double
        var emoji: String?
        var sugar: Double?
        var addedSugar: Double?
        var fiber: Double?
        var saturatedFat: Double?
        var monounsaturatedFat: Double?
        var polyunsaturatedFat: Double?
        var cholesterol: Double?
        var sodium: Double?
        var potassium: Double?
        var transFat: Double?
        var calcium: Double?
        var iron: Double?
        var magnesium: Double?
        var zinc: Double?
        var vitaminA: Double?
        var vitaminC: Double?
        var vitaminD: Double?
        var vitaminB12: Double?
        var vitaminE: Double?
        var vitaminK: Double?
        var folate: Double?
        var omega3: Double?
        var servingUnitOptions: [ServingUnitOption] = []
        var selectedServingUnit: String?
        var selectedServingQuantity: Double?
    }

    struct NutritionLabelAnalysis {
        var name: String
        var caloriesPer100g: Double
        var proteinPer100g: Double
        var carbsPer100g: Double
        var fatPer100g: Double
        var servingSizeGrams: Double?
        var sugarPer100g: Double?
        var addedSugarPer100g: Double?
        var fiberPer100g: Double?
        var saturatedFatPer100g: Double?
        var monounsaturatedFatPer100g: Double?
        var polyunsaturatedFatPer100g: Double?
        var cholesterolPer100g: Double?
        var sodiumPer100g: Double?
        var potassiumPer100g: Double?
        var transFatPer100g: Double?
        var calciumPer100g: Double?
        var ironPer100g: Double?
        var magnesiumPer100g: Double?
        var zincPer100g: Double?
        var vitaminAPer100g: Double?
        var vitaminCPer100g: Double?
        var vitaminDPer100g: Double?
        var vitaminB12Per100g: Double?
        var vitaminEPer100g: Double?
        var vitaminKPer100g: Double?
        var folatePer100g: Double?
        var omega3Per100g: Double?
        var servingUnitOptions: [ServingUnitOption] = []

        func scaled(to grams: Double) -> FoodAnalysis {
            let selectedOption = servingUnitOptions.first
            let scale = grams / 100
            return FoodAnalysis(
                name: name,
                calories: Int(round(caloriesPer100g * scale)),
                protein: proteinPer100g * scale,
                carbs: carbsPer100g * scale,
                fat: fatPer100g * scale,
                servingSizeGrams: grams,
                sugar: sugarPer100g.map { round($0 * scale * 10) / 10 },
                addedSugar: addedSugarPer100g.map { round($0 * scale * 10) / 10 },
                fiber: fiberPer100g.map { round($0 * scale * 10) / 10 },
                saturatedFat: saturatedFatPer100g.map { round($0 * scale * 10) / 10 },
                monounsaturatedFat: monounsaturatedFatPer100g.map { round($0 * scale * 10) / 10 },
                polyunsaturatedFat: polyunsaturatedFatPer100g.map { round($0 * scale * 10) / 10 },
                cholesterol: cholesterolPer100g.map { round($0 * scale * 10) / 10 },
                sodium: sodiumPer100g.map { round($0 * scale * 10) / 10 },
                potassium: potassiumPer100g.map { round($0 * scale * 10) / 10 },
                transFat: transFatPer100g.map { round($0 * scale * 10) / 10 },
                calcium: calciumPer100g.map { round($0 * scale * 10) / 10 },
                iron: ironPer100g.map { round($0 * scale * 10) / 10 },
                magnesium: magnesiumPer100g.map { round($0 * scale * 10) / 10 },
                zinc: zincPer100g.map { round($0 * scale * 10) / 10 },
                vitaminA: vitaminAPer100g.map { round($0 * scale * 10) / 10 },
                vitaminC: vitaminCPer100g.map { round($0 * scale * 10) / 10 },
                vitaminD: vitaminDPer100g.map { round($0 * scale * 10) / 10 },
                vitaminB12: vitaminB12Per100g.map { round($0 * scale * 10) / 10 },
                vitaminE: vitaminEPer100g.map { round($0 * scale * 10) / 10 },
                vitaminK: vitaminKPer100g.map { round($0 * scale * 10) / 10 },
                folate: folatePer100g.map { round($0 * scale * 10) / 10 },
                omega3: omega3Per100g.map { round($0 * scale * 10) / 10 },
                servingUnitOptions: servingUnitOptions,
                selectedServingUnit: selectedOption?.unit,
                selectedServingQuantity: selectedOption?.quantity(for: grams)
            )
        }
    }

    struct HealthEnergyGoalSuggestion {
        var calories: Int
        var reason: String?
    }

    private struct MacroTotals {
        var calories: Int
        var protein: Double
        var carbs: Double
        var fat: Double

        static let zero = MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)

        static func + (lhs: MacroTotals, rhs: MacroTotals) -> MacroTotals {
            MacroTotals(
                calories: lhs.calories + rhs.calories,
                protein: lhs.protein + rhs.protein,
                carbs: lhs.carbs + rhs.carbs,
                fat: lhs.fat + rhs.fat
            )
        }
    }

    enum AnalysisError: LocalizedError {
        case noAPIKey
        case imageConversionFailed
        case networkError(Error)
        case invalidResponse
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "No API key configured. Add your key in Settings → AI Provider."
            case .imageConversionFailed:
                return "Failed to process the image."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Could not understand the AI response. Please try again."
            case .apiError(let message):
                return "API error: \(message)"
            }
        }
    }

    private static let foodAnalysisJSONShape = """
    {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"emoji":"🍽️","sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"trans_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
    """

    private static let foodAnalysisJSONShapeWithoutEmoji = """
    {"name":"...","calories":0,"protein":0.0,"carbs":0.0,"fat":0.0,"serving_size_grams":0.0,"sugar":0.0,"added_sugar":0.0,"fiber":0.0,"saturated_fat":0.0,"monounsaturated_fat":0.0,"polyunsaturated_fat":0.0,"trans_fat":0.0,"cholesterol":0.0,"sodium":0.0,"potassium":0.0,"calcium":0.0,"iron":0.0,"magnesium":0.0,"zinc":0.0,"vitamin_a":0.0,"vitamin_c":0.0,"vitamin_d":0.0,"vitamin_b12":0.0,"vitamin_e":0.0,"vitamin_k":0.0,"folate":0.0,"omega_3":0.0,"unit_options":[]}
    """

    private static let nutritionLabelJSONShape = """
    {"name":"Product Name","calories_per_100g":0.0,"protein_per_100g":0.0,"carbs_per_100g":0.0,"fat_per_100g":0.0,"serving_size_grams":0.0,"sugar_per_100g":0.0,"added_sugar_per_100g":0.0,"fiber_per_100g":0.0,"saturated_fat_per_100g":0.0,"monounsaturated_fat_per_100g":0.0,"polyunsaturated_fat_per_100g":0.0,"trans_fat_per_100g":0.0,"cholesterol_per_100g":0.0,"sodium_per_100g":0.0,"potassium_per_100g":0.0,"calcium_per_100g":0.0,"iron_per_100g":0.0,"magnesium_per_100g":0.0,"zinc_per_100g":0.0,"vitamin_a_per_100g":0.0,"vitamin_c_per_100g":0.0,"vitamin_d_per_100g":0.0,"vitamin_b12_per_100g":0.0,"vitamin_e_per_100g":0.0,"vitamin_k_per_100g":0.0,"folate_per_100g":0.0,"omega_3_per_100g":0.0,"unit_options":[]}
    """

    private static let nutrientUnitsInstruction = "Calories are integers. Protein/carbs/fat are decimal gram values when needed. serving_size_grams is the estimated weight in grams. Nutrients are numbers: sugar/fiber/fats/omega_3 in grams; cholesterol/sodium/potassium/calcium/iron/magnesium/zinc/vitamin_c/vitamin_e in milligrams; vitamin_a/vitamin_d/vitamin_b12/vitamin_k/folate in micrograms."

    // MARK: - Public API (unchanged interface)

    static func suggestMealWhatIf(
        entry: FoodEntry,
        dayEntries: [FoodEntry],
        profile: UserProfile,
        useMetric: Bool
    ) async throws -> String {
        let current = macroTotals(for: dayEntries)
        let meal = macroTotals(for: entry)
        let after = current + meal
        let goals = MacroTotals(
            calories: profile.effectiveCalories,
            protein: Double(profile.effectiveProtein),
            carbs: Double(profile.effectiveCarbs),
            fat: Double(profile.effectiveFat)
        )
        let remaining = MacroTotals(
            calories: goals.calories - after.calories,
            protein: goals.protein - after.protein,
            carbs: goals.carbs - after.carbs,
            fat: goals.fat - after.fat
        )
        let existingMeals = dayEntries.isEmpty
            ? "No meals logged yet for this day."
            : dayEntries
                .prefix(12)
                .map { "- \($0.name): \($0.calories) kcal, \(formatGrams($0.protein))g protein, \(formatGrams($0.carbs))g carbs, \(formatGrams($0.fat))g fat" }
                .joined(separator: "\n")
        let weight = useMetric
            ? String(format: "%.1f kg", profile.weightKg)
            : String(format: "%.1f lb", profile.weightKg * 2.20462)
        let bodyFat = profile.bodyFatPercentage.map { "\(Int(($0 * 100).rounded()))%" } ?? "not set"

        let prompt = """
        You are a concise nutrition coach inside Fud AI. The user is reviewing a meal before logging it.
        Analyze this what-if scenario only. Do not say the meal has already been logged. Do not change the user's goals.

        Return 2-4 short plain-English sentences, no markdown and no bullets.
        Say whether logging this meal as-is fits the remaining daily targets. If it does not fit well, suggest one practical action: reduce quantity, replace an item, add a protein/fiber source, or balance the next meal. Be specific with calories/macros from the data below.

        User:
        - Goal: \(profile.goal.displayName)
        - Activity: \(profile.activityLevel.displayName)
        - Weight: \(weight)
        - Body fat: \(bodyFat)

        Daily targets:
        \(macroLine(goals))

        Already logged today:
        \(macroLine(current))

        Meal being reviewed:
        - \(entry.name): \(macroLine(meal))

        If logged, daily total becomes:
        \(macroLine(after))

        Remaining after logging (negative means over target):
        \(macroLine(remaining))

        Existing meals today:
        \(existingMeals)
        """

        let text = try await callAI(prompt: prompt, image: nil)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func analyzeTextInput(description: String) async throws -> FoodAnalysis {
        // Fast path: on-device model (iOS 26+, Apple Intelligence devices).
        // Instant, offline, no quota consumed. Falls through on unsupported hardware.
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if let onDevice = await OnDeviceAIService.analyzeText(description) {
                return await addingFallbackServingUnits(to: onDevice, image: nil, description: description)
            }
        }
        #endif

        let prompt = """
        Estimate the nutritional content for: \(description)
        Parse any quantities, brands, and multiple items from the text. If a brand is mentioned, use that brand's known nutritional data. If multiple items are described, sum up the total nutrition.
        Respond ONLY with JSON:
        \(Self.foodAnalysisJSONShape)
        \(Self.nutrientUnitsInstruction)
        The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
        unit_options is required when the text names an obvious non-gram serving unit, and optional otherwise. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. Do not copy any sample number; use the quantity stated or clearly implied by the meal. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
        Include a single food emoji that best represents the food. Use null for any nutrient you cannot estimate.
        """
        let text = try await callAI(prompt: prompt, image: nil)
        let analysis = try parseFoodAnalysis(from: text)
        return await addingFallbackServingUnits(to: analysis, image: nil, description: description)
    }

    static func autoAnalyze(image: UIImage) async throws -> FoodAnalysis {
        let prompt = """
        Analyze this image. It could be either a photo of food OR a nutrition facts label.

        If it's a food photo: identify the food and estimate nutritional content for the serving shown.
        If it's a nutrition label: read the values and calculate for one serving size as listed on the label.

        Respond ONLY with JSON:
        \(Self.foodAnalysisJSONShapeWithoutEmoji)
        \(Self.nutrientUnitsInstruction)
        The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
        unit_options is required for obvious non-gram units visible in the image or label. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. For a whole or mostly-whole divisible food like cake, pie, or pizza, count the visible pieces/slices and derive grams_per_unit from serving_size_grams / quantity. If N slices are visible, return quantity N. Use quantity 1 only when a single piece/slice is actually the analyzed portion. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
        Use null for any nutrient you cannot estimate.
        """
        let text = try await callAI(prompt: prompt, image: image)
        let analysis = try parseFoodAnalysis(from: text)
        return await addingFallbackServingUnits(to: analysis, image: image, description: nil)
    }

    static func analyzeFood(image: UIImage, description: String? = nil) async throws -> FoodAnalysis {
        var prompt = """
        Analyze this food image. Identify the food and estimate its nutritional content.

        Respond ONLY with a JSON object in this exact format, no other text:
        \(Self.foodAnalysisJSONShapeWithoutEmoji)

        \(Self.nutrientUnitsInstruction)
        The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
        unit_options is required for obvious non-gram units visible in the food. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet when packaged. Its quantity must describe the whole analyzed amount, not always 1. For a whole or mostly-whole divisible food like cake, pie, or pizza, count the visible pieces/slices and derive grams_per_unit from serving_size_grams / quantity. If N slices are visible, return quantity N. Use quantity 1 only when a single piece/slice is actually the analyzed portion. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
        Give your best estimate for the visible food amount shown in the image. For whole/mostly-whole cakes, pizzas, pies, loaves, or similar foods, estimate the total visible item/remaining item weight rather than defaulting to one slice. Use null for any nutrient you cannot estimate.
        """

        if let description, !description.trimmingCharacters(in: .whitespaces).isEmpty {
            prompt += "\n\nAdditional context from the user about this meal: \(description)\nUse this context to improve accuracy of identification, portion size, and nutrition estimates."
        }

        let text = try await callAI(prompt: prompt, image: image)
        let analysis = try parseFoodAnalysis(from: text)
        return await addingFallbackServingUnits(to: analysis, image: image, description: description)
    }

    static func analyzeFood(images: [UIImage]) async throws -> FoodAnalysis {
        guard !images.isEmpty else { throw AnalysisError.imageConversionFailed }

        let prompt = """
        Analyze these food-related images together. They may show the food/package from one angle and the nutrition facts label or another useful angle from another photo.

        Use all images as one logging request. If a nutrition label is visible, prefer the label values for packaged foods and combine that with the visible serving/package context from the other image. If no label is visible, estimate the visible food amount from the photos.

        Respond ONLY with a JSON object in this exact format, no other text:
        \(Self.foodAnalysisJSONShapeWithoutEmoji)

        \(Self.nutrientUnitsInstruction)
        The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is obvious.
        unit_options is required for obvious non-gram units visible in the food or label. Use slice/piece for pizza, cake, bread, cookies, fruit pieces, etc.; use ml/cup/fl oz for drinks, milk, soup, smoothies, sauces, etc.; use tbsp/tsp for spooned foods; use can/packet/bar when packaged. Its quantity must describe the whole analyzed amount, not always 1. Use [] only when no non-gram unit is apparent. Do not include g/grams in unit_options.
        Give your best estimate for the actual amount shown or implied across the images. Use null for any nutrient you cannot estimate.
        """

        let text = try await callAI(prompt: prompt, images: images)
        let analysis = try parseFoodAnalysis(from: text)
        return await addingFallbackServingUnits(to: analysis, image: images[0], description: nil)
    }

    static func analyzeNutritionLabel(image: UIImage) async throws -> NutritionLabelAnalysis {
        let prompt = """
        Read this nutrition label image. Extract the nutritional values per 100g (or per 100ml).
        If the label shows per-serving values, convert them to per-100g using the serving size.

        For the name, identify the product or brand name visible on the packaging or label.
        If no name is visible, describe the food type (e.g. "Protein Bar", "Yogurt", "Cereal").

        Respond ONLY with JSON:
        \(Self.nutritionLabelJSONShape)

        The [] in unit_options above is only a JSON shape placeholder; replace it with options when a non-gram unit is visible.
        All values should be numbers. If serving size or any nutrient is not available, use null. unit_options is required when a non-gram label serving unit is visible, such as slice, piece, tbsp, cup, ml, fl oz, can, or packet. Do not copy any sample number; use the quantity shown on the label. Use [] only when no non-gram unit is visible. Do not include g/grams in unit_options.
        """
        let text = try await callAI(prompt: prompt, image: image)
        let analysis = try parseNutritionLabel(from: text)
        return await addingFallbackServingUnits(to: analysis, image: image)
    }

    static func suggestOptionalNutrientGoals(
        profile: UserProfile,
        currentGoals: OptionalNutrientGoals,
        useMetric: Bool
    ) async throws -> OptionalNutrientGoals {
        let weight = useMetric
            ? String(format: "%.1f kg", profile.weightKg)
            : String(format: "%.1f lb", profile.weightKg * 2.20462)
        let height = useMetric
            ? String(format: "%.0f cm", profile.heightCm)
            : String(format: "%.1f in", profile.heightCm / 2.54)
        let bodyFat = profile.bodyFatPercentage.map { "\(Int(($0 * 100).rounded()))%" } ?? "not set"
        let goalWeight = profile.goalWeightKg.map { kg in
            useMetric ? String(format: "%.1f kg", kg) : String(format: "%.1f lb", kg * 2.20462)
        } ?? "not set"
        let currentGoalLines = OptionalNutrient.allCases
            .map { "- \($0.displayName): \(currentGoals.goal(for: $0)) \($0.unit) (\($0.goalStyle))" }
            .joined(separator: "\n")

        let prompt = """
        You are setting daily non-macro nutrient goals for a food tracking app.
        Return ONLY valid JSON with these exact numeric keys:
        {"fiber":30,"sugar":50,"added_sugar":25,"saturated_fat":20,"cholesterol":300,"sodium":2300,"potassium":3500,"trans_fat":0,"calcium":1000,"iron":18,"magnesium":400,"zinc":11,"vitamin_a":900,"vitamin_c":90,"vitamin_d":20,"vitamin_b12":3,"vitamin_e":15,"vitamin_k":120,"folate":400,"omega_3":2}

        Do not include calories, protein, carbs, or fat. Do not change calorie or macro targets.
        Use reasonable general-adult nutrition targets unless the user's profile strongly suggests a small adjustment.
        Treat fiber, potassium, calcium, iron, magnesium, zinc, vitamins, folate, and omega-3 as target/minimum style goals. Treat sugar, added sugar, saturated fat, trans fat, cholesterol, and sodium as daily limit-style goals.
        Units: sugar, added_sugar, fiber, saturated_fat, trans_fat, and omega_3 are grams; cholesterol, sodium, potassium, calcium, iron, magnesium, zinc, vitamin_c, and vitamin_e are milligrams; vitamin_a, vitamin_d, vitamin_b12, vitamin_k, and folate are micrograms.
        Keep values in normal consumer-tracker ranges and round to practical app-friendly numbers.
        Use integers only.

        User profile:
        - Gender: \(profile.gender.displayName)
        - Age: \(profile.age)
        - Height: \(height)
        - Weight: \(weight)
        - Activity: \(profile.activityLevel.displayName)
        - Weight goal: \(profile.goal.displayName)
        - Goal weight: \(goalWeight)
        - Body fat: \(bodyFat)
        - Current calorie target: \(profile.effectiveCalories) kcal
        - Current macro targets: \(profile.effectiveProtein)g protein, \(profile.effectiveCarbs)g carbs, \(profile.effectiveFat)g fat

        Current non-macro nutrient defaults/custom values:
        \(currentGoalLines)
        """

        let text = try await callAI(prompt: prompt, image: nil)
        return try parseOptionalNutrientGoals(from: text, fallback: currentGoals)
    }

    static func suggestHealthEnergyGoals(
        profile: UserProfile,
        energy: HealthEnergySummary,
        useMetric: Bool
    ) async throws -> HealthEnergyGoalSuggestion {
        let weight = useMetric
            ? String(format: "%.1f kg", profile.weightKg)
            : String(format: "%.1f lb", profile.weightKg * 2.20462)
        let height = useMetric
            ? String(format: "%.0f cm", profile.heightCm)
            : String(format: "%.1f in", profile.heightCm / 2.54)
        let bodyFat = profile.bodyFatPercentage.map { "\(Int(($0 * 100).rounded()))%" } ?? "not set"
        let goalWeight = profile.goalWeightKg.map { kg in
            useMetric ? String(format: "%.1f kg", kg) : String(format: "%.1f lb", kg * 2.20462)
        } ?? "not set"
        let healthTotalLine = energy.totalAverageCalories
            .map { "\($0) kcal/day from active + basal energy" }
            ?? "basal energy unavailable; estimate total burn from app BMR + Apple Health active energy"

        let prompt = """
        You are setting a daily calorie target for a food tracking app.
        Return ONLY valid JSON with these exact keys:
        {"calories":2000,"reason":"Short reason under 100 characters"}

        Use Apple Health energy as the primary activity signal, but keep the app's existing formula as a sanity check.
        If Apple Health basal energy is unavailable, estimate total daily burn from app BMR plus Apple Health active energy.
        Apply the user's weight goal and weekly change preference to choose the calorie target.
        Keep calories practical for a consumer food tracker: 800-6000 kcal.
        Do not set protein, carbs, or fat; the app keeps macros unlocked on auto-balance unless the user manually locks them.
        Use integers only for calories. Do not include any other keys.

        User profile:
        - Gender: \(profile.gender.displayName)
        - Age: \(profile.age)
        - Height: \(height)
        - Weight: \(weight)
        - Activity level setting: \(profile.activityLevel.displayName)
        - Weight goal: \(profile.goal.displayName)
        - Weekly change preference: \(profile.weeklyChangeKg.map { String(format: "%.2f kg/week", $0) } ?? "maintain")
        - Goal weight: \(goalWeight)
        - Body fat: \(bodyFat)

        Existing app formula:
        - BMR: \(Int(profile.bmr.rounded())) kcal/day
        - TDEE: \(Int(profile.tdee.rounded())) kcal/day
        - Formula calorie target: \(profile.dailyCalories) kcal/day

        Apple Health energy from \(energy.daysUsed) of the last \(energy.requestedDays) completed days:
        - Active energy average: \(energy.activeAverageCalories) kcal/day
        - Basal energy average: \(energy.basalAverageCalories.map { "\($0) kcal/day" } ?? "not available")
        - Health total: \(healthTotalLine)
        """

        let text = try await callAI(prompt: prompt, image: nil)
        return try parseHealthEnergyGoalSuggestion(from: text)
    }

    // MARK: - Weight Forecast Insight

    /// Asks the user's selected LLM to summarize their weight trend and suggest 2–3 adjustments
    /// in plain English. Caller provides an already-computed WeightForecast so the LLM gets hard
    /// numbers instead of guessing.
    static func analyzeWeightTrend(
        profile: UserProfile,
        forecast: WeightForecast,
        recentAvgMacros: (protein: Int, carbs: Int, fat: Int)?,
        useMetric: Bool
    ) async throws -> String {
        let unit = useMetric ? "kg" : "lbs"
        let wUnit: (Double) -> String = { kg in
            useMetric ? String(format: "%.1f kg", kg) : String(format: "%.1f lbs", kg * 2.20462)
        }
        let weekly: (Double) -> String = { kg in
            useMetric ? String(format: "%+.2f kg/week", kg) : String(format: "%+.2f lbs/week", kg * 2.20462)
        }

        var lines: [String] = []
        lines.append("User profile:")
        lines.append("- Gender: \(profile.gender.rawValue)")
        lines.append("- Age: \(profile.age)")
        lines.append("- Height: \(useMetric ? String(format: "%.0f cm", profile.heightCm) : String(format: "%.1f in", profile.heightCm / 2.54))")
        lines.append("- Current weight: \(wUnit(forecast.currentWeightKg))")
        lines.append("- Activity level: \(profile.activityLevel.displayName)")
        lines.append("- Goal: \(profile.goal.displayName)")
        if let goal = profile.goalWeightKg {
            lines.append("- Goal weight: \(wUnit(goal))")
        }
        if let bf = profile.bodyFatPercentage {
            lines.append("- Body fat: \(Int(bf * 100))%")
        }
        lines.append("")
        lines.append("Energy balance (from \(forecast.daysOfFoodData) days of logged food):")
        lines.append("- Avg daily intake: \(forecast.avgDailyCalories) kcal")
        lines.append("- TDEE estimate: \(forecast.tdee) kcal")
        lines.append("- Daily balance: \(forecast.dailyEnergyBalance >= 0 ? "+" : "")\(forecast.dailyEnergyBalance) kcal")
        if let macros = recentAvgMacros {
            lines.append("- Avg macros: \(macros.protein)g protein, \(macros.carbs)g carbs, \(macros.fat)g fat")
        }
        lines.append("")
        lines.append("Projection:")
        lines.append("- Predicted (from diet): \(weekly(forecast.predictedWeeklyChangeKg))")
        if let observed = forecast.observedWeeklyChangeKg {
            lines.append("- Observed (from \(forecast.weightEntriesUsed) weight entries): \(weekly(observed))")
        }
        lines.append("- Expected weight in 30 days: \(wUnit(forecast.predictedWeight30dKg))")
        lines.append("- Expected weight in 90 days: \(wUnit(forecast.predictedWeight90dKg))")
        if let days = forecast.daysToGoal {
            lines.append("- At current pace, reach goal in ~\(days) days")
        }
        if forecast.trendsDisagree {
            lines.append("- NOTE: predicted and observed trends differ by >0.3 kg/week (possibly under-logging food).")
        }

        let prompt = """
        You are a nutrition coach analyzing a user's weight trend. Write 3–4 short sentences (plain English, no bullets, no markdown, no bold) that:
        1. State the predicted weight in \(unit) 30 days out and whether they're on track for their goal.
        2. Give one or two specific, actionable suggestions (e.g. calorie target, protein amount, activity change) grounded in the numbers below.
        3. If predicted and observed trends disagree, mention possible under-logging briefly.
        Be direct, factual, and encouraging. Do not exceed 100 words.

        \(lines.joined(separator: "\n"))
        """
        return try await callAI(prompt: prompt, image: nil)
    }

    private static func macroTotals(for entries: [FoodEntry]) -> MacroTotals {
        entries.reduce(.zero) { totals, entry in
            totals + macroTotals(for: entry)
        }
    }

    private static func macroTotals(for entry: FoodEntry) -> MacroTotals {
        MacroTotals(
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat
        )
    }

    private static func macroLine(_ totals: MacroTotals) -> String {
        "\(totals.calories) kcal, \(formatGrams(totals.protein))g protein, \(formatGrams(totals.carbs))g carbs, \(formatGrams(totals.fat))g fat"
    }

    private static func formatGrams(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    // MARK: - Unified AI Call Router

    private static func callAI(prompt: String, image: UIImage?) async throws -> String {
        try await callAI(prompt: prompt, images: image.map { [$0] } ?? [])
    }

    private static func callAI(prompt: String, images: [UIImage]) async throws -> String {
        let primaryProvider = AIProviderSettings.selectedProvider
        if primaryProvider.requiresAPIKey, AIProviderSettings.currentAPIKey == nil {
            throw AnalysisError.noAPIKey
        }

        let imageDataList = try images.map {
            try encodedJPEGData(for: $0)
        }

        do {
            return try await dispatch(
                provider: primaryProvider,
                model: AIProviderSettings.selectedModel,
                baseURL: AIProviderSettings.currentBaseURL,
                apiKey: AIProviderSettings.currentAPIKey,
                prompt: prompt,
                imageDataList: imageDataList
            )
        } catch {
            // imageConversionFailed is local — fallback won't help, rethrow.
            // For everything else (network / 5xx / 4xx / parser failure) try fallback.
            if case AnalysisError.imageConversionFailed = error { throw error }
            guard let fallback = AIProviderSettings.currentFallbackConfig(excludingPrimary: primaryProvider) else {
                throw error
            }
            return try await dispatch(
                provider: fallback.provider,
                model: fallback.model,
                baseURL: fallback.baseURL,
                apiKey: fallback.apiKey,
                prompt: prompt,
                imageDataList: imageDataList
            )
        }
    }

    private static func encodedJPEGData(for image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw AnalysisError.imageConversionFailed
        }
        return data
    }

    private static func dispatch(provider: AIProvider, model: String, baseURL: String, apiKey: String?, prompt: String, imageDataList: [Data]) async throws -> String {
        switch provider.apiFormat {
        case .gemini:
            guard let key = apiKey else { throw AnalysisError.noAPIKey }
            return try await callGemini(baseURL: baseURL, model: model, apiKey: key, prompt: prompt, imageDataList: imageDataList)
        case .openaiCompatible:
            return try await callOpenAICompatible(baseURL: baseURL, model: model, apiKey: apiKey, provider: provider, prompt: prompt, imageDataList: imageDataList)
        case .anthropic:
            guard let key = apiKey else { throw AnalysisError.noAPIKey }
            return try await callAnthropic(baseURL: baseURL, model: model, apiKey: key, prompt: prompt, imageDataList: imageDataList)
        }
    }

    // MARK: - Gemini Format

    private static func callGemini(baseURL: String, model: String, apiKey: String?, prompt: String, imageDataList: [Data]) async throws -> String {
        // Send the API key in the X-goog-api-key header, not the URL query string,
        // so it doesn't end up in server logs / proxies (CodeQL: cleartext transmission).
        var parts: [[String: Any]] = []
        for imageData in imageDataList {
            parts.append([
                "inlineData": [
                    "mimeType": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }
        parts.append(["text": prompt])

        var body: [String: Any] = [
            "contents": [["parts": parts]]
        ]
        if let userContext = AIProviderSettings.currentUserContext {
            body["systemInstruction"] = ["parts": [["text": userContext]]]
        }

        let data: Data
        guard let apiKey else { throw AnalysisError.noAPIKey }
        guard let url = URL(string: "\(baseURL)/models/\(model):generateContent") else {
            throw AnalysisError.apiError("Invalid API URL. Check your provider settings.")
        }
        data = try await makeRequest(
            url: url,
            headers: ["Content-Type": "application/json", "X-goog-api-key": apiKey],
            body: body
        )

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String
        else { throw AnalysisError.invalidResponse }
        return text
    }

    // MARK: - OpenAI-Compatible Format (OpenAI, xAI, OpenRouter, Together, Groq, Ollama)

    private static func callOpenAICompatible(baseURL: String, model: String, apiKey: String?, provider: AIProvider, prompt: String, imageDataList: [Data]) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AnalysisError.apiError("Invalid API URL. Check your provider settings.")
        }

        var content: [[String: Any]] = []
        for imageData in imageDataList {
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:image/jpeg;base64,\(imageData.base64EncodedString())"]
            ])
        }
        content.append(["type": "text", "text": prompt])

        var messages: [[String: Any]] = []
        if let userContext = AIProviderSettings.currentUserContext {
            messages.append(["role": "system", "content": userContext])
        }
        messages.append(["role": "user", "content": content])

        var body: [String: Any] = [
            "model": model,
            "messages": messages,
        ]
        body[provider.openAICompatibleTokenLimitKey(for: model)] = 1024

        var headers = ["Content-Type": "application/json"]
        if let apiKey {
            headers["Authorization"] = "Bearer \(apiKey)"
        }
        if provider == .openrouter {
            headers["HTTP-Referer"] = "https://github.com/apoorvdarshan/fud-ai"
            headers["X-Title"] = "Fud AI"
        }

        let data = try await makeRequest(url: url, headers: headers, body: body)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else { throw AnalysisError.invalidResponse }
        return text
    }

    // MARK: - Anthropic Format

    private static func callAnthropic(baseURL: String, model: String, apiKey: String, prompt: String, imageDataList: [Data]) async throws -> String {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AnalysisError.apiError("Invalid API URL. Check your provider settings.")
        }

        var content: [[String: Any]] = []
        for imageData in imageDataList {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": imageData.base64EncodedString()
                ]
            ])
        }
        content.append(["type": "text", "text": prompt])

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": content]],
        ]
        if let userContext = AIProviderSettings.currentUserContext {
            body["system"] = userContext
        }

        let headers = [
            "Content-Type": "application/json",
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
        ]

        let data = try await makeRequest(url: url, headers: headers, body: body)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let text = contentArray.first?["text"] as? String
        else { throw AnalysisError.invalidResponse }
        return text
    }

    // MARK: - Network

    private static func makeRequest(url: URL, headers: [String: String], body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Retry transient overload responses (503/429/529) with exponential backoff: 1s, 2s, 4s.
        // The "model is currently experiencing high demand" message is Google's global throttle on
        // the Gemini model, not a per-key rate limit, so a quick retry usually succeeds.
        let retryDelaysNs: [UInt64] = [1_000_000_000, 2_000_000_000, 4_000_000_000]
        var lastError: AnalysisError = .apiError("Request failed")

        for attempt in 0...retryDelaysNs.count {
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await URLSession.shared.data(for: request)
            } catch {
                throw AnalysisError.networkError(error)
            }

            guard let httpResponse = response as? HTTPURLResponse else { return data }

            if httpResponse.statusCode == 200 {
                return data
            }

            // Parse the API's error message once so we can surface the friendliest version.
            // Fall back to a status-code-only message when parsing finds nothing OR when the
            // parsed value is empty (some providers return `{"error": {"message": ""}}`,
            // which used to slip through as a literal blank "API error: " alert).
            let parsed = AINetworkHelpers.parseErrorMessage(from: data) ?? ""
            let parsedMessage = parsed.isEmpty ? "HTTP \(httpResponse.statusCode)" : parsed
            lastError = .apiError(AINetworkHelpers.friendlyMessage(for: httpResponse.statusCode, raw: parsedMessage))

            let isRetryable = httpResponse.statusCode == 503
                           || httpResponse.statusCode == 529
                           || httpResponse.statusCode == 429
            if isRetryable && attempt < retryDelaysNs.count {
                try? await Task.sleep(nanoseconds: retryDelaysNs[attempt])
                continue
            }
            throw lastError
        }
        throw lastError
    }

    // MARK: - Parsing (unchanged)

    private static func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let openFence = cleaned.range(of: "```json", options: .caseInsensitive)
            ?? cleaned.range(of: "```") {
            cleaned = String(cleaned[openFence.upperBound...])
            if let closeFence = cleaned.range(of: "```", options: .backwards) {
                cleaned = String(cleaned[..<closeFence.lowerBound])
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let firstBrace = cleaned.firstIndex(of: "{") else { return cleaned }
        var depth = 0
        var inString = false
        var escape = false
        var endIndex: String.Index?
        for idx in cleaned[firstBrace...].indices {
            let ch = cleaned[idx]
            if escape { escape = false; continue }
            if ch == "\\" { escape = true; continue }
            if ch == "\"" { inString.toggle(); continue }
            if inString { continue }
            if ch == "{" { depth += 1 }
            else if ch == "}" {
                depth -= 1
                if depth == 0 {
                    endIndex = cleaned.index(after: idx)
                    break
                }
            }
        }
        if let end = endIndex {
            return String(cleaned[firstBrace..<end])
        }
        return cleaned
    }

    private static func parseFoodAnalysis(from text: String) throws -> FoodAnalysis {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let calories = (json["calories"] as? NSNumber)?.intValue,
              let protein = (json["protein"] as? NSNumber)?.doubleValue,
              let carbs = (json["carbs"] as? NSNumber)?.doubleValue,
              let fat = (json["fat"] as? NSNumber)?.doubleValue
        else { throw AnalysisError.invalidResponse }
        let servingSizeGrams = (json["serving_size_grams"] as? NSNumber)?.doubleValue ?? 100
        let unitOptions = parseServingUnitOptions(from: json, servingSizeGrams: servingSizeGrams)
        let selectedOption = unitOptions.first
        func double(_ key: String) -> Double? {
            (json[key] as? NSNumber)?.doubleValue
        }
        return FoodAnalysis(
            name: name, calories: calories, protein: protein, carbs: carbs, fat: fat,
            servingSizeGrams: servingSizeGrams,
            emoji: json["emoji"] as? String,
            sugar: double("sugar"),
            addedSugar: double("added_sugar"),
            fiber: double("fiber"),
            saturatedFat: double("saturated_fat"),
            monounsaturatedFat: double("monounsaturated_fat"),
            polyunsaturatedFat: double("polyunsaturated_fat"),
            cholesterol: double("cholesterol"),
            sodium: double("sodium"),
            potassium: double("potassium"),
            transFat: double("trans_fat"),
            calcium: double("calcium"),
            iron: double("iron"),
            magnesium: double("magnesium"),
            zinc: double("zinc"),
            vitaminA: double("vitamin_a"),
            vitaminC: double("vitamin_c"),
            vitaminD: double("vitamin_d"),
            vitaminB12: double("vitamin_b12"),
            vitaminE: double("vitamin_e"),
            vitaminK: double("vitamin_k"),
            folate: double("folate"),
            omega3: double("omega_3"),
            servingUnitOptions: unitOptions,
            selectedServingUnit: selectedOption?.unit,
            selectedServingQuantity: selectedOption?.quantity(for: servingSizeGrams)
        )
    }

    private static func parseNutritionLabel(from text: String) throws -> NutritionLabelAnalysis {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let caloriesPer100g = (json["calories_per_100g"] as? NSNumber)?.doubleValue,
              let proteinPer100g = (json["protein_per_100g"] as? NSNumber)?.doubleValue,
              let carbsPer100g = (json["carbs_per_100g"] as? NSNumber)?.doubleValue,
              let fatPer100g = (json["fat_per_100g"] as? NSNumber)?.doubleValue
        else { throw AnalysisError.invalidResponse }
        let servingSizeGrams = (json["serving_size_grams"] as? NSNumber)?.doubleValue
        func double(_ key: String) -> Double? {
            (json[key] as? NSNumber)?.doubleValue
        }
        return NutritionLabelAnalysis(
            name: name, caloriesPer100g: caloriesPer100g, proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g, fatPer100g: fatPer100g,
            servingSizeGrams: servingSizeGrams,
            sugarPer100g: double("sugar_per_100g"),
            addedSugarPer100g: double("added_sugar_per_100g"),
            fiberPer100g: double("fiber_per_100g"),
            saturatedFatPer100g: double("saturated_fat_per_100g"),
            monounsaturatedFatPer100g: double("monounsaturated_fat_per_100g"),
            polyunsaturatedFatPer100g: double("polyunsaturated_fat_per_100g"),
            cholesterolPer100g: double("cholesterol_per_100g"),
            sodiumPer100g: double("sodium_per_100g"),
            potassiumPer100g: double("potassium_per_100g"),
            transFatPer100g: double("trans_fat_per_100g"),
            calciumPer100g: double("calcium_per_100g"),
            ironPer100g: double("iron_per_100g"),
            magnesiumPer100g: double("magnesium_per_100g"),
            zincPer100g: double("zinc_per_100g"),
            vitaminAPer100g: double("vitamin_a_per_100g"),
            vitaminCPer100g: double("vitamin_c_per_100g"),
            vitaminDPer100g: double("vitamin_d_per_100g"),
            vitaminB12Per100g: double("vitamin_b12_per_100g"),
            vitaminEPer100g: double("vitamin_e_per_100g"),
            vitaminKPer100g: double("vitamin_k_per_100g"),
            folatePer100g: double("folate_per_100g"),
            omega3Per100g: double("omega_3_per_100g"),
            servingUnitOptions: parseServingUnitOptions(from: json, servingSizeGrams: servingSizeGrams)
        )
    }

    private static func parseOptionalNutrientGoals(
        from text: String,
        fallback: OptionalNutrientGoals
    ) throws -> OptionalNutrientGoals {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw AnalysisError.invalidResponse }

        var goals = fallback.mergedWithDefaults()
        var parsedAnyValue = false

        for nutrient in OptionalNutrient.allCases {
            let rawValue = json[nutrient.jsonKey] ?? json[nutrient.rawValue]
            guard let number = rawValue as? NSNumber else { continue }
            goals.setGoal(number.intValue, for: nutrient)
            parsedAnyValue = true
        }

        guard parsedAnyValue else { throw AnalysisError.invalidResponse }
        return goals.mergedWithDefaults()
    }

    private static func parseHealthEnergyGoalSuggestion(from text: String) throws -> HealthEnergyGoalSuggestion {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let calories = (json["calories"] as? NSNumber)?.intValue
        else { throw AnalysisError.invalidResponse }

        return HealthEnergyGoalSuggestion(
            calories: min(max(calories, 800), 6_000),
            reason: json["reason"] as? String
        )
    }

    private static func addingFallbackServingUnits(
        to analysis: FoodAnalysis,
        image: UIImage?,
        description: String?
    ) async -> FoodAnalysis {
        guard analysis.servingUnitOptions.isEmpty else { return analysis }
        guard let options = try? await inferServingUnitOptions(
            name: analysis.name,
            servingSizeGrams: analysis.servingSizeGrams,
            image: image,
            description: description
        ), !options.isEmpty else {
            return analysis
        }

        var updated = analysis
        updated.servingUnitOptions = options
        updated.selectedServingUnit = options.first?.unit
        updated.selectedServingQuantity = options.first?.quantity(for: analysis.servingSizeGrams)
        return updated
    }

    private static func addingFallbackServingUnits(
        to analysis: NutritionLabelAnalysis,
        image: UIImage
    ) async -> NutritionLabelAnalysis {
        guard analysis.servingUnitOptions.isEmpty else { return analysis }
        guard let servingSizeGrams = analysis.servingSizeGrams,
              let options = try? await inferServingUnitOptions(
                name: analysis.name,
                servingSizeGrams: servingSizeGrams,
                image: image,
                description: nil
              ), !options.isEmpty else {
            return analysis
        }

        var updated = analysis
        updated.servingUnitOptions = options
        return updated
    }

    private static func inferServingUnitOptions(
        name: String,
        servingSizeGrams: Double,
        image: UIImage?,
        description: String?
    ) async throws -> [ServingUnitOption] {
        let context = description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let contextLine = context.map { "\nUser context: \($0)" } ?? ""
        let prompt = """
        The previous food analysis returned grams only. Infer non-gram serving unit options for the same food and amount.

        Food: \(name)
        Total grams for the analyzed amount: \(String(format: "%.1f", servingSizeGrams))\(contextLine)

        Return ONLY JSON:
        {"unit_options":[{"unit":"slice","quantity":8.0,"grams_per_unit":45.0}]}

        Rules:
        - Replace the sample numbers with the actual best estimate. Do not copy 8 or 45 unless they fit the food.
        - If the image shows countable portions, count visible pieces/slices. For pizza, cake, pie, bread, cookies, fruit pieces, nuggets, or sweets, use slice or piece.
        - For liquids or pourable foods like milk, juice, soup, smoothies, dal, sauces, or yogurt, use ml when the volume is clearer than a count.
        - For spooned foods like peanut butter, honey, oil, chutney, or ghee, use tbsp or tsp.
        - For packaged foods/drinks, use can, packet, bar, scoop, or bowl only when that unit is visible or strongly implied.
        - grams_per_unit is grams for one unit. For countable units, use total grams / visible quantity. For ml, use grams per ml.
        - Return [] only if no non-gram unit is apparent.

        Good outputs:
        {"unit_options":[{"unit":"slice","quantity":8.0,"grams_per_unit":45.0}]}
        {"unit_options":[{"unit":"ml","quantity":250.0,"grams_per_unit":1.03},{"unit":"cup","quantity":1.0,"grams_per_unit":250.0}]}
        {"unit_options":[{"unit":"tbsp","quantity":2.0,"grams_per_unit":16.0}]}
        {"unit_options":[{"unit":"can","quantity":1.0,"grams_per_unit":330.0}]}
        {"unit_options":[{"unit":"piece","quantity":5.0,"grams_per_unit":18.0}]}
        """

        let text = try await callAI(prompt: prompt, image: image)
        return try parseServingUnitOptions(from: text, servingSizeGrams: servingSizeGrams)
    }

    private static func parseServingUnitOptions(from text: String, servingSizeGrams: Double?) throws -> [ServingUnitOption] {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw AnalysisError.invalidResponse }
        return parseServingUnitOptions(from: json, servingSizeGrams: servingSizeGrams)
    }

    private static func parseServingUnitOptions(from json: [String: Any], servingSizeGrams: Double?) -> [ServingUnitOption] {
        let rawOptions = json["unit_options"] as? [[String: Any]]
            ?? json["serving_unit_options"] as? [[String: Any]]
            ?? []

        var seen = Set<String>()
        var options: [ServingUnitOption] = []
        for raw in rawOptions {
            guard let unit = raw["unit"] as? String,
                  let gramsPerUnit = doubleValue(raw["grams_per_unit"] ?? raw["gramsPerUnit"])
            else { continue }

            var option = ServingUnitOption(
                unit: unit,
                gramsPerUnit: gramsPerUnit,
                quantity: doubleValue(raw["quantity"])
            )
            if option.quantity == nil, let servingSizeGrams, gramsPerUnit > 0 {
                option.quantity = servingSizeGrams / gramsPerUnit
            }

            guard option.isValid, !option.isGramUnit, !seen.contains(option.id) else { continue }
            seen.insert(option.id)
            options.append(option)
        }
        return Array(options.prefix(4))
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }
}
