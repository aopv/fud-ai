import Foundation
import Testing
@testable import calorietracker

struct GoalEvidenceTests {
    @Test func evidenceUsesNinetyCompletedCalendarDaysAndExcludesToday() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let oldDate = try #require(calendar.date(byAdding: .day, value: -100, to: now))
        var profile = UserProfile.default
        profile.customCalories = 2_000

        let foods = [
            food(name: "Private breakfast name", note: "private note", calories: 700, fiber: 8, at: yesterday),
            food(name: "Private dinner name", note: "another secret", calories: 650, fiber: nil, at: yesterday),
            food(name: "Today's unfinished log", note: nil, calories: 1_900, fiber: 12, at: now),
            food(name: "Ancient private meal", note: nil, calories: 900, fiber: 3, at: oldDate),
        ]

        let evidence = GoalEvidence.build(
            foods: foods,
            weights: [],
            bodyFatEntries: [],
            workoutSessions: [],
            bodyMeasurements: [],
            healthEnergy: [],
            profile: profile,
            now: now,
            calendar: calendar
        )

        #expect(evidence.dailyNutrition.count == 90)
        #expect(evidence.dailyNutrition.filter { $0.coverage == .missing }.count == 89)
        #expect(evidence.dailyNutrition.last?.coverage == .likelyComplete)
        #expect(evidence.dailyNutrition.last?.fiberGrams == 8)
        #expect(evidence.dailyNutrition.last?.fiberLogCount == 1)
        #expect(evidence.dailyNutrition.allSatisfy { $0.date < calendar.startOfDay(for: now) })
        #expect(evidence.summaries.first { $0.days == 7 }?.loggedDays == 1)
        #expect(evidence.summaries.first { $0.days == 7 }?.likelyCompleteDays == 1)
    }

    @Test func promptContainsOnlyAggregatesAndExcludesPrivateFoodAndWorkoutDetails() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12)))
        let historyDate = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let foodEntry = food(
            name: "Sensitive family recipe",
            note: "Contains a private medication note",
            calories: 1_400,
            fiber: 20,
            at: historyDate
        )
        let workout = StrengthWorkoutSession(
            diaryDate: try #require(calendar.date(byAdding: .day, value: -2, to: now)),
            startedAt: now,
            completedAt: now,
            durationSeconds: 1_800,
            exercises: [],
            caloriesBurned: 4_321
        )
        let evidence = GoalEvidence.build(
            foods: [foodEntry],
            weights: [WeightEntry(date: historyDate, weightKg: 70.2)],
            bodyFatEntries: [BodyFatEntry(date: historyDate, bodyFatFraction: 0.18)],
            workoutSessions: [workout],
            bodyMeasurements: [BodyMeasurement(date: historyDate, waistCm: 80)],
            healthEnergy: [HealthEnergyDay(date: historyDate, activeCalories: 500, basalCalories: 1_600)],
            profile: .default,
            now: now,
            calendar: calendar
        )
        let prompt = evidence.promptSection(profile: .default)

        #expect(prompt.contains("logged kcal 1400"))
        #expect(prompt.contains("unknown intake, NOT zero intake"))
        #expect(prompt.contains("sessions 1"))
        #expect(prompt.contains("active 500, basal 1600, total 2100"))
        #expect(!prompt.contains("Sensitive family recipe"))
        #expect(!prompt.contains("private medication"))
        #expect(!prompt.contains("4321"))
        #expect(!prompt.contains(foodEntry.id.uuidString))
        #expect(prompt.contains("unchanged sites may be carried forward"))
        #expect(prompt.contains("weight span"))
    }

    @Test func genuineTimerRowsTakePrecedenceAndTodayIsIncluded() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12)))
        let diaryDate = calendar.startOfDay(for: now)
        let timerRow = StrengthWorkoutSession(
            diaryDate: diaryDate,
            startedAt: now,
            completedAt: now.addingTimeInterval(600),
            durationSeconds: 600,
            exercises: []
        )
        var calculatedSnapshot = StrengthWorkoutSession(
            diaryDate: diaryDate,
            startedAt: now,
            completedAt: now.addingTimeInterval(1_800),
            durationSeconds: 0,
            exercises: [],
            caloriesBurned: 500
        )
        calculatedSnapshot.healthSyncVersion = 2

        let evidence = GoalEvidence.build(
            foods: [],
            weights: [WeightEntry(date: now, weightKg: 70)],
            bodyFatEntries: [BodyFatEntry(date: now, bodyFatFraction: 0.18)],
            workoutSessions: [timerRow, calculatedSnapshot],
            bodyMeasurements: [],
            healthEnergy: [],
            profile: .default,
            now: now,
            calendar: calendar
        )

        #expect(evidence.workouts.count == 1)
        #expect(evidence.workouts.first?.sessionCount == 1)
        #expect(evidence.workouts.first?.durationMinutes == 10)
        #expect(evidence.weights.count == 1)
        #expect(evidence.bodyFat.count == 1)
    }

    @Test func knownBodyFatAutomaticallyUsesKatchAndProteinUsesFullBodyweightRates() {
        var profile = UserProfile.default
        profile.weightKg = 70
        profile.heightCm = 175
        profile.bodyFatPercentage = 0.50
        profile.useBodyFatInBMR = false
        profile.activityLevel = .moderate
        profile.goal = .maintain

        #expect(profile.usesBodyFatForBMR)
        #expect(abs(profile.bmr - (370 + 21.6 * 0.50 * 70)) < 0.001)
        #expect(profile.proteinGoal == 112)

        profile.bodyFatPercentage = nil
        #expect(!profile.usesBodyFatForBMR)
        #expect(profile.proteinGoal == 112)
    }

    @Test func totalEnergySignalNeedsThreeTotalDays() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12)))
        let energy = try (1...3).map { offset in
            let date = try #require(calendar.date(byAdding: .day, value: -offset, to: now))
            return HealthEnergyDay(
                date: date,
                activeCalories: 400 + offset * 10,
                basalCalories: offset == 1 ? 1_600 : nil
            )
        }
        let evidence = GoalEvidence.build(
            foods: [],
            weights: [],
            bodyFatEntries: [],
            workoutSessions: [],
            bodyMeasurements: [],
            healthEnergy: energy,
            profile: .default,
            now: now,
            calendar: calendar
        )

        let week = try #require(evidence.signalSummaries.first { $0.days == 7 })
        #expect(week.healthEnergyDays == 3)
        #expect(week.averageActiveCalories == 420)
        #expect(week.averageTotalCalories == nil)
    }

    @Test func empiricalForecastExcludesTodaysIncompleteDiary() throws {
        let calendar = utcCalendar
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 12)))
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: now))
        let twoDaysAgo = try #require(calendar.date(byAdding: .day, value: -2, to: now))
        var profile = UserProfile.default
        profile.customCalories = 2_000
        let forecast = WeightAnalysisService.compute(
            weights: [
                WeightEntry(date: twoDaysAgo, weightKg: 70.5),
                WeightEntry(date: yesterday, weightKg: 70.4),
                WeightEntry(date: now, weightKg: 70.3),
            ],
            foods: [
                food(name: "day one", note: nil, calories: 1_400, fiber: nil, at: twoDaysAgo),
                food(name: "day two", note: nil, calories: 1_600, fiber: nil, at: yesterday),
                food(name: "today partial", note: nil, calories: 300, fiber: nil, at: now),
            ],
            profile: profile,
            now: now,
            calendar: calendar
        )

        #expect(forecast.avgDailyCalories == 1_500)
        #expect(forecast.daysOfFoodData == 2)
        #expect(forecast.weightEntriesUsed == 3)
        #expect(forecast.hasEnoughData)
    }

    @Test func formulaAndHealthEnergyAggregationStayConsistent() {
        var profile = UserProfile.default
        profile.goal = .lose
        profile.weeklyChangeKg = 0.5
        #expect(profile.calorieAdjustment == -550)

        let history = [
            HealthEnergyDay(date: .now, activeCalories: 400, basalCalories: 1_600),
            HealthEnergyDay(date: .now, activeCalories: 500, basalCalories: 1_600),
            HealthEnergyDay(date: .now, activeCalories: 600, basalCalories: 1_600),
        ]
        let summary = HealthKitManager.energySummary(from: history, requestedDays: 14)
        #expect(summary?.activeAverageCalories == 500)
        #expect(summary?.basalAverageCalories == 1_600)
        #expect(summary?.totalAverageCalories == 2_100)

        let basalOnly = [
            HealthEnergyDay(date: .now, activeCalories: 0, basalCalories: 1_600),
            HealthEnergyDay(date: .now, activeCalories: 0, basalCalories: 1_650),
            HealthEnergyDay(date: .now, activeCalories: 0, basalCalories: 1_700),
        ]
        #expect(HealthKitManager.energySummary(from: basalOnly, requestedDays: 14) == nil)
    }

    @Test func goalParserRequiresEveryMacroAndNormalizesExactEnergy() throws {
        var missingMacroThrew = false
        do {
            _ = try GeminiService.parseGoalCalculation(
                from: #"{"calories":2000,"protein":150,"carbs":200}"#
            )
        } catch {
            missingMacroThrew = true
        }
        #expect(missingMacroThrew)

        let normalized = try GeminiService.parseGoalCalculation(
            from: #"{"calories":2000,"protein":150,"carbs":215,"fat":61,"reason":"test"}"#
        )
        #expect(normalized.calories == 2_000)
        #expect(normalized.protein == 150)
        #expect(normalized.fat == 60)
        #expect(normalized.carbs == 215)
        #expect(normalized.protein * 4 + normalized.carbs * 4 + normalized.fat * 9 == normalized.calories)

        #expect(throws: (any Error).self) {
            try GeminiService.parseGoalCalculation(
                from: #"{"calories":800,"protein":500,"carbs":1200,"fat":400}"#
            )
        }
        #expect(throws: (any Error).self) {
            try GeminiService.parseGoalCalculation(
                from: #"{"calories":2000,"protein":0,"carbs":500,"fat":0}"#
            )
        }
        #expect(throws: (any Error).self) {
            try GeminiService.parseGoalCalculation(
                from: #"{"calories":800,"protein":200,"carbs":0,"fat":10}"#
            )
        }
        #expect(throws: (any Error).self) {
            try GeminiService.parseGoalCalculation(
                from: #"{"calories":2000,"protein":300,"carbs":110,"fat":40}"#,
                profile: .default
            )
        }
        #expect(throws: (any Error).self) {
            try GeminiService.parseGoalCalculation(
                from: #"{"calories":6000,"protein":112,"carbs":1289,"fat":44}"#,
                profile: .default
            )
        }

        let oddCalories = try GeminiService.parseGoalCalculation(
            from: #"{"calories":801,"protein":70,"carbs":29,"fat":45}"#
        )
        #expect(oddCalories.protein * 4 + oddCalories.carbs * 4 + oddCalories.fat * 9 == 801)
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func food(
        name: String,
        note: String?,
        calories: Int,
        fiber: Double?,
        at timestamp: Date
    ) -> FoodEntry {
        FoodEntry(
            name: name,
            calories: calories,
            protein: 40,
            carbs: 80,
            fat: 30,
            timestamp: timestamp,
            source: .manual,
            fiber: fiber,
            customNote: note,
            ingredients: [MealIngredient(name: "Secret ingredient", grams: 10, calories: 20, protein: 1, carbs: 2, fat: 1)]
        )
    }
}
