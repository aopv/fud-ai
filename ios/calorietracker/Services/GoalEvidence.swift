import Foundation

/// Privacy-safe evidence sent to the user's selected text AI when recalculating goals.
/// Food identity, notes, photos, ingredients, and meal-level records never enter this model.
struct GoalEvidence: Equatable {
    enum DayCoverage: String, Equatable {
        case missing
        case partial = "likely_partial"
        case likelyComplete = "likely_complete"
    }

    struct DailyNutrition: Equatable {
        let date: Date
        let calories: Int
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let fiberGrams: Double?
        let fiberLogCount: Int
        let logCount: Int
        let coverage: DayCoverage
    }

    struct WindowSummary: Equatable {
        let days: Int
        let loggedDays: Int
        let likelyCompleteDays: Int
        let averageCaloriesOnLoggedDays: Int?
        let averageCaloriesOnLikelyCompleteDays: Int?
        let averageProteinOnLoggedDays: Double?
        let averageCarbsOnLoggedDays: Double?
        let averageFatOnLoggedDays: Double?
        let averageFiberOnMeasuredDays: Double?
    }

    struct SignalSummary: Equatable {
        let days: Int
        let weightReadings: Int
        let weightSpanDays: Int?
        let bodyFatReadings: Int
        let workoutSessions: Int
        let workoutMinutes: Int
        let healthEnergyDays: Int
        let averageActiveCalories: Int?
        let averageTotalCalories: Int?
        let weightChangeKg: Double?
    }

    struct DatedValue: Equatable {
        let date: Date
        let value: Double
    }

    struct DailyWorkout: Equatable {
        let date: Date
        let sessionCount: Int
        let durationMinutes: Int
        let exerciseCount: Int
        let performedSetCount: Int
        let repCount: Int
    }

    struct MeasurementSnapshot: Equatable {
        let date: Date
        let neckCm: Double?
        let waistCm: Double?
        let hipsCm: Double?
        let chestCm: Double?
        let upperArmCm: Double?
        let thighCm: Double?
        let calfCm: Double?
        let wristCm: Double?
        let waistToHipRatio: Double?
        let waistToHeightRatio: Double?
        let estimatedBodyFatPercent: Double?
    }

    struct Confidence: Equatable {
        enum Level: String, Equatable {
            case low, medium, high
        }

        let level: Level
        let score: Int
        let reasons: [String]
    }

    let lookbackDays: Int
    let dailyNutrition: [DailyNutrition]
    let summaries: [WindowSummary]
    let signalSummaries: [SignalSummary]
    let weights: [DatedValue]
    let bodyFat: [DatedValue]
    let workouts: [DailyWorkout]
    let bodyMeasurements: [MeasurementSnapshot]
    let healthEnergy: [HealthEnergyDay]
    let confidence: Confidence
    let timeZone: TimeZone

    static func build(
        foods: [FoodEntry],
        weights: [WeightEntry],
        bodyFatEntries: [BodyFatEntry],
        workoutSessions: [StrengthWorkoutSession],
        bodyMeasurements: [BodyMeasurement],
        healthEnergy: [HealthEnergyDay],
        profile: UserProfile,
        now: Date = .now,
        calendar: Calendar = .current,
        lookbackDays: Int = WeightForecast.maxLookbackDays
    ) -> GoalEvidence {
        let safeLookback = min(max(1, lookbackDays), WeightForecast.maxLookbackDays)
        let today = calendar.startOfDay(for: now)
        // Goal evidence uses completed calendar days only. Today's diary is still
        // in progress and would systematically look like under-eating.
        let firstDay = calendar.date(byAdding: .day, value: -safeLookback, to: today) ?? today
        let endExclusive = today
        let currentEndExclusive = calendar.date(byAdding: .day, value: 1, to: today) ?? now

        let recentFoods = foods.filter { $0.timestamp >= firstDay && $0.timestamp < endExclusive }
        let foodsByDay = Dictionary(grouping: recentFoods) { calendar.startOfDay(for: $0.timestamp) }

        let dailyNutrition: [DailyNutrition] = (0..<safeLookback).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else { return nil }
            let entries = foodsByDay[date] ?? []
            let fiberValues = entries.compactMap(\.fiber)
            let calories = entries.reduce(0) { $0 + $1.calories }
            let coverage: DayCoverage
            if entries.isEmpty {
                coverage = .missing
            } else if isLikelyComplete(
                logCount: entries.count,
                calories: calories,
                calorieGoal: profile.effectiveCalories
            ) {
                coverage = .likelyComplete
            } else {
                coverage = .partial
            }
            return DailyNutrition(
                date: date,
                calories: calories,
                proteinGrams: entries.reduce(0) { $0 + $1.protein },
                carbsGrams: entries.reduce(0) { $0 + $1.carbs },
                fatGrams: entries.reduce(0) { $0 + $1.fat },
                fiberGrams: fiberValues.isEmpty ? nil : fiberValues.reduce(0, +),
                fiberLogCount: fiberValues.count,
                logCount: entries.count,
                coverage: coverage
            )
        }

        func latestValuePerDay(_ values: [DatedValue]) -> [DatedValue] {
            Dictionary(grouping: values) { calendar.startOfDay(for: $0.date) }
                .values
                .compactMap { dayValues in dayValues.max { $0.date < $1.date } }
                .sorted { $0.date < $1.date }
        }

        let recentWeights = latestValuePerDay(weights
            .filter { $0.date >= firstDay && $0.date < currentEndExclusive }
            .map { DatedValue(date: $0.date, value: $0.weightKg) })
        let recentBodyFat = latestValuePerDay(bodyFatEntries
            .filter { $0.date >= firstDay && $0.date < currentEndExclusive }
            .map { DatedValue(date: $0.date, value: $0.bodyFatPercent) })

        func workoutDateKey(_ session: StrengthWorkoutSession) -> String {
            session.diaryDateKey ?? StrengthWorkoutDate.key(for: session.diaryDate, calendar: calendar)
        }

        func workoutDate(_ session: StrengthWorkoutSession) -> Date {
            StrengthWorkoutDate.date(for: workoutDateKey(session), calendar: calendar)
                ?? calendar.startOfDay(for: session.diaryDate)
        }

        // Workout names, exercises, loads, RPE, and app-estimated calorie burns are intentionally
        // omitted. Burn-only diary records are also excluded so estimates cannot feed back into goals.
        let effectiveSessions = Dictionary(grouping: workoutSessions, by: workoutDateKey)
            .values
            .flatMap { sessions -> [StrengthWorkoutSession] in
                let completed = sessions.filter { $0.caloriesBurned == nil }
                // A calculated-burn row is a whole-day sync snapshot, not another timed session.
                // Prefer the real completed sessions whenever they exist so duration and session
                // count stay truthful. The newest snapshot is only a fallback for days that have
                // no timer/manual completion row.
                guard completed.isEmpty else { return completed }
                let calculated = sessions.filter { $0.caloriesBurned != nil }
                guard !calculated.isEmpty else { return sessions }
                let latest = calculated.max {
                    let leftVersion = $0.healthSyncVersion ?? 0
                    let rightVersion = $1.healthSyncVersion ?? 0
                    if leftVersion == rightVersion { return $0.completedAt < $1.completedAt }
                    return leftVersion < rightVersion
                }
                return latest.map { [$0] } ?? []
            }
        let genuineSessions = effectiveSessions.filter {
            workoutDate($0) >= firstDay
                && workoutDate($0) < currentEndExclusive
                && ($0.durationSeconds > 0 || $0.exerciseCount > 0 || $0.performedSetCount > 0)
        }
        let workoutsByDay = Dictionary(grouping: genuineSessions) {
            calendar.startOfDay(for: workoutDate($0))
        }
        let dailyWorkouts = workoutsByDay.keys.sorted().compactMap { date -> DailyWorkout? in
            guard let sessions = workoutsByDay[date], !sessions.isEmpty else { return nil }
            return DailyWorkout(
                date: date,
                sessionCount: sessions.count,
                durationMinutes: sessions.reduce(0) { $0 + $1.durationMinutes },
                exerciseCount: sessions.reduce(0) { $0 + $1.exerciseCount },
                performedSetCount: sessions.reduce(0) { $0 + $1.performedSetCount },
                repCount: sessions.reduce(0) { $0 + $1.repCount }
            )
        }

        let recentMeasurements = bodyMeasurements
            .filter { $0.date >= firstDay && $0.date < currentEndExclusive && $0.hasAnyValue }
            .sorted { $0.date > $1.date }
            .prefix(12)
            .reversed()
            .map { measurement in
                MeasurementSnapshot(
                    date: measurement.date,
                    neckCm: measurement.neckCm,
                    waistCm: measurement.waistCm,
                    hipsCm: measurement.hipsCm,
                    chestCm: measurement.chestCm,
                    upperArmCm: measurement.upperArmCm,
                    thighCm: measurement.thighCm,
                    calfCm: measurement.calfCm,
                    wristCm: measurement.wristCm,
                    waistToHipRatio: measurement.waistToHipRatio,
                    waistToHeightRatio: measurement.waistToHeightRatio(heightCm: profile.heightCm),
                    estimatedBodyFatPercent: measurement.usNavyBodyFatPercent(
                        gender: profile.gender,
                        heightCm: profile.heightCm
                    )
                )
            }

        let recentEnergy = healthEnergy
            .filter { $0.date >= firstDay && $0.date < endExclusive }
            .sorted { $0.date < $1.date }

        let summaries = [7, 14, 28, safeLookback]
            .filter { $0 <= safeLookback }
            .reduce(into: [Int]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }
            .map { days in
                makeSummary(
                    days: days,
                    dailyNutrition: dailyNutrition
                )
            }

        let signalSummaries = summaries.map { summary in
            makeSignalSummary(
                days: summary.days,
                today: today,
                weights: recentWeights,
                bodyFat: recentBodyFat,
                workouts: dailyWorkouts,
                healthEnergy: recentEnergy,
                calendar: calendar
            )
        }

        let confidence = makeConfidence(
            dailyNutrition: dailyNutrition,
            weights: recentWeights,
            healthEnergy: recentEnergy,
            calendar: calendar
        )

        return GoalEvidence(
            lookbackDays: safeLookback,
            dailyNutrition: dailyNutrition,
            summaries: summaries,
            signalSummaries: signalSummaries,
            weights: recentWeights,
            bodyFat: recentBodyFat,
            workouts: dailyWorkouts,
            bodyMeasurements: Array(recentMeasurements),
            healthEnergy: recentEnergy,
            confidence: confidence,
            timeZone: calendar.timeZone
        )
    }

    func promptSection(profile: UserProfile) -> String {
        var lines: [String] = [
            "GOAL EVIDENCE PACK — privacy-safe aggregates from the last \(lookbackDays) completed nutrition days; point-in-time measurements and completed workouts may also include today.",
            "No food names, notes, photos, ingredients, meal text, workout names, loads, or RPE are included.",
            "Diary completeness is a heuristic: likely_complete means at least 85% of the current calorie target, or at least 2 logs and at least 65% (minimum 800 kcal); likely_partial/missing days must NOT be treated as true low intake.",
            "Overall evidence confidence: \(confidence.level.rawValue) (\(confidence.score)/100). \(confidence.reasons.joined(separator: "; "))",
            "",
            "WINDOW SUMMARIES:"
        ]

        for summary in summaries {
            let calories = summary.averageCaloriesOnLoggedDays.map(String.init) ?? "n/a"
            let completeCalories = summary.averageCaloriesOnLikelyCompleteDays.map(String.init) ?? "n/a"
            let protein = formatted(summary.averageProteinOnLoggedDays)
            let carbs = formatted(summary.averageCarbsOnLoggedDays)
            let fat = formatted(summary.averageFatOnLoggedDays)
            let fiber = formatted(summary.averageFiberOnMeasuredDays)
            lines.append("- \(summary.days)d: logged \(summary.loggedDays)/\(summary.days), likely complete \(summary.likelyCompleteDays)/\(summary.days), avg all logged-day kcal \(calories), avg likely-complete-day kcal \(completeCalories), avg logged P/C/F/fiber \(protein)/\(carbs)/\(fat)/\(fiber) g")
        }

        lines.append("")
        lines.append("OTHER SIGNAL PERIOD SUMMARIES:")
        for summary in signalSummaries {
            let active = summary.averageActiveCalories.map(String.init) ?? "n/a"
            let total = summary.averageTotalCalories.map(String.init) ?? "n/a"
            let weightChange = summary.weightChangeKg.map { String(format: "%+.2f kg", $0) } ?? "n/a"
            let weightSpan = summary.weightSpanDays.map { "\($0)d" } ?? "n/a"
            lines.append("- \(summary.days)d: weigh-ins \(summary.weightReadings), weight span \(weightSpan), weight change \(weightChange), body-fat readings \(summary.bodyFatReadings), workouts \(summary.workoutSessions) (\(summary.workoutMinutes) min), measured-energy days \(summary.healthEnergyDays), avg active/total \(active)/\(total) kcal")
        }

        lines.append("")
        lines.append("DAILY NUTRITION (aggregated logged-day totals only; omitted dates are missing/unlogged and have unknown intake, NOT zero intake):")
        let loggedNutrition = dailyNutrition.filter { $0.coverage != .missing }
        let nutritionDetail = loggedNutrition.suffix(45)
        if loggedNutrition.count > nutritionDetail.count {
            lines.append("- \(loggedNutrition.count - nutritionDetail.count) older logged-day rows omitted; the 90-day summaries above still include them.")
        }
        for day in nutritionDetail {
            let fiber = day.fiberGrams.map { "\(oneDecimal($0))g (known in \(day.fiberLogCount)/\(day.logCount) logs)" } ?? "unknown"
            lines.append("- \(dayString(day.date)): logged kcal \(day.calories), P \(oneDecimal(day.proteinGrams))g, C \(oneDecimal(day.carbsGrams))g, F \(oneDecimal(day.fatGrams))g, fiber \(fiber), logs \(day.logCount), coverage \(day.coverage.rawValue)")
        }

        lines.append("")
        lines.append("DATED WEIGHT (kg): \(datedValues(weights, suffix: ""))")
        lines.append("DATED BODY FAT (%): \(datedValues(bodyFat, suffix: ""))")

        lines.append("")
        lines.append("WORKOUT HISTORY (aggregate only; app-estimated burn is excluded):")
        if workouts.isEmpty {
            lines.append("- none")
        } else {
            let workoutDetail = workouts.suffix(30)
            if workouts.count > workoutDetail.count {
                lines.append("- \(workouts.count - workoutDetail.count) older workout-day rows omitted; period summaries above still include them.")
            }
            for workout in workoutDetail {
                lines.append("- \(dayString(workout.date)): sessions \(workout.sessionCount), duration \(workout.durationMinutes) min, exercises \(workout.exerciseCount), performed sets \(workout.performedSetCount), reps \(workout.repCount)")
            }
        }

        lines.append("")
        lines.append("BODY MEASUREMENT SNAPSHOTS (cm; unchanged sites may be carried forward from the previous snapshot, so compare values rather than treating every field as newly measured; US-Navy body fat is only a rough estimate):")
        if bodyMeasurements.isEmpty {
            lines.append("- none")
        } else {
            for measurement in bodyMeasurements {
                var values: [String] = []
                appendMeasurement("neck", measurement.neckCm, to: &values)
                appendMeasurement("waist", measurement.waistCm, to: &values)
                appendMeasurement("hips", measurement.hipsCm, to: &values)
                appendMeasurement("chest", measurement.chestCm, to: &values)
                appendMeasurement("upper_arm", measurement.upperArmCm, to: &values)
                appendMeasurement("thigh", measurement.thighCm, to: &values)
                appendMeasurement("calf", measurement.calfCm, to: &values)
                appendMeasurement("wrist", measurement.wristCm, to: &values)
                if let ratio = measurement.waistToHipRatio { values.append("waist/hip \(twoDecimals(ratio))") }
                if let ratio = measurement.waistToHeightRatio { values.append("waist/height \(twoDecimals(ratio))") }
                if let estimate = measurement.estimatedBodyFatPercent { values.append("Navy BF ~\(oneDecimal(estimate))%") }
                lines.append("- \(dayString(measurement.date)): \(values.joined(separator: ", "))")
            }
        }

        if !healthEnergy.isEmpty {
            lines.append("")
            lines.append("DAILY MEASURED APPLE HEALTH ENERGY (kcal; app-estimated workout samples are excluded):")
            for day in healthEnergy {
                let basal = day.basalCalories.map(String.init) ?? "unavailable"
                let total = day.totalCalories.map(String.init) ?? "unavailable"
                lines.append("- \(dayString(day.date)): active \(day.activeCalories), basal \(basal), total \(total)")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func makeSummary(
        days: Int,
        dailyNutrition: [DailyNutrition]
    ) -> WindowSummary {
        let nutrition = Array(dailyNutrition.suffix(days))
        let logged = nutrition.filter { $0.logCount > 0 }
        let likelyComplete = nutrition.filter { $0.coverage == .likelyComplete }
        let measuredFiber = logged.compactMap(\.fiberGrams)

        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }

        return WindowSummary(
            days: days,
            loggedDays: logged.count,
            likelyCompleteDays: likelyComplete.count,
            averageCaloriesOnLoggedDays: logged.isEmpty ? nil : logged.reduce(0) { $0 + $1.calories } / logged.count,
            averageCaloriesOnLikelyCompleteDays: likelyComplete.isEmpty
                ? nil
                : likelyComplete.reduce(0) { $0 + $1.calories } / likelyComplete.count,
            averageProteinOnLoggedDays: average(logged.map(\.proteinGrams)),
            averageCarbsOnLoggedDays: average(logged.map(\.carbsGrams)),
            averageFatOnLoggedDays: average(logged.map(\.fatGrams)),
            averageFiberOnMeasuredDays: average(measuredFiber)
        )
    }

    private static func makeSignalSummary(
        days: Int,
        today: Date,
        weights: [DatedValue],
        bodyFat: [DatedValue],
        workouts: [DailyWorkout],
        healthEnergy: [HealthEnergyDay],
        calendar: Calendar
    ) -> SignalSummary {
        // Summaries cover exactly N completed calendar days. Today's point-in-time
        // measurements/workouts still appear in the dated detail sections below, but mixing them
        // into a completed-day energy window would make an advertised 7-day summary span 8 dates.
        let start = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        let periodWeights = weights.filter { $0.date >= start && $0.date < today }
        let periodBodyFat = bodyFat.filter { $0.date >= start && $0.date < today }
        let periodWorkouts = workouts.filter { $0.date >= start && $0.date < today }
        let periodEnergy = healthEnergy.filter { $0.date >= start && $0.date < today }
        let totalValues = periodEnergy.compactMap(\.totalCalories)
        let weightSpanDays = periodWeights.count >= 2
            ? calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: periodWeights.first?.date ?? today),
                to: calendar.startOfDay(for: periodWeights.last?.date ?? today)
            ).day
            : nil
        return SignalSummary(
            days: days,
            weightReadings: periodWeights.count,
            weightSpanDays: weightSpanDays,
            bodyFatReadings: periodBodyFat.count,
            workoutSessions: periodWorkouts.reduce(0) { $0 + $1.sessionCount },
            workoutMinutes: periodWorkouts.reduce(0) { $0 + $1.durationMinutes },
            healthEnergyDays: periodEnergy.count,
            averageActiveCalories: periodEnergy.isEmpty
                ? nil
                : periodEnergy.reduce(0) { $0 + $1.activeCalories } / periodEnergy.count,
            averageTotalCalories: totalValues.count < 3
                ? nil
                : totalValues.reduce(0, +) / totalValues.count,
            weightChangeKg: periodWeights.count >= 2
                ? (periodWeights.last?.value ?? 0) - (periodWeights.first?.value ?? 0)
                : nil
        )
    }

    private static func makeConfidence(
        dailyNutrition: [DailyNutrition],
        weights: [DatedValue],
        healthEnergy: [HealthEnergyDay],
        calendar: Calendar
    ) -> Confidence {
        let recent = Array(dailyNutrition.suffix(min(28, dailyNutrition.count)))
        let completeDays = recent.filter { $0.coverage == .likelyComplete }.count
        let nutritionScore = Int(
            (Double(completeDays) / Double(max(1, recent.count)) * 55).rounded()
        )
        let sortedWeights = weights.sorted { $0.date < $1.date }
        let weightSpan = sortedWeights.count >= 2
            ? max(0, calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: sortedWeights.first?.date ?? .now),
                to: calendar.startOfDay(for: sortedWeights.last?.date ?? .now)
            ).day ?? 0)
            : 0
        let weightScore: Int
        if sortedWeights.count >= 6, weightSpan >= 28 {
            weightScore = 25
        } else if sortedWeights.count >= 3, weightSpan >= 14 {
            weightScore = 18
        } else if sortedWeights.count >= 2 {
            weightScore = 10
        } else {
            weightScore = 0
        }
        let energyScore: Int
        if healthEnergy.count >= 10 {
            energyScore = 20
        } else if healthEnergy.count >= 5 {
            energyScore = 12
        } else if healthEnergy.count >= 3 {
            energyScore = 7
        } else {
            energyScore = 0
        }
        let score = min(100, nutritionScore + weightScore + energyScore)
        let level: Confidence.Level = score >= 70 ? .high : (score >= 40 ? .medium : .low)
        let reasons = [
            "\(completeDays)/\(recent.count) likely-complete nutrition days in the latest 28-day window",
            "\(sortedWeights.count) weigh-ins spanning \(weightSpan) days",
            "\(healthEnergy.count) measured Apple Health energy days"
        ]
        return Confidence(level: level, score: score, reasons: reasons)
    }

    private static func isLikelyComplete(logCount: Int, calories: Int, calorieGoal: Int) -> Bool {
        let goal = max(calorieGoal, 800)
        return calories >= Int((Double(goal) * 0.85).rounded())
            || (logCount >= 2 && calories >= max(800, Int((Double(goal) * 0.65).rounded())))
    }

    private func datedValues(_ values: [DatedValue], suffix: String) -> String {
        guard !values.isEmpty else { return "none" }
        let detail = values.suffix(30)
        let omitted = values.count - detail.count
        let prefix = omitted > 0 ? "\(omitted) older daily values omitted; " : ""
        return prefix + detail.map { "\(dayString($0.date)) \(oneDecimal($0.value))\(suffix)" }.joined(separator: ", ")
    }

    private func formatted(_ value: Double?) -> String {
        value.map(oneDecimal) ?? "n/a"
    }

    private func dayString(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private func twoDecimals(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func appendMeasurement(_ name: String, _ value: Double?, to values: inout [String]) {
        if let value { values.append("\(name) \(oneDecimal(value))") }
    }

}
