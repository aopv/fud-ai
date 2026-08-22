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
                    NeoScreenHeader(
                        eyebrow: "SHARED FOOD",
                        title: "Add Meal",
                        subtitle: "Review every item before it reaches today's diary."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    ForEach(meals) { meal in
                        HStack(spacing: 12) {
                            if let emoji = meal.emoji {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 42, height: 42)
                                    .background(NeoAppColors.subtleSurface)
                                    .overlay {
                                        Rectangle()
                                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                                    }
                            } else {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 18, weight: .black))
                                    .foregroundStyle(Color.black)
                                    .frame(width: 42, height: 42)
                                    .background(NeoAppColors.acid)
                                    .overlay {
                                        Rectangle()
                                            .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                                    }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meal.name)
                                    .font(.system(.body, design: .rounded, weight: .black))
                                    .foregroundStyle(NeoAppColors.ink)
                                Text("\(Int(meal.protein.rounded()))P · \(Int(meal.carbs.rounded()))C · \(Int(meal.fat.rounded()))F")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(NeoAppColors.mutedInk)
                            }
                            Spacer()
                            Text("\(meal.calories) kcal")
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                                .foregroundStyle(NeoAppColors.cobalt)
                        }
                        .padding(12)
                        .background(NeoAppColors.surface)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }
                        .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    NeoSectionBanner(
                        title: meals.count == 1 ? "Shared meal" : "\(meals.count) shared meals",
                        detail: "\(totalCalories) KCAL",
                        style: .cobalt
                    )
                } footer: {
                    Text("Adds to your log with the exact nutrients from the sender. No photo is included.")
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .padding(.top, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listSectionSpacing(NeoAppMetrics.sectionSpacing)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .navigationTitle("Add Shared Meal")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(meals)
                } label: {
                    Text(meals.count == 1 ? "Add to Log" : "Add \(meals.count) to Log · \(totalCalories) kcal")
                        .textCase(.uppercase)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(NeoAppColors.canvas)
                .accessibilityIdentifier("sharedMeal.confirm")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .tint(NeoAppColors.cobalt)
                        .accessibilityIdentifier("sharedMeal.cancel")
                }
            }
        }
    }
}
