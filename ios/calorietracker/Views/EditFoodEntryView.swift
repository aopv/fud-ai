import SwiftUI

struct EditFoodEntryView: View {
    private enum ScrollTarget: Hashable {
        case quantity
    }

    let entry: FoodEntry
    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss

    // Base values (the entry's nutrition at its logged serving size)
    @State private var baseCalories: Int
    @State private var baseProtein: Double
    @State private var baseCarbs: Double
    @State private var baseFat: Double
    @State private var baseServingSizeGrams: Double
    @State private var baseSugar: Double?
    @State private var baseAddedSugar: Double?
    @State private var baseFiber: Double?
    @State private var baseSaturatedFat: Double?
    @State private var baseMonounsaturatedFat: Double?
    @State private var basePolyunsaturatedFat: Double?
    @State private var baseCholesterol: Double?
    @State private var baseSodium: Double?
    @State private var basePotassium: Double?
    @State private var baseTransFat: Double?
    @State private var baseCalcium: Double?
    @State private var baseIron: Double?
    @State private var baseMagnesium: Double?
    @State private var baseZinc: Double?
    @State private var baseVitaminA: Double?
    @State private var baseVitaminC: Double?
    @State private var baseVitaminD: Double?
    @State private var baseVitaminB12: Double?
    @State private var baseVitaminE: Double?
    @State private var baseVitaminK: Double?
    @State private var baseFolate: Double?
    @State private var baseOmega3: Double?
    @State private var servingUnitOptions: [ServingUnitOption]

    @State private var emoji: String?
    @State private var customNote: String
    @State private var savedNote: String
    @State private var isReprocessing: Bool = false
    @State private var reprocessingError: String? = nil

    @State private var name: String
    @State private var servingSizeGrams: Double
    @State private var servingSizeText: String
    @State private var selectedServingUnitID: String
    @State private var quantityFocusRequest = 0
    @State private var isQuantityEditing = false
    @State private var mealType: MealType
    @State private var loggedAt: Date

    private var scale: Double {
        guard baseServingSizeGrams > 0 else { return 1 }
        return servingSizeGrams / baseServingSizeGrams
    }

    private var scaledCalories: Int { Int(round(Double(baseCalories) * scale)) }
    private var scaledProtein: Double { baseProtein * scale }
    private var scaledCarbs: Double { baseCarbs * scale }
    private var scaledFat: Double { baseFat * scale }
    private var scaledSugar: Double? { baseSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledAddedSugar: Double? { baseAddedSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledFiber: Double? { baseFiber.map { round($0 * scale * 10) / 10 } }
    private var scaledSaturatedFat: Double? { baseSaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledMonounsaturatedFat: Double? { baseMonounsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledPolyunsaturatedFat: Double? { basePolyunsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCholesterol: Double? { baseCholesterol.map { round($0 * scale * 10) / 10 } }
    private var scaledSodium: Double? { baseSodium.map { round($0 * scale * 10) / 10 } }
    private var scaledPotassium: Double? { basePotassium.map { round($0 * scale * 10) / 10 } }
    private var scaledTransFat: Double? { baseTransFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCalcium: Double? { baseCalcium.map { round($0 * scale * 10) / 10 } }
    private var scaledIron: Double? { baseIron.map { round($0 * scale * 10) / 10 } }
    private var scaledMagnesium: Double? { baseMagnesium.map { round($0 * scale * 10) / 10 } }
    private var scaledZinc: Double? { baseZinc.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminA: Double? { baseVitaminA.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminC: Double? { baseVitaminC.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminD: Double? { baseVitaminD.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminB12: Double? { baseVitaminB12.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminE: Double? { baseVitaminE.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminK: Double? { baseVitaminK.map { round($0 * scale * 10) / 10 } }
    private var scaledFolate: Double? { baseFolate.map { round($0 * scale * 10) / 10 } }
    private var scaledOmega3: Double? { baseOmega3.map { round($0 * scale * 10) / 10 } }
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
        self._baseCalories = State(initialValue: entry.calories)
        self._baseProtein = State(initialValue: entry.protein)
        self._baseCarbs = State(initialValue: entry.carbs)
        self._baseFat = State(initialValue: entry.fat)
        self._baseServingSizeGrams = State(initialValue: serving)
        self._baseSugar = State(initialValue: entry.sugar)
        self._baseAddedSugar = State(initialValue: entry.addedSugar)
        self._baseFiber = State(initialValue: entry.fiber)
        self._baseSaturatedFat = State(initialValue: entry.saturatedFat)
        self._baseMonounsaturatedFat = State(initialValue: entry.monounsaturatedFat)
        self._basePolyunsaturatedFat = State(initialValue: entry.polyunsaturatedFat)
        self._baseCholesterol = State(initialValue: entry.cholesterol)
        self._baseSodium = State(initialValue: entry.sodium)
        self._basePotassium = State(initialValue: entry.potassium)
        self._baseTransFat = State(initialValue: entry.transFat)
        self._baseCalcium = State(initialValue: entry.calcium)
        self._baseIron = State(initialValue: entry.iron)
        self._baseMagnesium = State(initialValue: entry.magnesium)
        self._baseZinc = State(initialValue: entry.zinc)
        self._baseVitaminA = State(initialValue: entry.vitaminA)
        self._baseVitaminC = State(initialValue: entry.vitaminC)
        self._baseVitaminD = State(initialValue: entry.vitaminD)
        self._baseVitaminB12 = State(initialValue: entry.vitaminB12)
        self._baseVitaminE = State(initialValue: entry.vitaminE)
        self._baseVitaminK = State(initialValue: entry.vitaminK)
        self._baseFolate = State(initialValue: entry.folate)
        self._baseOmega3 = State(initialValue: entry.omega3)
        self._servingUnitOptions = State(initialValue: normalizedServingUnitOptions)
        self._emoji = State(initialValue: entry.emoji)
        self._customNote = State(initialValue: entry.customNote ?? "")
        self._savedNote = State(initialValue: entry.customNote ?? "")
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
                    let entryImages = entry.allImageData.compactMap(UIImage.init(data:))
                    if !entryImages.isEmpty {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(Array(entryImages.enumerated()), id: \.offset) { index, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 220, height: 200)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(alignment: .bottomTrailing) {
                                                if entryImages.count > 1 {
                                                    Text("\(index + 1)/\(entryImages.count)")
                                                        .font(.caption2.weight(.semibold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 5)
                                                        .background(.ultraThinMaterial, in: Capsule())
                                                        .padding(8)
                                                }
                                            }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                            .listRowBackground(Color.clear)
                        }
                    } else if let emoji = emoji {
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
                    }

                    Section("Nutrition") {
                        NutritionDisplayRow(label: "Calories", value: "\(scaledCalories)", unit: "kcal")
                        NutritionDisplayRow(label: "Protein", value: MacroValueFormatter.string(scaledProtein), unit: "g")
                        NutritionDisplayRow(label: "Carbs", value: MacroValueFormatter.string(scaledCarbs), unit: "g")
                        NutritionDisplayRow(label: "Fat", value: MacroValueFormatter.string(scaledFat), unit: "g")
                    }

                    Section {
                        DisclosureGroup("More Nutrition") {
                            OptionalNutritionDisplayRow(label: "Sugar", value: scaledSugar, unit: "g")
                            OptionalNutritionDisplayRow(label: "Added Sugar", value: scaledAddedSugar, unit: "g")
                            OptionalNutritionDisplayRow(label: "Fiber", value: scaledFiber, unit: "g")
                            OptionalNutritionDisplayRow(label: "Saturated Fat", value: scaledSaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Mono Fat", value: scaledMonounsaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Poly Fat", value: scaledPolyunsaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Cholesterol", value: scaledCholesterol, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Sodium", value: scaledSodium, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Potassium", value: scaledPotassium, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Trans Fat", value: scaledTransFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Calcium", value: scaledCalcium, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Iron", value: scaledIron, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Magnesium", value: scaledMagnesium, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Zinc", value: scaledZinc, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Vitamin A", value: scaledVitaminA, unit: "mcg")
                            OptionalNutritionDisplayRow(label: "Vitamin C", value: scaledVitaminC, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Vitamin D", value: scaledVitaminD, unit: "mcg")
                            OptionalNutritionDisplayRow(label: "Vitamin B12", value: scaledVitaminB12, unit: "mcg")
                            OptionalNutritionDisplayRow(label: "Vitamin E", value: scaledVitaminE, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Vitamin K", value: scaledVitaminK, unit: "mcg")
                            OptionalNutritionDisplayRow(label: "Folate", value: scaledFolate, unit: "mcg")
                            OptionalNutritionDisplayRow(label: "Omega-3", value: scaledOmega3, unit: "g")
                        }
                        .tint(AppColors.calorie)
                    }

                    Section("Reprocess with AI") {
                        ZStack(alignment: .topLeading) {
                            if customNote.isEmpty {
                                Text("Add a note to refine this entry — e.g. “large bowl, extra olive oil” — then tap Reprocess.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $customNote)
                                .frame(minHeight: 80)
                        }

                        if let errorMsg = reprocessingError {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
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

                    // Share this meal as a fudai://add-meal link (issue #107)
                    Section {
                        Button {
                            MealShare.presentShareSheet(for: [entry])
                        } label: {
                            Label("Share Meal", systemImage: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded, weight: .medium))
                        }
                        .tint(AppColors.calorie)
                    } footer: {
                        Text("Send this meal to a friend — they can add it to their Fud AI in one tap.")
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
                .disabled(isReprocessing)
                .navigationTitle("Edit Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if isReprocessing {
                            ProgressView()
                        } else if noteChanged {
                            Button("Reprocess", action: reprocess)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .tint(AppColors.calorie)
                        } else {
                            Button("Save", action: saveChanges)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .tint(AppColors.calorie)
                        }
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

    private var noteChanged: Bool {
        customNote.trimmingCharacters(in: .whitespacesAndNewlines) != savedNote
    }

    /// Re-run the AI on this entry with the edited note and overwrite the fields in
    /// place, then mark the note as saved (so the toolbar reverts to "Save").
    private func reprocess() {
        Task {
            isReprocessing = true
            reprocessingError = nil
            do {
                let newAnalysis = try await foodStore.reprocessEntry(entry, withNote: customNote)

                name = newAnalysis.name
                baseCalories = newAnalysis.calories
                baseProtein = newAnalysis.protein
                baseCarbs = newAnalysis.carbs
                baseFat = newAnalysis.fat
                baseServingSizeGrams = newAnalysis.servingSizeGrams
                baseSugar = newAnalysis.sugar
                baseAddedSugar = newAnalysis.addedSugar
                baseFiber = newAnalysis.fiber
                baseSaturatedFat = newAnalysis.saturatedFat
                baseMonounsaturatedFat = newAnalysis.monounsaturatedFat
                basePolyunsaturatedFat = newAnalysis.polyunsaturatedFat
                baseCholesterol = newAnalysis.cholesterol
                baseSodium = newAnalysis.sodium
                basePotassium = newAnalysis.potassium
                baseTransFat = newAnalysis.transFat
                baseCalcium = newAnalysis.calcium
                baseIron = newAnalysis.iron
                baseMagnesium = newAnalysis.magnesium
                baseZinc = newAnalysis.zinc
                baseVitaminA = newAnalysis.vitaminA
                baseVitaminC = newAnalysis.vitaminC
                baseVitaminD = newAnalysis.vitaminD
                baseVitaminB12 = newAnalysis.vitaminB12
                baseVitaminE = newAnalysis.vitaminE
                baseVitaminK = newAnalysis.vitaminK
                baseFolate = newAnalysis.folate
                baseOmega3 = newAnalysis.omega3
                emoji = newAnalysis.emoji

                servingUnitOptions = ServingUnitOption.normalizedOptions(newAnalysis.servingUnitOptions, totalGrams: newAnalysis.servingSizeGrams)
                let initialServingUnitID = ServingUnitOption.initialUnitID(
                    preferredUnit: newAnalysis.selectedServingUnit,
                    options: servingUnitOptions,
                    defaultToGrams: FoodMeasurementSettings.preferGramsByDefault
                )
                selectedServingUnitID = initialServingUnitID
                servingSizeGrams = newAnalysis.servingSizeGrams
                servingSizeText = ServingUnitOption.initialQuantityText(
                    totalGrams: newAnalysis.servingSizeGrams,
                    selectedUnitID: initialServingUnitID,
                    selectedQuantity: newAnalysis.selectedServingQuantity,
                    options: servingUnitOptions
                )

                savedNote = customNote.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                reprocessingError = error.localizedDescription
            }
            isReprocessing = false
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
            imageFilename: entry.imageFilename,
            additionalImageData: entry.additionalImageData,
            additionalImageFilenames: entry.additionalImageFilenames,
            emoji: emoji,
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
            selectedServingQuantity: servingUnitOptions.isEmpty ? nil : selectedServingQuantity,
            customNote: customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customNote
        )
        foodStore.updateEntry(updated)
        dismiss()
    }
}
