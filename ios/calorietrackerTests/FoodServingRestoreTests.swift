import Foundation
import Testing
@testable import calorietracker

struct FoodServingRestoreTests {
    @Test func unknownServingUsesOneServingWithoutInventingGrams() {
        let entry = FoodEntry(
            name: "Recovered meal",
            calories: 420,
            protein: 30,
            carbs: 45,
            fat: 12,
            source: .manual
        )

        #expect(!entry.hasKnownServingSize)
        #expect(entry.reviewServingReference == 1)
        #expect(entry.reviewSelectedServingUnit == "serving")
        #expect(entry.reviewSelectedServingQuantity == 1)
        #expect(entry.reviewServingUnitOptions == [.loggedServing(quantity: 1)])

        let duplicated = entry.duplicatedForLogging(at: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(duplicated.servingSizeGrams == nil)
    }

    @Test func knownServingKeepsExactAmountAndUnit() {
        let option = ServingUnitOption(unit: "slice", gramsPerUnit: 60, quantity: 2)
        let entry = FoodEntry(
            name: "Pizza",
            calories: 480,
            protein: 20,
            carbs: 64,
            fat: 16,
            source: .manual,
            servingSizeGrams: 120,
            servingUnitOptions: [option],
            selectedServingUnit: "slice",
            selectedServingQuantity: 2
        )

        #expect(entry.hasKnownServingSize)
        #expect(entry.reviewServingReference == 120)
        #expect(entry.reviewServingUnitOptions == [option])
        #expect(entry.reviewSelectedServingUnit == "slice")
        #expect(entry.reviewSelectedServingQuantity == 2)
    }

    @Test func healthMetadataRoundTripsServingDetails() throws {
        let option = ServingUnitOption(unit: "cup", gramsPerUnit: 180, quantity: 1.5)
        let entry = FoodEntry(
            name: "Rice",
            calories: 390,
            protein: 8,
            carbs: 84,
            fat: 1,
            source: .manual,
            servingSizeGrams: 270,
            servingUnitOptions: [option],
            selectedServingUnit: "cup",
            selectedServingQuantity: 1.5
        )

        let decoded = try #require(
            HealthFoodServingMetadata.decode(from: HealthFoodServingMetadata(entry: entry).dictionary)
        )
        #expect(decoded.servingSizeGrams == 270)
        #expect(decoded.servingUnitOptions == [option])
        #expect(decoded.selectedServingUnit == "cup")
        #expect(decoded.selectedServingQuantity == 1.5)
    }

    @Test func sharedMealRoundTripsServingOptions() throws {
        let option = ServingUnitOption(unit: "piece", gramsPerUnit: 75, quantity: 2)
        let entry = FoodEntry(
            name: "Falafel",
            calories: 300,
            protein: 12,
            carbs: 30,
            fat: 14,
            source: .manual,
            servingSizeGrams: 150,
            servingUnitOptions: [option],
            selectedServingUnit: "piece",
            selectedServingQuantity: 2
        )

        let link = try #require(MealShare.link(for: [entry]))
        let imported = try #require(MealShare.meals(from: link)?.first)
        #expect(imported.servingSizeGrams == 150)
        #expect(imported.servingUnitOptions == [option])
        #expect(imported.selectedServingUnit == "piece")
        #expect(imported.selectedServingQuantity == 2)
    }
}
