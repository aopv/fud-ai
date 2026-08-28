import SwiftUI

/// Confirmation shown when the user opens a `fudai://add-meal` link (issue #107).
/// Lists the shared meal(s) and adds them to today's log on confirm — never silently,
/// so a stray link can't add food without the user seeing it first.
struct ImportSharedMealView: View {
    let meals: [FoodEntry]
    let onAdd: ([FoodEntry]) -> Void
    let onCancel: () -> Void

    private var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(meals) { meal in
                        HStack(spacing: 12) {
                            if let emoji = meal.emoji {
                                Text(emoji).font(.title2)
                            } else {
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(AppColors.calorie)
                                    .frame(width: 28)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                Text("\(Int(meal.protein.rounded()))P · \(Int(meal.carbs.rounded()))C · \(Int(meal.fat.rounded()))F")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(meal.calories) kcal")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(AppColors.calorie)
                        }
                        .listRowBackground(AppColors.appCard)
                    }
                } header: {
                    Text(meals.count == 1 ? "Shared meal" : "\(meals.count) shared meals")
                } footer: {
                    Text("Adds to your log with the exact nutrients from the sender. No photo is included.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationTitle("Add Shared Meal")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(meals)
                } label: {
                    Text(meals.count == 1 ? "Add to Log" : "Add \(meals.count) to Log · \(totalCalories) kcal")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.calorie, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .tint(AppColors.calorie)
                }
            }
        }
    }
}
