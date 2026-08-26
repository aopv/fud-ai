import SwiftUI

enum ManualEntryInput {
    static func optionalNutritionValue(_ text: String, locale: Locale = .current) -> Double? {
        guard let value = ServingUnitEditor.parseDecimal(text, locale: locale), value >= 0 else {
            return nil
        }
        return value
    }
}

struct ManualEntryView: View {
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""
    @State private var mealType: MealType = .currentMeal
    @FocusState private var focused: Field?

    let logDate: Date
    var onCancel: () -> Void
    var onSave: (FoodEntry) -> Void

    private enum Field { case name, calories, protein, carbs, fat, fiber }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(calories) != nil
    }

    var body: some View {
        VStack(spacing: 14) {
            NeoSectionBanner(title: "Manual Entry", detail: "FOOD LOG", style: .cobalt)

            field(label: "Name", text: $name, placeholder: "e.g. Homemade salad", keyboard: .default, focus: .name)

            HStack(spacing: 10) {
                numberField(label: "Calories", text: $calories, focus: .calories)
                numberField(label: "Protein (g)", text: $protein, focus: .protein)
            }

            HStack(spacing: 10) {
                numberField(label: "Carbs (g)", text: $carbs, focus: .carbs)
                numberField(label: "Fat (g)", text: $fat, focus: .fat)
            }

            numberField(
                label: "\(LocalizedDisplayText.text("Fiber", polish: "Błonnik")) (g)",
                text: $fiber,
                focus: .fiber
            )

            // Meal Type — same .menu picker style used by FoodResultView /
            // EditFoodEntryView so manual logging assigns to a specific meal
            // (defaults to whatever currentMeal returns for the time of day).
            VStack(alignment: .leading, spacing: 4) {
                Text("Meal")
                    .textCase(.uppercase)
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                HStack {
                    Text("Meal Type")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.ink)
                    Spacer()
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases, id: \.self) { meal in
                            Label(meal.displayName, systemImage: meal.icon).tag(meal)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(NeoAppColors.cobalt)
                    .labelsHidden()
                }
                .padding(12)
                .kitchenTableSurface(
                    fill: NeoAppColors.surface,
                    border: KitchenTablePalette.rule,
                    cornerRadius: 14,
                    lineWidth: NeoAppMetrics.rule,
                    shadowRadius: 3,
                    shadowY: 1
                )
            }

            Button {
                let entry = FoodEntry(
                    name: name.trimmingCharacters(in: .whitespaces),
                    calories: Int(calories) ?? 0,
                    protein: ServingUnitEditor.parseDecimal(protein) ?? 0,
                    carbs: ServingUnitEditor.parseDecimal(carbs) ?? 0,
                    fat: ServingUnitEditor.parseDecimal(fat) ?? 0,
                    timestamp: logDate,
                    source: .manual,
                    mealType: mealType,
                    fiber: ManualEntryInput.optionalNutritionValue(fiber)
                )
                onSave(entry)
            } label: {
                Text("Save")
                    .textCase(.uppercase)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(KitchenTablePalette.onStrongAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(NeoAppColors.tomato, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(KitchenTablePalette.tomatoDeep, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
            .accessibilityIdentifier("quickAdd.manual.save")

            Button(action: onCancel) {
                Text("Cancel")
                    .textCase(.uppercase)
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .background(NeoAppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .accessibilityIdentifier("quickAdd.manual.cancel")
        }
        .padding(14)
        .frame(width: 340)
        .background(KitchenTableBackdrop())
        .onAppear { focused = .name }
    }

    @ViewBuilder
    private func field(label: String, text: Binding<String>, placeholder: String, keyboard: UIKeyboardType, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.cobalt)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(NeoAppColors.ink)
                .autocorrectionDisabled()
                .focused($focused, equals: focus)
                .padding(12)
                .kitchenTableSurface(
                    fill: NeoAppColors.surface,
                    border: KitchenTablePalette.rule,
                    cornerRadius: 14,
                    lineWidth: NeoAppMetrics.rule,
                    shadowRadius: 3,
                    shadowY: 1
                )
        }
    }

    @ViewBuilder
    private func numberField(label: String, text: Binding<String>, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.cobalt)
            TextField("0", text: text)
                .keyboardType(focus == .calories ? .numberPad : .decimalPad)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(NeoAppColors.ink)
                .focused($focused, equals: focus)
                .padding(12)
                .kitchenTableSurface(
                    fill: NeoAppColors.surface,
                    border: KitchenTablePalette.rule,
                    cornerRadius: 14,
                    lineWidth: NeoAppMetrics.rule,
                    shadowRadius: 3,
                    shadowY: 1
                )
        }
    }
}
