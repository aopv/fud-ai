import SwiftUI

struct EditFoodEntryView: View {
    private enum ScrollTarget: Hashable {
        case quantity
    }

    let entry: FoodEntry
    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss

    @State private var baseEntry: FoodEntry
    @State private var servingUnitOptions: [ServingUnitOption]

    @State private var name: String
    @State private var showingAddCustomPortion = false
    @State private var servingSizeGrams: Double
    @State private var servingSizeText: String
    @State private var selectedServingUnitID: String
    @State private var quantityFocusRequest = 0
    @State private var isQuantityEditing = false
    @State private var mealType: MealType
    @State private var loggedAt: Date

    private var baseServingSizeGrams: Double { baseEntry.servingSizeGrams ?? 100 }

    private var scale: Double {
        guard baseServingSizeGrams > 0 else { return 1 }
        return servingSizeGrams / baseServingSizeGrams
    }

    private var scaledCalories: Int { Int(round(Double(baseEntry.calories) * scale)) }
    private var scaledProtein: Double { baseEntry.protein * scale }
    private var scaledCarbs: Double { baseEntry.carbs * scale }
    private var scaledFat: Double { baseEntry.fat * scale }
    private var scaledSugar: Double? { baseEntry.sugar.map { round($0 * scale * 10) / 10 } }
    private var scaledAddedSugar: Double? { baseEntry.addedSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledFiber: Double? { baseEntry.fiber.map { round($0 * scale * 10) / 10 } }
    private var scaledSaturatedFat: Double? { baseEntry.saturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledMonounsaturatedFat: Double? { baseEntry.monounsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledPolyunsaturatedFat: Double? { baseEntry.polyunsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCholesterol: Double? { baseEntry.cholesterol.map { round($0 * scale * 10) / 10 } }
    private var scaledSodium: Double? { baseEntry.sodium.map { round($0 * scale * 10) / 10 } }
    private var scaledPotassium: Double? { baseEntry.potassium.map { round($0 * scale * 10) / 10 } }
    private var scaledTransFat: Double? { baseEntry.transFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCalcium: Double? { baseEntry.calcium.map { round($0 * scale * 10) / 10 } }
    private var scaledIron: Double? { baseEntry.iron.map { round($0 * scale * 10) / 10 } }
    private var scaledMagnesium: Double? { baseEntry.magnesium.map { round($0 * scale * 10) / 10 } }
    private var scaledZinc: Double? { baseEntry.zinc.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminA: Double? { baseEntry.vitaminA.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminC: Double? { baseEntry.vitaminC.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminD: Double? { baseEntry.vitaminD.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminB12: Double? { baseEntry.vitaminB12.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminE: Double? { baseEntry.vitaminE.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminK: Double? { baseEntry.vitaminK.map { round($0 * scale * 10) / 10 } }
    private var scaledFolate: Double? { baseEntry.folate.map { round($0 * scale * 10) / 10 } }
    private var scaledOmega3: Double? { baseEntry.omega3.map { round($0 * scale * 10) / 10 } }
    private var selectedServingOption: ServingUnitOption {
        ServingUnitOption.option(matching: selectedServingUnitID, in: servingUnitOptions)
    }
    private var selectedServingQuantity: Double? {
        ServingUnitEditor.parseDecimal(servingSizeText)
    }

    init(entry: FoodEntry) {
        self.entry = entry
        let serving = entry.servingSizeGrams ?? 100
        let normalizedServingUnitOptions = ServingUnitOption.normalizedOptions(entry.servingUnitOptions, totalGrams: serving)
        let initialServingUnitID = ServingUnitOption.initialUnitID(
            preferredUnit: entry.selectedServingUnit,
            options: normalizedServingUnitOptions,
            defaultToGrams: FoodMeasurementSettings.preferGramsByDefault
        )
        self._baseEntry = State(initialValue: entry)
        self._servingUnitOptions = State(initialValue: normalizedServingUnitOptions)
        self._name = State(initialValue: entry.name)
        self._servingSizeGrams = State(initialValue: serving)
        self._servingSizeText = State(initialValue: ServingUnitOption.initialQuantityText(
            totalGrams: serving,
            selectedUnitID: initialServingUnitID,
            selectedQuantity: entry.selectedServingQuantity,
            options: normalizedServingUnitOptions
        ))
        self._selectedServingUnitID = State(initialValue: initialServingUnitID)
        self._mealType = State(initialValue: entry.mealType)
        self._loggedAt = State(initialValue: entry.timestamp)
    }

    private static func formatGrams(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                        Section {
                            HStack {
                                Spacer()
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 240)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } else if let emoji = entry.emoji {
                        Section {
                            HStack {
                                Spacer()
                                Text(emoji)
                                    .font(.system(size: 80))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    }

                    Section("Food Details") {
                        HStack {
                            Text("Name")
                            Spacer()
                            TextField("Food name", text: $name)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section("Serving") {
                        HStack {
                            Text("Quantity")
                            Spacer()
                            ServingUnitEditor(
                                quantityText: $servingSizeText,
                                servingSizeGrams: $servingSizeGrams,
                                selectedUnitID: $selectedServingUnitID,
                                unitOptions: servingUnitOptions,
                                focusRequest: quantityFocusRequest,
                                onEditingChanged: { editing in
                                    isQuantityEditing = editing
                                },
                                onClear: {
                                    servingSizeText = ""
                                    quantityFocusRequest += 1
                                }
                            )
                        }
                        .id(ScrollTarget.quantity)
                        if !selectedServingOption.isGramUnit {
                            HStack {
                                Text("Total")
                                Spacer()
                                Text("~\(Self.formatGrams(servingSizeGrams)) g")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            showingAddCustomPortion = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Custom Portion Size")
                            }
                            .font(.subheadline)
                            .foregroundStyle(AppColors.calorie)
                        }
                    }

                    Section("Nutrition") {
                        NutritionEditRowInt(label: "Calories", baseValue: $baseEntry.calories, scale: scale, unit: "kcal")
                        NutritionEditRow(label: "Protein", baseValue: $baseEntry.protein, scale: scale, unit: "g")
                        NutritionEditRow(label: "Carbs", baseValue: $baseEntry.carbs, scale: scale, unit: "g")
                        NutritionEditRow(label: "Fat", baseValue: $baseEntry.fat, scale: scale, unit: "g")
                    }

                    Section {
                        DisclosureGroup("More Nutrition") {
                            OptionalNutritionEditRow(label: "Sugar", baseValue: $baseEntry.sugar, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Added Sugar", baseValue: $baseEntry.addedSugar, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Fiber", baseValue: $baseEntry.fiber, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Saturated Fat", baseValue: $baseEntry.saturatedFat, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Mono Fat", baseValue: $baseEntry.monounsaturatedFat, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Poly Fat", baseValue: $baseEntry.polyunsaturatedFat, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Cholesterol", baseValue: $baseEntry.cholesterol, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Sodium", baseValue: $baseEntry.sodium, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Potassium", baseValue: $baseEntry.potassium, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Trans Fat", baseValue: $baseEntry.transFat, scale: scale, unit: "g")
                            OptionalNutritionEditRow(label: "Calcium", baseValue: $baseEntry.calcium, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Iron", baseValue: $baseEntry.iron, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Magnesium", baseValue: $baseEntry.magnesium, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Zinc", baseValue: $baseEntry.zinc, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Vitamin A", baseValue: $baseEntry.vitaminA, scale: scale, unit: "mcg")
                            OptionalNutritionEditRow(label: "Vitamin C", baseValue: $baseEntry.vitaminC, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Vitamin D", baseValue: $baseEntry.vitaminD, scale: scale, unit: "mcg")
                            OptionalNutritionEditRow(label: "Vitamin B12", baseValue: $baseEntry.vitaminB12, scale: scale, unit: "mcg")
                            OptionalNutritionEditRow(label: "Vitamin E", baseValue: $baseEntry.vitaminE, scale: scale, unit: "mg")
                            OptionalNutritionEditRow(label: "Vitamin K", baseValue: $baseEntry.vitaminK, scale: scale, unit: "mcg")
                            OptionalNutritionEditRow(label: "Folate", baseValue: $baseEntry.folate, scale: scale, unit: "mcg")
                            OptionalNutritionEditRow(label: "Omega-3", baseValue: $baseEntry.omega3, scale: scale, unit: "g")
                        }
                        .tint(AppColors.calorie)
                    }

                    Section("Meal") {
                        Picker("Meal Type", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { meal in
                                Label(meal.displayName, systemImage: meal.icon)
                                    .tag(meal)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.calorie)
                    }

                    Section("Date & Time") {
                        DatePicker("Date", selection: $loggedAt, displayedComponents: .date)
                            .tint(AppColors.calorie)
                        DatePicker("Time", selection: $loggedAt, displayedComponents: .hourAndMinute)
                            .tint(AppColors.calorie)
                    }

                }
                .scrollContentBackground(.hidden)
                .background(AppColors.appBackground)
                .background(KeyboardDismissTapInstaller())
                .safeAreaInset(edge: .bottom) {
                    if isQuantityEditing {
                        Color.clear.frame(height: 12)
                    }
                }
                .onChange(of: isQuantityEditing) { _, editing in
                    guard editing else { return }
                    scrollQuantityIntoView(scrollProxy)
                }
                .sheet(isPresented: $showingAddCustomPortion) {
                    AddCustomPortionSheet(currentGrams: servingSizeGrams) { name, grams in
                        let newOption = ServingUnitOption(
                            unit: name,
                            gramsPerUnit: grams,
                            quantity: servingSizeGrams / grams
                        )
                        if let index = servingUnitOptions.firstIndex(where: { $0.id == newOption.id }) {
                            servingUnitOptions[index] = newOption
                        } else {
                            servingUnitOptions.append(newOption)
                        }
                        if selectedServingUnitID == newOption.id {
                            let quantity = grams > 0 ? servingSizeGrams / grams : servingSizeGrams
                            servingSizeText = ServingUnitEditor.formatQuantity(quantity)
                        } else {
                            selectedServingUnitID = newOption.id
                        }
                    }
                    .presentationDetents([.fraction(0.35), .medium])
                }
                .navigationTitle("Edit Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save", action: saveChanges)
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .tint(AppColors.calorie)
                    }
                }
            }
        }
    }

    private func scrollQuantityIntoView(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(ScrollTarget.quantity, anchor: .bottom)
            }
        }
    }

    private func saveChanges() {
        let updated = FoodEntry(
            id: entry.id,
            name: name,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            timestamp: loggedAt,
            imageData: entry.imageData,
            emoji: entry.emoji,
            source: entry.source,
            mealType: mealType,
            sugar: scaledSugar,
            addedSugar: scaledAddedSugar,
            fiber: scaledFiber,
            saturatedFat: scaledSaturatedFat,
            monounsaturatedFat: scaledMonounsaturatedFat,
            polyunsaturatedFat: scaledPolyunsaturatedFat,
            cholesterol: scaledCholesterol,
            sodium: scaledSodium,
            potassium: scaledPotassium,
            transFat: scaledTransFat,
            calcium: scaledCalcium,
            iron: scaledIron,
            magnesium: scaledMagnesium,
            zinc: scaledZinc,
            vitaminA: scaledVitaminA,
            vitaminC: scaledVitaminC,
            vitaminD: scaledVitaminD,
            vitaminB12: scaledVitaminB12,
            vitaminE: scaledVitaminE,
            vitaminK: scaledVitaminK,
            folate: scaledFolate,
            omega3: scaledOmega3,
            servingSizeGrams: servingSizeGrams,
            servingUnitOptions: servingUnitOptions,
            selectedServingUnit: servingUnitOptions.isEmpty ? nil : selectedServingOption.unit,
            selectedServingQuantity: servingUnitOptions.isEmpty ? nil : selectedServingQuantity
        )
        foodStore.updateEntry(updated)
        dismiss()
    }
}
