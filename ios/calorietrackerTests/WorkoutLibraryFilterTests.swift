import Foundation
import Testing
@testable import calorietracker

@MainActor
struct WorkoutLibraryFilterTests {
    @Test func fullBodyUsesIndividualCatalogBodyParts() {
        let groups = StrengthWorkoutSplitGroup.selectionGroups(
            for: .fullBody,
            availablePrimaryMuscles: ["Chest", "Biceps"],
            availableSecondaryMuscles: ["Triceps", "Chest"]
        )

        #expect(groups.map(\.title) == ["Biceps", "Chest", "Triceps"])
        #expect(groups.allSatisfy { $0.muscles == [$0.title] })
    }

    @Test func configuredSplitUsesItsTrainingGroups() {
        let groups = StrengthWorkoutSplitGroup.selectionGroups(
            for: .pushPullLegs,
            availablePrimaryMuscles: ["Chest", "Lats", "Quadriceps", "Abdominals"],
            availableSecondaryMuscles: ["Shoulders", "Biceps", "Hamstrings"]
        )

        #expect(groups.map(\.title) == ["Push", "Pull", "Legs", "Core"])
        #expect(groups.first(where: { $0.title == "Push" })?.muscles == ["Chest", "Shoulders"])
        #expect(groups.first(where: { $0.title == "Pull" })?.muscles == ["Biceps", "Lats"])
    }

    @Test func legacyFilterStateDecodesWithoutSplitFields() throws {
        let legacyJSON = #"{"searchText":"bench","levels":["Intermediate"],"rawEquipment":["Barbell"],"primaryMuscles":[],"secondaryMuscles":[],"forces":[],"mechanics":[],"categories":[],"sort":"Name"}"#
        let state = try JSONDecoder().decode(ExerciseFilterState.self, from: Data(legacyJSON.utf8))

        #expect(state.searchText == "bench")
        #expect(state.levels == ["Intermediate"])
        #expect(state.rawEquipment == ["Barbell"])
        #expect(state.splitIdentifier == nil)
        #expect(state.splitGroups.isEmpty)
    }

    @Test func filterStateRoundTripsSplitContext() throws {
        let expected = ExerciseFilterState(
            searchText: "press",
            splitIdentifier: StrengthWorkoutSplit.pushPullLegs.rawValue,
            splitGroups: ["Push"],
            levels: ["Intermediate"],
            sort: .level
        )

        let data = try JSONEncoder().encode(expected)
        let restored = try JSONDecoder().decode(ExerciseFilterState.self, from: data)

        #expect(restored == expected)
    }
}
