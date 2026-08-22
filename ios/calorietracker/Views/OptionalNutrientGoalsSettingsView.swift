import SwiftUI

struct OptionalNutrientGoalsSettingsView: View {
    let profile: UserProfile

    @AppStorage(OptionalNutrientGoals.storageKey) private var storedGoalsData = Data()
    @State private var goals: OptionalNutrientGoals = .current
    @State private var editingNutrient: OptionalNutrient?

    var body: some View {
        List {
            Section {
                ForEach(OptionalNutrient.allCases) { nutrient in
                    Button {
                        editingNutrient = nutrient
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: nutrient.iconName)
                                .foregroundStyle(NeoAppColors.cobalt)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(nutrient.displayName)
                                    .foregroundStyle(.primary)
                                Text(nutrient.localizedGoalStyle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(goals.goal(for: nutrient)) \(nutrient.unit)")
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                                .foregroundStyle(NeoAppColors.cobalt)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                NeoSectionBanner(title: "Other Nutrients", detail: "Daily targets", style: .cobalt)
            } footer: {
                Text("Separate from calorie, protein, carb, and fat goals.")
            }
            .neoListRow()
        }
        .listStyle(.plain)
        .listSectionSpacing(NeoAppMetrics.sectionSpacing)
        .scrollContentBackground(.hidden)
        .background(NeoAppColors.canvas)
        .tint(NeoAppColors.cobalt)
        .navigationTitle("Other Nutrients")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            goals = OptionalNutrientGoals.decoded(from: storedGoalsData)
        }
        .onChange(of: storedGoalsData) { _, newData in
            goals = OptionalNutrientGoals.decoded(from: newData)
        }
        .sheet(item: $editingNutrient) { nutrient in
            NutritionPickerSheet(
                label: nutrient.displayName,
                unit: nutrient.unit,
                currentValue: goals.goal(for: nutrient),
                range: nutrient.range,
                step: nutrient.step,
                allowsCustomValue: true,
                guidanceUpperLimit: nutrient.generalAdultUpperLimit,
                customValueDetail: nutrient.customValueDetail
            ) { value in
                save(goals.settingGoal(value, for: nutrient))
            }
        }
    }

    private func save(_ newGoals: OptionalNutrientGoals) {
        let normalized = newGoals.mergedWithDefaults()
        goals = normalized
        storedGoalsData = normalized.encodedData
    }
}
