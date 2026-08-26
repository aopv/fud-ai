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
    @State private var baseCaffeine: Double?
    @State private var baseSupplementalNutrients: [String: Double]
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
    @State private var baseIngredients: [MealIngredient]
    @State private var servingUnitOptions: [ServingUnitOption]
    @State private var ingredientEditor: IngredientEditorTarget?

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
    private var scaledCaffeine: Double? { baseCaffeine.map { round($0 * scale * 10) / 10 } }
    private var scaledSupplementalNutrients: [String: Double] {
        baseSupplementalNutrients.mapValues { round($0 * scale * 10) / 10 }
    }
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
    private var scaledIngredients: [MealIngredient] { baseIngredients.map { $0.scaled(by: scale) } }
    private var selectedServingOption: ServingUnitOption {
        ServingUnitOption.option(matching: selectedServingUnitID, in: servingUnitOptions)
    }
    private var selectedServingQuantity: Double? {
        ServingAmountExpression.evaluate(servingSizeText)
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
        self._baseCaffeine = State(initialValue: entry.caffeine)
        self._baseSupplementalNutrients = State(initialValue: entry.supplementalNutrients)
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
        self._baseIngredients = State(initialValue: entry.ingredients)
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

    private func applyIngredientChanges(_ displayedIngredients: [MealIngredient]) {
        baseIngredients = displayedIngredients
        let totals = displayedIngredients.ingredientTotals
        baseCalories = totals.calories
        baseProtein = totals.protein
        baseCarbs = totals.carbs
        baseFat = totals.fat
        guard totals.grams > 0 else { return }
        baseServingSizeGrams = totals.grams
        servingSizeGrams = totals.grams
        servingSizeText = Self.formatGrams(totals.grams)
        selectedServingUnitID = ServingUnitOption.grams.unit
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    Section {
                        NeoScreenHeader(
                            eyebrow: "FOOD LOG",
                            title: "EDIT ENTRY",
                            subtitle: "Adjust the serving, nutrition, meal, or timestamp."
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 14, bottom: 2, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

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
                                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.rule)
                                            }
                                            .overlay(alignment: .bottomTrailing) {
                                                if entryImages.count > 1 {
                                                    Text("\(index + 1)/\(entryImages.count)")
                                                        .font(.system(.caption2, design: .rounded, weight: .black))
                                                        .foregroundStyle(KitchenTablePalette.onBrass)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 5)
                                                        .background(NeoAppColors.brass, in: Capsule())
                                                        .overlay {
                                                            Capsule().stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.compactRule)
                                                        }
                                                        .padding(8)
                                                }
                                            }
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.viewAligned)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else if let emoji = emoji {
                        Section {
                            HStack {
                                Spacer()
                                Text(emoji)
                                    .font(.system(size: 80))
                                    .frame(width: 140, height: 120)
                                    .background(NeoAppColors.subtleSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.rule)
                                    }
                                Spacer()
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Section {
                        HStack {
                            Text("Name")
                                .font(.system(.body, design: .rounded, weight: .black))
                            Spacer()
                            TextField("Food name", text: $name)
                                .multilineTextAlignment(.trailing)
                        }
                    } header: {
                        NeoSectionBanner(title: "Food Details", style: .cobalt)
                    }
                    .neoEditSectionRows()

                    Section {
                        HStack {
                            Text("Quantity")
                                .font(.system(.body, design: .rounded, weight: .black))
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
                                    .font(.system(.body, design: .rounded, weight: .black))
                                Spacer()
                                Text("~\(Self.formatGrams(servingSizeGrams)) g")
                                    .foregroundStyle(NeoAppColors.mutedInk)
                            }
                        }
                    } header: {
                        NeoSectionBanner(title: "Serving", style: .acid)
                    }
                    .neoEditSectionRows()

                    Section {
                        NutritionDisplayRow(label: "Calories", value: "\(scaledCalories)", unit: "kcal")
                        NutritionDisplayRow(label: "Protein", value: MacroValueFormatter.string(scaledProtein), unit: "g")
                        NutritionDisplayRow(label: "Carbs", value: MacroValueFormatter.string(scaledCarbs), unit: "g")
                        NutritionDisplayRow(label: "Fat", value: MacroValueFormatter.string(scaledFat), unit: "g")
                    } header: {
                        NeoSectionBanner(title: "Nutrition", detail: "Scaled", style: .cobalt)
                    }
                    .neoEditSectionRows()

                    MealIngredientsSection(
                        ingredients: scaledIngredients,
                        onEdit: { index in
                            ingredientEditor = IngredientEditorTarget(index: index, ingredient: scaledIngredients[index])
                        },
                        onAdd: {
                            ingredientEditor = IngredientEditorTarget(
                                index: nil,
                                ingredient: MealIngredient(name: "", grams: 100, calories: 0, protein: 0, carbs: 0, fat: 0)
                            )
                        }
                    )

                    Section {
                        DisclosureGroup("More Nutrition") {
                            OptionalNutritionDisplayRow(label: "Sugar", value: scaledSugar, unit: "g")
                            OptionalNutritionDisplayRow(label: "Added Sugar", value: scaledAddedSugar, unit: "g")
                            OptionalNutritionDisplayRow(label: "Fiber", value: scaledFiber, unit: "g")
                            OptionalNutritionDisplayRow(label: "Saturated Fat", value: scaledSaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Mono Fat", value: scaledMonounsaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Poly Fat", value: scaledPolyunsaturatedFat, unit: "g")
                            OptionalNutritionDisplayRow(label: "Cholesterol", value: scaledCholesterol, unit: "mg")
                            OptionalNutritionDisplayRow(label: "Caffeine", value: scaledCaffeine, unit: "mg")
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
                            ForEach(SupplementalNutrient.allCases) { nutrient in
                                OptionalNutritionDisplayRow(
                                    label: nutrient.displayName,
                                    value: scaledSupplementalNutrients[nutrient.rawValue],
                                    unit: "g"
                                )
                            }
                        }
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .tint(NeoAppColors.cobalt)
                    } header: {
                        NeoSectionBanner(title: "Nutrient Detail", style: .ink)
                    }
                    .neoEditSectionRows()

                    Section {
                        ZStack(alignment: .topLeading) {
                            if customNote.isEmpty {
                                Text("Add a note to refine this entry — e.g. “large bowl, extra olive oil” — then tap Reprocess.")
                                    .foregroundStyle(NeoAppColors.mutedInk)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $customNote)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(NeoAppColors.subtleSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                                }
                        }

                        if let errorMsg = reprocessingError {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundStyle(NeoAppColors.warning)
                        }
                    } header: {
                        NeoSectionBanner(title: "Reprocess with AI", detail: "Optional", style: .acid)
                    }
                    .neoEditSectionRows()

                    Section {
                        Picker("Meal Type", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { meal in
                                Label(meal.displayName, systemImage: meal.icon)
                                    .tag(meal)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(NeoAppColors.cobalt)
                    } header: {
                        NeoSectionBanner(title: "Meal", style: .cobalt)
                    }
                    .neoEditSectionRows()

                    Section {
                        DatePicker("Date", selection: $loggedAt, displayedComponents: .date)
                            .tint(NeoAppColors.cobalt)
                        DatePicker("Time", selection: $loggedAt, displayedComponents: .hourAndMinute)
                            .tint(NeoAppColors.cobalt)
                    } header: {
                        NeoSectionBanner(title: "Date & Time", style: .ink)
                    }
                    .neoEditSectionRows()

                    // Share this meal as a fudai://add-meal link (issue #107)
                    Section {
                        Button {
                            MealShare.presentShareSheet(for: [entry])
                        } label: {
                            Label("Share Meal", systemImage: "square.and.arrow.up")
                                .font(.system(.body, design: .rounded, weight: .black))
                                .foregroundStyle(NeoAppColors.cobalt)
                        }
                        .accessibilityIdentifier("editFood.share")
                    } header: {
                        NeoSectionBanner(title: "Share", style: .acid)
                    } footer: {
                        Text("Send this meal to a friend — they can add it to their Fud AI in one tap.")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.mutedInk)
                    }
                    .neoEditSectionRows()

                }
                .listStyle(.plain)
                .listSectionSpacing(NeoAppMetrics.sectionSpacing)
                .neoScreen()
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
                .tint(NeoAppColors.cobalt)
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
                                .tint(NeoAppColors.cobalt)
                                .accessibilityIdentifier("editFood.reprocess")
                        } else {
                            Button("Save", action: saveChanges)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .tint(NeoAppColors.cobalt)
                                .accessibilityIdentifier("editFood.save")
                        }
                    }
                }
                .sheet(item: $ingredientEditor) { target in
                    IngredientEditorSheet(
                        target: target,
                        onSave: { ingredient in
                            var next = scaledIngredients
                            if let index = target.index, next.indices.contains(index) {
                                next[index] = ingredient
                            } else {
                                next.append(ingredient)
                            }
                            applyIngredientChanges(next)
                        },
                        onDelete: target.index.map { index in
                            {
                                var next = scaledIngredients
                                guard next.indices.contains(index) else { return }
                                next.remove(at: index)
                                applyIngredientChanges(next)
                            }
                        }
                    )
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
                baseCaffeine = newAnalysis.caffeine
                baseSupplementalNutrients = newAnalysis.supplementalNutrients
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
                baseIngredients = newAnalysis.ingredients
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
            caffeine: scaledCaffeine,
            supplementalNutrients: scaledSupplementalNutrients,
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
            customNote: customNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customNote,
            progressiveMeal: entry.progressiveMeal,
            ingredients: scaledIngredients
        )
        foodStore.updateEntry(updated)
        dismiss()
    }
}

private extension View {
    func neoEditSectionRows() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))
            .listRowBackground(NeoAppColors.surface)
            .listRowSeparatorTint(NeoAppColors.ink.opacity(0.34))
    }
}
