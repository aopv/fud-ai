import Foundation
import Testing
@testable import calorietracker

/// Tests the cross-process food-log store that App Intents (Siri/Shortcuts) and
/// the Watch voice round-trip write to. These tests touch the real
/// `UserDefaults.standard` "foodEntries" key, so each one snapshots and restores
/// that key. The suite is serialized to avoid clobbering shared state.
@Suite(.serialized)
struct FoodEntryStorageTests {

    private static let key = "foodEntries"

    /// Run `body` with a clean foodEntries store, restoring whatever was there before.
    private func withCleanStore(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let saved = defaults.data(forKey: Self.key)
        defaults.removeObject(forKey: Self.key)
        defer {
            if let saved { defaults.set(saved, forKey: Self.key) }
            else { defaults.removeObject(forKey: Self.key) }
        }
        body()
    }

    private func makeEntry(
        name: String,
        calories: Int,
        protein: Double,
        timestamp: Date = Date()
    ) -> FoodEntry {
        FoodEntry(
            name: name,
            calories: calories,
            protein: protein,
            carbs: 0,
            fat: 0,
            timestamp: timestamp,
            source: .textInput,
            mealType: .other
        )
    }

    @Test func appendAddsExactlyOneEntry() {
        withCleanStore {
            #expect(FoodEntryStorage.loadAll().isEmpty)
            FoodEntryStorage.append(makeEntry(name: "Apple", calories: 95, protein: 0.5))
            let all = FoodEntryStorage.loadAll()
            #expect(all.count == 1)
            #expect(all.first?.name == "Apple")
            #expect(all.first?.calories == 95)
        }
    }

    @Test func appendRoundTripsAllFields() {
        withCleanStore {
            let entry = makeEntry(name: "Oatmeal", calories: 150, protein: 5.5)
            FoodEntryStorage.append(entry)
            let loaded = FoodEntryStorage.loadAll().first
            #expect(loaded?.id == entry.id)
            #expect(loaded?.protein == 5.5)
            #expect(loaded?.source == .textInput)
        }
    }

    @Test func multipleAppendsAccumulate() {
        withCleanStore {
            FoodEntryStorage.append(makeEntry(name: "A", calories: 100, protein: 1))
            FoodEntryStorage.append(makeEntry(name: "B", calories: 200, protein: 2))
            FoodEntryStorage.append(makeEntry(name: "C", calories: 300, protein: 3))
            let names = FoodEntryStorage.loadAll().map(\.name).sorted()
            #expect(names == ["A", "B", "C"])
        }
    }

    @Test func todayCaloriesSumsOnlyTodayEntries() {
        withCleanStore {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            FoodEntryStorage.append(makeEntry(name: "Today1", calories: 100, protein: 0))
            FoodEntryStorage.append(makeEntry(name: "Today2", calories: 250, protein: 0))
            FoodEntryStorage.append(makeEntry(name: "Old", calories: 999, protein: 0, timestamp: yesterday))
            #expect(FoodEntryStorage.todayCalories() == 350)
        }
    }

    @Test func todayProteinSumsOnlyTodayEntries() {
        withCleanStore {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            FoodEntryStorage.append(makeEntry(name: "Today", calories: 0, protein: 12.5))
            FoodEntryStorage.append(makeEntry(name: "Old", calories: 0, protein: 88, timestamp: yesterday))
            #expect(abs(FoodEntryStorage.todayProtein() - 12.5) < 0.0001)
        }
    }

    @Test func emptyStoreReportsZeroTotals() {
        withCleanStore {
            #expect(FoodEntryStorage.todayCalories() == 0)
            #expect(FoodEntryStorage.todayProtein() == 0)
        }
    }
}
