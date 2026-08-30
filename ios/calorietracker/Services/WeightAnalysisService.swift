import Foundation

/// Pure thermodynamic / statistical forecast of where the user's weight is heading based on
/// recent calorie intake, logged weight history, and their profile (gender, age, activity, goal).
/// No network, no LLM — just energy-balance math + linear regression.
struct WeightForecast {
    /// Average daily calories eaten over the last `lookbackDays` days of logged food.
    let avgDailyCalories: Int
    /// Total Daily Energy Expenditure from the user's profile (BMR × activity).
    let tdee: Int
    /// avgDailyCalories − tdee. Negative = deficit, positive = surplus.
    let dailyEnergyBalance: Int

    /// Predicted kg change per week based on energy balance (7,700 kcal ≈ 1 kg body fat).
    let predictedWeeklyChangeKg: Double
    /// Predicted kg change per week derived from linear regression on recent weight log.
    /// Nil if fewer than 2 weight entries in the regression window.
    let observedWeeklyChangeKg: Double?

    /// Current weight (latest entry in the store, or profile weight if no entries).
    let currentWeightKg: Double
    /// Predicted weight 30 days from now at the current predicted pace.
    let predictedWeight30dKg: Double
    let predictedWeight60dKg: Double
    let predictedWeight90dKg: Double

    /// Days until goal weight at the current predicted pace. Nil if no goal, if goal is Maintain,
    /// or if the user is moving in the wrong direction.
    let daysToGoal: Int?
    let goalReachDate: Date?

    /// Sentinel for views to know whether enough data exists to render a meaningful forecast.
    let hasEnoughData: Bool
    /// True when predicted (from diet) and observed (from weight scale) trends disagree substantially.
    /// Hint that the user may be under-logging food or not weighing consistently.
    let trendsDisagree: Bool

    /// How many days of logged food informed the calorie average. Displayed so the user knows
    /// how much history the forecast is based on.
    let daysOfFoodData: Int
    /// How many weight entries informed the observed-trend regression.
    let weightEntriesUsed: Int

    /// Hard cap so ancient data doesn't dominate the projection. Everything within this window
    /// is used — if the user only has a week, that's fine; if they have 3 months, we use 3 months.
    static let maxLookbackDays: Int = 90
}

enum WeightAnalysisService {
    static func compute(
        weights: [WeightEntry],
        foods: [FoodEntry],
        profile: UserProfile,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeightForecast {
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -WeightForecast.maxLookbackDays, to: today) ?? today
        let currentEndExclusive = calendar.date(byAdding: .day, value: 1, to: today) ?? now

        // --- Avg daily calories from the previous 90 completed calendar days ---
        // Today's diary is intentionally excluded: it is still in progress and would
        // systematically bias empirical maintenance downward.
        let recentFoods = foods.filter { $0.timestamp >= cutoff && $0.timestamp < today }
        let daysLogged = Set(recentFoods.map { calendar.startOfDay(for: $0.timestamp) }).count
        let totalRecentCal = recentFoods.reduce(0) { $0 + $1.calories }
        let avgDailyCal = daysLogged > 0 ? totalRecentCal / daysLogged : 0

        let tdee = Int(profile.tdee)
        let balance = avgDailyCal - tdee
        let predictedWeeklyKg = Double(balance) * 7.0 / GoalEnergyMath.kilocaloriesPerKilogram

        // --- Current weight ---
        let sortedWeights = weights.sorted { $0.date > $1.date }
        let currentWeight = sortedWeights.first?.weightKg ?? profile.weightKg

        // --- Observed trend via linear regression on weight history ---
        // A weigh-in is a complete point-in-time measurement, so today's reading is useful even
        // though today's still-in-progress food diary is excluded above.
        let regressionWindow = sortedWeights.filter {
            $0.date >= cutoff && $0.date < currentEndExclusive
        }
        let observedWeeklyKg = linearRegressionSlopePerDay(entries: regressionWindow).map { $0 * 7.0 }

        // --- Future projections ---
        let pred30 = currentWeight + predictedWeeklyKg * 30.0 / 7.0
        let pred60 = currentWeight + predictedWeeklyKg * 60.0 / 7.0
        let pred90 = currentWeight + predictedWeeklyKg * 90.0 / 7.0

        // --- Goal-reach projection ---
        var daysToGoal: Int? = nil
        var goalReachDate: Date? = nil
        if let goalKg = profile.goalWeightKg, predictedWeeklyKg != 0, profile.goal != .maintain {
            let kgRemaining = goalKg - currentWeight
            let movingCorrectWay = (profile.goal == .lose && predictedWeeklyKg < 0 && kgRemaining < 0)
                                || (profile.goal == .gain && predictedWeeklyKg > 0 && kgRemaining > 0)
            if movingCorrectWay {
                let daysPerKg = 7.0 / abs(predictedWeeklyKg)
                let days = Int((abs(kgRemaining) * daysPerKg).rounded())
                daysToGoal = days
                goalReachDate = calendar.date(byAdding: .day, value: days, to: now)
            }
        }

        // Work with whatever the user has. Even 2 days of food and 2 weights is enough for a rough forecast;
        // the LLM will caveat accordingly.
        let hasEnoughData = daysLogged >= 2 && regressionWindow.count >= 2

        // Compare predicted vs observed trends. If both exist and they differ by more than
        // 0.3 kg/week, user is likely under-logging food (or over-eating un-logged snacks).
        let trendsDisagree: Bool
        if let observed = observedWeeklyKg, hasEnoughData {
            trendsDisagree = abs(predictedWeeklyKg - observed) > 0.3
        } else {
            trendsDisagree = false
        }

        return WeightForecast(
            avgDailyCalories: avgDailyCal,
            tdee: tdee,
            dailyEnergyBalance: balance,
            predictedWeeklyChangeKg: predictedWeeklyKg,
            observedWeeklyChangeKg: observedWeeklyKg,
            currentWeightKg: currentWeight,
            predictedWeight30dKg: pred30,
            predictedWeight60dKg: pred60,
            predictedWeight90dKg: pred90,
            daysToGoal: daysToGoal,
            goalReachDate: goalReachDate,
            hasEnoughData: hasEnoughData,
            trendsDisagree: trendsDisagree,
            daysOfFoodData: daysLogged,
            weightEntriesUsed: regressionWindow.count
        )
    }

    /// Slope of a simple linear regression (y = mx + b) over weight entries, returning m in
    /// kg per day. Returns nil if fewer than 2 entries.
    private static func linearRegressionSlopePerDay(entries: [WeightEntry]) -> Double? {
        guard entries.count >= 2 else { return nil }
        // Use seconds-since-epoch as X so slope has real time units, then scale to per-day.
        let xs = entries.map { $0.date.timeIntervalSince1970 }
        let ys = entries.map { $0.weightKg }
        let n = Double(xs.count)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0
        var den = 0.0
        for i in 0..<xs.count {
            let dx = xs[i] - meanX
            num += dx * (ys[i] - meanY)
            den += dx * dx
        }
        guard den != 0 else { return nil }
        let kgPerSecond = num / den
        return kgPerSecond * 86_400.0
    }
}

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}
