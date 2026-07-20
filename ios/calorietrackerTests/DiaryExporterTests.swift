import Foundation
import Testing
@testable import calorietracker

struct DiaryExporterTests {
    private let nutrientFields = [
        "sugar_g", "added_sugar_g", "fiber_g", "saturated_fat_g",
        "monounsaturated_fat_g", "polyunsaturated_fat_g", "cholesterol_mg",
        "sodium_mg", "potassium_mg", "trans_fat_g", "calcium_mg", "iron_mg",
        "magnesium_mg", "zinc_mg", "vitamin_a_mcg", "vitamin_c_mg",
        "vitamin_d_mcg", "vitamin_b12_mcg", "vitamin_e_mg", "vitamin_k_mcg",
        "folate_mcg", "omega3_g"
    ]

    @Test func jsonIncludesEveryStoredNutrient() throws {
        let fixture = makeFixture()
        let export = try #require(DiaryExporter.build(
            from: fixture.date,
            to: fixture.date,
            format: .json,
            entries: [fixture.entry],
            profile: makeProfile()
        ))

        let root = try #require(JSONSerialization.jsonObject(with: export.data) as? [String: Any])
        let metadata = try #require(root["export"] as? [String: Any])
        #expect(metadata["format_version"] as? String == "1.1")
        let days = try #require(root["days"] as? [[String: Any]])
        let meals = try #require(days.first?["meals"] as? [[String: Any]])
        let items = try #require(meals.first?["items"] as? [[String: Any]])
        let item = try #require(items.first)

        for field in nutrientFields {
            #expect(item[field] != nil, "Missing JSON nutrient field: \(field)")
        }
        #expect(item["fiber_g"] as? Double == 3.3)
        #expect(item["sodium_mg"] as? Double == 8.8)
        #expect(item["vitamin_b12_mcg"] as? Double == 18.8)
    }

    @Test func csvAndMarkdownIncludeEveryStoredNutrient() throws {
        let fixture = makeFixture()
        let csvExport = try #require(DiaryExporter.build(
            from: fixture.date,
            to: fixture.date,
            format: .csv,
            entries: [fixture.entry],
            profile: makeProfile()
        ))
        let csv = String(decoding: csvExport.data, as: UTF8.self)
        let lines = csv.split(separator: "\n").map(String.init)
        let headers = try #require(lines.first?.split(separator: ",").map(String.init))
        let values = try #require(lines.dropFirst().first?.split(separator: ",", omittingEmptySubsequences: false).map(String.init))
        #expect(headers.count == values.count)
        for field in nutrientFields {
            #expect(headers.contains(field), "Missing CSV nutrient column: \(field)")
        }
        let fiberIndex = try #require(headers.firstIndex(of: "fiber_g"))
        #expect(values[fiberIndex] == "3.3")

        let markdownExport = try #require(DiaryExporter.build(
            from: fixture.date,
            to: fixture.date,
            format: .markdown,
            entries: [fixture.entry],
            profile: makeProfile()
        ))
        let markdown = String(decoding: markdownExport.data, as: UTF8.self)
        for heading in ["Fiber (g)", "Sodium (mg)", "Vitamin A (mcg)", "Vitamin B12 (mcg)", "Omega-3 (g)"] {
            #expect(markdown.contains(heading), "Missing Markdown nutrient heading: \(heading)")
        }
    }

    private func makeFixture() -> (date: Date, entry: FoodEntry) {
        let date = Date(timeIntervalSince1970: 1_752_840_000)
        let entry = FoodEntry(
            name: "Nutrient fixture",
            calories: 120,
            protein: 4.4,
            carbs: 5.5,
            fat: 6.6,
            timestamp: date,
            source: .manual,
            mealType: .lunch,
            sugar: 1.1,
            addedSugar: 2.2,
            fiber: 3.3,
            saturatedFat: 4.4,
            monounsaturatedFat: 5.5,
            polyunsaturatedFat: 6.6,
            cholesterol: 7.7,
            sodium: 8.8,
            potassium: 9.9,
            transFat: 10.1,
            calcium: 11.1,
            iron: 12.2,
            magnesium: 13.3,
            zinc: 14.4,
            vitaminA: 15.5,
            vitaminC: 16.6,
            vitaminD: 17.7,
            vitaminB12: 18.8,
            vitaminE: 19.9,
            vitaminK: 20.1,
            folate: 21.2,
            omega3: 22.3,
            servingSizeGrams: 100
        )
        return (date, entry)
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            name: "Exporter",
            gender: .male,
            birthday: Date(timeIntervalSince1970: 0),
            heightCm: 175,
            weightKg: 70,
            activityLevel: .moderate,
            goal: .maintain,
            bodyFatPercentage: nil,
            goalBodyFatPercentage: nil,
            useBodyFatInBMR: nil,
            weeklyChangeKg: nil,
            goalWeightKg: nil,
            customCalories: 2_000,
            customProtein: 120,
            customFat: 60,
            customCarbs: 200,
            autoBalanceMacro: nil
        )
    }
}
