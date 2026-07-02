import Foundation

/// On-demand data accessor for Coach. Replaces the old "dump everything into
/// the system prompt" pattern: instead of stuffing the prompt with the last
/// N weights + N body fats + N days of food, we expose a small tool kit that
/// the LLM can call when it actually needs older / specific data.
///
/// Three provider formats (Gemini / Anthropic Messages / OpenAI-compatible)
/// each have a slightly different tool schema shape. CoachTools owns the
/// execute() side — turning a tool name + JSON args into a JSON result —
/// while the per-provider tool definitions live alongside each provider's
/// HTTP layer (formatted for that API in callX).
///
/// Date format on the API: ISO `yyyy-MM-dd`. Each list-returning tool caps
/// results at 365 entries to bound any one tool result's size — Coach can
/// always issue a narrower range for older history if it needs more.
struct CoachTools {
    let weights: [WeightEntry]
    let bodyFats: [BodyFatEntry]
    let foods: [FoodEntry]

    /// All available tool names — used by per-provider schema builders to stay
    /// in sync with the executor.
    static let toolNames: [String] = [
        "get_data_summary",
        "get_weight_history",
        "get_body_fat_history",
        "get_calorie_totals",
        "get_food_entries",
    ]

    /// Per-provider tool descriptions kept in one place so all three formats
    /// see the same human-readable text.
    static let toolDescriptions: [String: String] = [
        "get_data_summary": "Get a quick summary of the user's available data: total counts and earliest/latest dates for weights, body-fat readings, and food entries. Call this first when the user asks anything about their history range or data spanning more than 14 days.",
        "get_weight_history": "Fetch weight entries between two dates (inclusive). Returns date + weight (kg + lbs). Use this when the user asks about specific past dates or weight trends older than the last 10 entries.",
        "get_body_fat_history": "Fetch body-fat readings between two dates (inclusive). Returns date + percent. Use when the user asks about body composition trends older than the last 10 readings.",
        "get_calorie_totals": "Daily calorie totals (sum of all logged foods per day) between two dates. Returns date + kcal. Use when the user asks about intake patterns older than the last 14 days.",
        "get_food_entries": "Individual logged food items (name + calories + macros) between two dates. Use when the user asks about specific meals, what they ate on a given date, or wants macro breakdowns rather than just kcal totals.",
    ]

    // MARK: - Execution

    /// Turn a tool call into a JSON-encoded result string. Unknown tool names
    /// return a JSON error so the LLM can correct course rather than silently
    /// hallucinate; callers should always pass through whatever this returns.
    func execute(name: String, arguments: [String: Any]) -> String {
        switch name {
        case "get_data_summary":
            return getDataSummary()
        case "get_weight_history":
            return getWeightHistory(arguments: arguments)
        case "get_body_fat_history":
            return getBodyFatHistory(arguments: arguments)
        case "get_calorie_totals":
            return getCalorieTotals(arguments: arguments)
        case "get_food_entries":
            return getFoodEntries(arguments: arguments)
        default:
            return jsonError("Unknown tool: \(name). Available tools: \(Self.toolNames.joined(separator: ", "))")
        }
    }

    // MARK: - Tool implementations

    private func getDataSummary() -> String {
        let weightDates = weights.map { $0.date }.sorted()
        let bodyFatDates = bodyFats.map { $0.date }.sorted()
        let foodDates = foods.map { $0.timestamp }.sorted()
        // Explicit `as Any` on the optional → NSNull coalesce so the dictionary
        // literal doesn't trigger Swift's "Any? coerced to Any" warning. Both
        // branches resolve to a concrete JSON-serializable type at runtime.
        let payload: [String: Any] = [
            "weights": [
                "count": weights.count,
                "first_date": (weightDates.first.map(Self.iso) ?? NSNull()) as Any,
                "last_date": (weightDates.last.map(Self.iso) ?? NSNull()) as Any,
            ],
            "body_fats": [
                "count": bodyFats.count,
                "first_date": (bodyFatDates.first.map(Self.iso) ?? NSNull()) as Any,
                "last_date": (bodyFatDates.last.map(Self.iso) ?? NSNull()) as Any,
            ],
            "foods": [
                "count": foods.count,
                "first_date": (foodDates.first.map(Self.iso) ?? NSNull()) as Any,
                "last_date": (foodDates.last.map(Self.iso) ?? NSNull()) as Any,
            ],
        ]
        return jsonString(payload)
    }

    private func getWeightHistory(arguments: [String: Any]) -> String {
        let (from, to) = parseRange(arguments)
        let limit = (arguments["limit"] as? Int).map { min(max($0, 1), 365) } ?? 365
        let filtered = weights
            .filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date < $1.date }
            .prefix(limit)
        let entries = filtered.map { entry -> [String: Any] in
            [
                "date": Self.iso(entry.date),
                "kg": (entry.weightKg * 10).rounded() / 10,
                "lbs": (entry.weightKg * 2.20462 * 10).rounded() / 10,
            ]
        }
        return jsonString([
            "from": Self.iso(from),
            "to": Self.iso(to),
            "count": entries.count,
            "weights": entries,
        ])
    }

    private func getBodyFatHistory(arguments: [String: Any]) -> String {
        let (from, to) = parseRange(arguments)
        let limit = (arguments["limit"] as? Int).map { min(max($0, 1), 365) } ?? 365
        let filtered = bodyFats
            .filter { $0.date >= from && $0.date <= to }
            .sorted { $0.date < $1.date }
            .prefix(limit)
        let entries = filtered.map { entry -> [String: Any] in
            [
                "date": Self.iso(entry.date),
                "percent": Int((entry.bodyFatFraction * 100).rounded()),
            ]
        }
        return jsonString([
            "from": Self.iso(from),
            "to": Self.iso(to),
            "count": entries.count,
            "body_fats": entries,
        ])
    }

    private func getCalorieTotals(arguments: [String: Any]) -> String {
        let (from, to) = parseRange(arguments)
        let calendar = Calendar.current
        var dailyKcal: [String: Int] = [:]
        for food in foods where food.timestamp >= from && food.timestamp <= to {
            let day = Self.iso(calendar.startOfDay(for: food.timestamp))
            dailyKcal[day, default: 0] += food.calories
        }
        let totals = dailyKcal
            .sorted { $0.key < $1.key }
            .map { ["date": $0.key, "kcal": $0.value] }
        return jsonString([
            "from": Self.iso(from),
            "to": Self.iso(to),
            "days_with_data": totals.count,
            "totals": totals,
        ])
    }

    private func getFoodEntries(arguments: [String: Any]) -> String {
        let (from, to) = parseRange(arguments)
        let limit = (arguments["limit"] as? Int).map { min(max($0, 1), 365) } ?? 200
        let filtered = foods
            .filter { $0.timestamp >= from && $0.timestamp <= to }
            .sorted { $0.timestamp < $1.timestamp }
            .prefix(limit)
        let entries = filtered.map { entry -> [String: Any] in
            var payload: [String: Any] = [
                "date": Self.iso(entry.timestamp),
                "name": entry.name,
                "kcal": entry.calories,
                "protein_g": entry.protein,
                "carbs_g": entry.carbs,
                "fat_g": entry.fat,
                "meal_type": entry.mealType.rawValue,
                "source": entry.source.rawValue,
            ]
            func add(_ key: String, _ value: Double?) {
                if let value {
                    payload[key] = value
                }
            }
            add("serving_size_g", entry.servingSizeGrams)
            add("sugar_g", entry.sugar)
            add("added_sugar_g", entry.addedSugar)
            add("fiber_g", entry.fiber)
            add("saturated_fat_g", entry.saturatedFat)
            add("monounsaturated_fat_g", entry.monounsaturatedFat)
            add("polyunsaturated_fat_g", entry.polyunsaturatedFat)
            add("cholesterol_mg", entry.cholesterol)
            add("sodium_mg", entry.sodium)
            add("potassium_mg", entry.potassium)
            add("trans_fat_g", entry.transFat)
            add("calcium_mg", entry.calcium)
            add("iron_mg", entry.iron)
            add("magnesium_mg", entry.magnesium)
            add("zinc_mg", entry.zinc)
            add("vitamin_a_mcg", entry.vitaminA)
            add("vitamin_c_mg", entry.vitaminC)
            add("vitamin_d_mcg", entry.vitaminD)
            add("vitamin_b12_mcg", entry.vitaminB12)
            add("vitamin_e_mg", entry.vitaminE)
            add("vitamin_k_mcg", entry.vitaminK)
            add("folate_mcg", entry.folate)
            add("omega_3_g", entry.omega3)
            return payload
        }
        return jsonString([
            "from": Self.iso(from),
            "to": Self.iso(to),
            "count": entries.count,
            "foods": entries,
        ])
    }

    // MARK: - Helpers

    /// Parse a `from` / `to` date range from the LLM's tool args. Defaults to
    /// last 30 days if `from` is missing, and to .now if `to` is missing —
    /// generous defaults mean a malformed call still returns useful data
    /// rather than failing the whole turn.
    private func parseRange(_ args: [String: Any]) -> (Date, Date) {
        let to = (args["to"] as? String).flatMap(Self.parseDate) ?? Date()
        let from = (args["from"] as? String).flatMap(Self.parseDate)
            ?? Calendar.current.date(byAdding: .day, value: -30, to: to)
            ?? to
        // Inclusive end-of-day so "to: 2025-04-26" includes everything that day.
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
        let startOfDay = Calendar.current.startOfDay(for: from)
        return (startOfDay, endOfDay)
    }

    /// `nonisolated` on the helpers below so they can be called from any
    /// context without tripping Swift's main-actor isolation warnings under
    /// the project-wide SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor setting.
    /// DateFormatter is Sendable as of recent SDKs, so a plain `private static
    /// let` is fine — no `nonisolated(unsafe)` needed.
    nonisolated private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    nonisolated private static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }
    nonisolated private static func parseDate(_ s: String) -> Date? { isoFormatter.date(from: s) }

    private func jsonString(_ obj: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    private func jsonError(_ message: String) -> String {
        jsonString(["error": message])
    }
}
