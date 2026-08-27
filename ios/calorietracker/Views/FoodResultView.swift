import SwiftUI

struct FoodResultView: View {
    private enum ScrollTarget: Hashable {
        case quantity
    }

    let images: [UIImage]
    let emoji: String?
    let source: FoodSource
    let progressiveMeal: Bool

    @State private var baseServingSizeGrams: Double
    let servingUnitOptions: [ServingUnitOption]

    @State var name: String
    @State var servingSizeGrams: Double
    @State private var servingSizeText: String
    @State private var selectedServingUnitID: String
    @State private var quantityFocusRequest = 0
    @State private var isQuantityEditing = false
    @State private var nutritionUnlocked = false
    @State private var editableCalories: Int
    @State private var editableProtein: Double
    @State private var editableCarbs: Double
    @State private var editableFat: Double
    @State private var editableSugar: Double?
    @State private var editableAddedSugar: Double?
    @State private var editableFiber: Double?
    @State private var editableSaturatedFat: Double?
    @State private var editableMonounsaturatedFat: Double?
    @State private var editablePolyunsaturatedFat: Double?
    @State private var editableCholesterol: Double?
    @State private var editableCaffeine: Double?
    @State private var editableSupplementalNutrients: [String: Double]
    @State private var editableSodium: Double?
    @State private var editablePotassium: Double?
    @State private var editableTransFat: Double?
    @State private var editableCalcium: Double?
    @State private var editableIron: Double?
    @State private var editableMagnesium: Double?
    @State private var editableZinc: Double?
    @State private var editableVitaminA: Double?
    @State private var editableVitaminC: Double?
    @State private var editableVitaminD: Double?
    @State private var editableVitaminB12: Double?
    @State private var editableVitaminE: Double?
    @State private var editableVitaminK: Double?
    @State private var editableFolate: Double?
    @State private var editableOmega3: Double?
    @State private var editableIngredients: [MealIngredient]
    @State private var ingredientEditor: IngredientEditorTarget?
    @State private var showWhatIfSheet = false
    @State var mealType: MealType = .currentMeal

    let logDate: Date
    let profile: UserProfile
    let dayEntries: [FoodEntry]
    let weightMetric: Bool
    var onLog: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    // Scaling factor based on user-adjusted serving size
    private var scale: Double {
        guard baseServingSizeGrams > 0 else { return 1 }
        return servingSizeGrams / baseServingSizeGrams
    }

    // Computed scaled nutrition values
    private var scaledCalories: Int { Int(round(Double(editableCalories) * scale)) }
    private var scaledProtein: Double { editableProtein * scale }
    private var scaledCarbs: Double { editableCarbs * scale }
    private var scaledFat: Double { editableFat * scale }
    private var scaledSugar: Double? { editableSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledAddedSugar: Double? { editableAddedSugar.map { round($0 * scale * 10) / 10 } }
    private var scaledFiber: Double? { editableFiber.map { round($0 * scale * 10) / 10 } }
    private var scaledSaturatedFat: Double? { editableSaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledMonounsaturatedFat: Double? { editableMonounsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledPolyunsaturatedFat: Double? { editablePolyunsaturatedFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCholesterol: Double? { editableCholesterol.map { round($0 * scale * 10) / 10 } }
    private var scaledCaffeine: Double? { editableCaffeine.map { round($0 * scale * 10) / 10 } }
    private var scaledSupplementalNutrients: [String: Double] {
        editableSupplementalNutrients.mapValues { round($0 * scale * 10) / 10 }
    }
    private var scaledSodium: Double? { editableSodium.map { round($0 * scale * 10) / 10 } }
    private var scaledPotassium: Double? { editablePotassium.map { round($0 * scale * 10) / 10 } }
    private var scaledTransFat: Double? { editableTransFat.map { round($0 * scale * 10) / 10 } }
    private var scaledCalcium: Double? { editableCalcium.map { round($0 * scale * 10) / 10 } }
    private var scaledIron: Double? { editableIron.map { round($0 * scale * 10) / 10 } }
    private var scaledMagnesium: Double? { editableMagnesium.map { round($0 * scale * 10) / 10 } }
    private var scaledZinc: Double? { editableZinc.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminA: Double? { editableVitaminA.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminC: Double? { editableVitaminC.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminD: Double? { editableVitaminD.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminB12: Double? { editableVitaminB12.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminE: Double? { editableVitaminE.map { round($0 * scale * 10) / 10 } }
    private var scaledVitaminK: Double? { editableVitaminK.map { round($0 * scale * 10) / 10 } }
    private var scaledFolate: Double? { editableFolate.map { round($0 * scale * 10) / 10 } }
    private var scaledOmega3: Double? { editableOmega3.map { round($0 * scale * 10) / 10 } }
    private var selectedServingOption: ServingUnitOption {
        ServingUnitOption.option(matching: selectedServingUnitID, in: servingUnitOptions)
    }
    private var selectedServingQuantity: Double? {
        ServingAmountExpression.evaluate(servingSizeText)
    }

    init(
        images: [UIImage] = [],
        emoji: String? = nil,
        source: FoodSource,
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        ingredients: [MealIngredient] = [],
        progressiveMeal: Bool = false,
        servingSizeGrams: Double = 100,
        sugar: Double? = nil,
        addedSugar: Double? = nil,
        fiber: Double? = nil,
        saturatedFat: Double? = nil,
        monounsaturatedFat: Double? = nil,
        polyunsaturatedFat: Double? = nil,
        cholesterol: Double? = nil,
        caffeine: Double? = nil,
        supplementalNutrients: [String: Double] = [:],
        sodium: Double? = nil,
        potassium: Double? = nil,
        transFat: Double? = nil,
        calcium: Double? = nil,
        iron: Double? = nil,
        magnesium: Double? = nil,
        zinc: Double? = nil,
        vitaminA: Double? = nil,
        vitaminC: Double? = nil,
        vitaminD: Double? = nil,
        vitaminB12: Double? = nil,
        vitaminE: Double? = nil,
        vitaminK: Double? = nil,
        folate: Double? = nil,
        omega3: Double? = nil,
        servingUnitOptions: [ServingUnitOption] = [],
        selectedServingUnit: String? = nil,
        selectedServingQuantity: Double? = nil,
        logDate: Date = .now,
        profile: UserProfile,
        dayEntries: [FoodEntry],
        weightMetric: Bool,
        onLog: @escaping (FoodEntry) -> Void
    ) {
        let normalizedServingUnitOptions = ServingUnitOption.normalizedOptions(servingUnitOptions, totalGrams: servingSizeGrams)
        let preferredServingUnit = FoodMeasurementSettings.preferGramsByDefault ? nil : selectedServingUnit
        let initialServingUnitID = ServingUnitOption.initialUnitID(
            preferredUnit: preferredServingUnit,
            options: normalizedServingUnitOptions,
            defaultToGrams: FoodMeasurementSettings.preferGramsByDefault
        )
        self.images = images
        self.emoji = emoji
        self.source = source
        self.progressiveMeal = progressiveMeal
        self._baseServingSizeGrams = State(initialValue: servingSizeGrams)
        self.servingUnitOptions = normalizedServingUnitOptions
        self._name = State(initialValue: name)
        self._servingSizeGrams = State(initialValue: servingSizeGrams)
        self._servingSizeText = State(initialValue: ServingUnitOption.initialQuantityText(
            totalGrams: servingSizeGrams,
            selectedUnitID: initialServingUnitID,
            selectedQuantity: selectedServingQuantity,
            options: normalizedServingUnitOptions
        ))
        self._selectedServingUnitID = State(initialValue: initialServingUnitID)
        self._editableCalories = State(initialValue: calories)
        self._editableProtein = State(initialValue: protein)
        self._editableCarbs = State(initialValue: carbs)
        self._editableFat = State(initialValue: fat)
        self._editableSugar = State(initialValue: sugar)
        self._editableAddedSugar = State(initialValue: addedSugar)
        self._editableFiber = State(initialValue: fiber)
        self._editableSaturatedFat = State(initialValue: saturatedFat)
        self._editableMonounsaturatedFat = State(initialValue: monounsaturatedFat)
        self._editablePolyunsaturatedFat = State(initialValue: polyunsaturatedFat)
        self._editableCholesterol = State(initialValue: cholesterol)
        self._editableCaffeine = State(initialValue: caffeine)
        self._editableSupplementalNutrients = State(initialValue: supplementalNutrients)
        self._editableSodium = State(initialValue: sodium)
        self._editablePotassium = State(initialValue: potassium)
        self._editableTransFat = State(initialValue: transFat)
        self._editableCalcium = State(initialValue: calcium)
        self._editableIron = State(initialValue: iron)
        self._editableMagnesium = State(initialValue: magnesium)
        self._editableZinc = State(initialValue: zinc)
        self._editableVitaminA = State(initialValue: vitaminA)
        self._editableVitaminC = State(initialValue: vitaminC)
        self._editableVitaminD = State(initialValue: vitaminD)
        self._editableVitaminB12 = State(initialValue: vitaminB12)
        self._editableVitaminE = State(initialValue: vitaminE)
        self._editableVitaminK = State(initialValue: vitaminK)
        self._editableFolate = State(initialValue: folate)
        self._editableOmega3 = State(initialValue: omega3)
        self._editableIngredients = State(initialValue: ingredients)
        self.logDate = logDate
        self.profile = profile
        self.dayEntries = dayEntries
        self.weightMetric = weightMetric
        self.onLog = onLog
    }

    private static func formatGrams(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var safeInverseScale: Double {
        scale > 0 ? scale : 1
    }

    private func decimalValue(from text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized) else {
            return nil
        }
        return max(0, value)
    }

    private func editText(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? ""
    }

    private func displayText(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? "—"
    }

    private func updateBaseCalories(from text: String) {
        editableCalories = Int(round((decimalValue(from: text) ?? 0) / safeInverseScale))
    }

    private func updateBaseDouble(from text: String, set: (Double) -> Void) {
        set((decimalValue(from: text) ?? 0) / safeInverseScale)
    }

    private func updateOptionalBaseDouble(from text: String, set: (Double?) -> Void) {
        set(decimalValue(from: text).map { $0 / safeInverseScale })
    }

    private func toggleNutritionLock() {
        nutritionUnlocked.toggle()
        if !nutritionUnlocked {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var scaledIngredients: [MealIngredient] {
        editableIngredients.map { $0.scaled(by: scale) }
    }

    private func applyIngredientChanges(_ displayedIngredients: [MealIngredient]) {
        editableIngredients = displayedIngredients
        let totals = displayedIngredients.ingredientTotals
        editableCalories = totals.calories
        editableProtein = totals.protein
        editableCarbs = totals.carbs
        editableFat = totals.fat
        guard totals.grams > 0 else { return }
        baseServingSizeGrams = totals.grams
        servingSizeGrams = totals.grams
        servingSizeText = Self.formatGrams(totals.grams)
        selectedServingUnitID = ServingUnitOption.grams.unit
    }

    private var reviewHero: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottom) {
                reviewPhoto
                    .frame(maxWidth: .infinity)
                    .frame(height: images.isEmpty && emoji == nil ? 300 : 360)
                    .padding(.bottom, 112)

                reviewReceipt
                    .padding(.horizontal, 16)
            }

            if images.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 9) {
                        ForEach(Array(images.dropFirst().enumerated()), id: \.offset) { index, image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(KitchenTablePalette.rule, lineWidth: 1)
                                }
                                .accessibilityLabel("Review Food")
                                .accessibilityValue(Text(verbatim: "\(index + 2) / \(images.count)"))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            if !scaledIngredients.isEmpty {
                reviewIngredientStrip
            }
        }
    }

    private var reviewIngredientStrip: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(scaledIngredients.prefix(4).enumerated()), id: \.element.id) { index, ingredient in
                VStack(alignment: .leading, spacing: 4) {
                    Circle()
                        .fill([KitchenTablePalette.tomato, KitchenTablePalette.herb, KitchenTablePalette.cobalt, KitchenTablePalette.brass][index % 4])
                        .frame(width: 7, height: 7)

                    Text(ingredient.name)
                        .font(.system(size: 9, weight: .semibold, design: .serif))
                        .foregroundStyle(KitchenTablePalette.espresso)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(verbatim: "\(Self.formatGrams(ingredient.grams)) g")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)
                        .lineLimit(1)
                }
                .padding(7)
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                .background(KitchenTablePalette.paperRaised)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(KitchenTablePalette.rule, lineWidth: 0.8)
                }
                .shadow(color: KitchenTablePalette.shadow, radius: 2, x: 0, y: 1)
                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -0.3 : 0.3))
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text("Ingredients", comment: "Accessibility label for the analyzed meal's ingredient list.")
        )
    }

    @ViewBuilder
    private var reviewPhoto: some View {
        if let image = images.first {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .compositingGroup()
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(KitchenTablePalette.paperRaised, lineWidth: 6)
                        .padding(4)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(KitchenTablePalette.strongRule, lineWidth: 1)
                }
                .shadow(color: KitchenTablePalette.shadow, radius: 5, x: 0, y: 3)
                .clipped()
                .accessibilityLabel("Review Food")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(KitchenTablePalette.paperMuted)

                if let emoji {
                    Text(emoji)
                        .font(.system(size: 88))
                } else {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 78, weight: .light))
                        .foregroundStyle(KitchenTablePalette.cobalt)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(KitchenTablePalette.rule, lineWidth: 1)
            }
        }
    }

    private var reviewReceipt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI analysis")
                        .textCase(.uppercase)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(KitchenTablePalette.mutedEspresso)

                    Group {
                        if name.isEmpty {
                            Text("Meal")
                        } else {
                            Text(name)
                        }
                    }
                    .font(.system(.title3, design: .serif, weight: .bold))
                    .foregroundStyle(KitchenTablePalette.espresso)
                    .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(scaledCalories.formatted())
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .monospacedDigit()
                    Text(verbatim: "kcal")
                        .textCase(.uppercase)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                }
                .foregroundStyle(KitchenTablePalette.tomatoDeep)
            }

            Rectangle()
                .fill(KitchenTablePalette.rule)
                .frame(height: 1)

            HStack(spacing: 0) {
                receiptMacro("Protein", value: scaledProtein, tint: KitchenTablePalette.herb)
                receiptMacro("Carbs", value: scaledCarbs, tint: KitchenTablePalette.cobalt)
                receiptMacro("Fat", value: scaledFat, tint: KitchenTablePalette.tomato)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(KitchenTablePalette.paperRaised)
        .overlay {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(KitchenTablePalette.rule, lineWidth: 1)
        }
        .shadow(color: KitchenTablePalette.shadow, radius: 5, x: 0, y: 3)
        .rotationEffect(.degrees(-0.35))
    }

    private func receiptMacro(_ label: LocalizedStringKey, value: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .textCase(.uppercase)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(KitchenTablePalette.mutedEspresso)
            Text(verbatim: "\(MacroValueFormatter.string(value)) g")
                .font(.system(.headline, design: .serif, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var reviewActions: some View {
        HStack(spacing: 10) {
            Button("What if?") { showWhatIfSheet = true }
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(KitchenTablePalette.espresso)
                .frame(minWidth: 82, minHeight: 50)
                .padding(.horizontal, 4)
                .background(KitchenTablePalette.paperRaised, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(KitchenTablePalette.strongRule, lineWidth: 1)
                }

            Button(action: logFood) {
                HStack(spacing: 12) {
                    Text("Add to Log")
                    Spacer(minLength: 0)
                    Text(verbatim: "\(scaledCalories.formatted()) kcal")
                        .monospacedDigit()
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(KitchenTablePalette.onStrongAccent)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(KitchenTablePalette.tomato, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(KitchenTablePalette.tomatoDeep, lineWidth: 1)
                }
                .shadow(color: KitchenTablePalette.tomato.opacity(0.18), radius: 3, x: 0, y: 2)
            }
            .accessibilityLabel("Log")
        }
        .buttonStyle(KitchenTablePressableButtonStyle())
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(KitchenTablePalette.canvas.opacity(0.98))
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                List {
                    Section {
                        reviewHero
                        .neoReviewBareRow()
                    }

                    Section {
                        KitchenReviewSectionLabel(title: "Food Details")
                            .neoReviewBareRow()

                        HStack {
                            Text("Name")
                                .neoReviewFieldLabel()
                            Spacer()
                            TextField("Food name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(KitchenTablePalette.paperMuted.opacity(0.62), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.compactRule)
                                }
                        }
                        .neoReviewRow()
                    }

                    Section {
                        KitchenReviewSectionLabel(title: "Serving")
                            .neoReviewBareRow()

                        HStack {
                            Text("Quantity")
                                .neoReviewFieldLabel()
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
                        .neoReviewRow()
                        if !selectedServingOption.isGramUnit {
                            HStack {
                                Text("Total")
                                    .neoReviewFieldLabel()
                                Spacer()
                                Text("~\(Self.formatGrams(servingSizeGrams)) g")
                                    .font(.system(.body, design: .rounded, weight: .black))
                                    .foregroundStyle(NeoAppColors.cobalt)
                            }
                            .neoReviewRow()
                        }
                    }

                    Section {
                        NeoReviewNutritionBanner(isUnlocked: nutritionUnlocked, action: toggleNutritionLock)
                            .neoReviewBareRow()

                        ReviewNutritionValueRow(
                            label: "Calories",
                            displayValue: "\(scaledCalories)",
                            editValue: "\(scaledCalories)",
                            unit: "kcal",
                            isUnlocked: nutritionUnlocked,
                            onEdit: updateBaseCalories
                        )
                        .neoReviewRow()
                        ReviewNutritionValueRow(
                            label: "Protein",
                            displayValue: MacroValueFormatter.string(scaledProtein),
                            editValue: MacroValueFormatter.string(scaledProtein),
                            unit: "g",
                            isUnlocked: nutritionUnlocked,
                            onEdit: { updateBaseDouble(from: $0) { editableProtein = $0 } }
                        )
                        .neoReviewRow()
                        ReviewNutritionValueRow(
                            label: "Carbs",
                            displayValue: MacroValueFormatter.string(scaledCarbs),
                            editValue: MacroValueFormatter.string(scaledCarbs),
                            unit: "g",
                            isUnlocked: nutritionUnlocked,
                            onEdit: { updateBaseDouble(from: $0) { editableCarbs = $0 } }
                        )
                        .neoReviewRow()
                        ReviewNutritionValueRow(
                            label: "Fat",
                            displayValue: MacroValueFormatter.string(scaledFat),
                            editValue: MacroValueFormatter.string(scaledFat),
                            unit: "g",
                            isUnlocked: nutritionUnlocked,
                            onEdit: { updateBaseDouble(from: $0) { editableFat = $0 } }
                        )
                        .neoReviewRow()
                    }

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
                            ReviewNutritionValueRow(label: "Sugar", displayValue: displayText(scaledSugar), editValue: editText(scaledSugar), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableSugar = $0 } })
                            ReviewNutritionValueRow(label: "Added Sugar", displayValue: displayText(scaledAddedSugar), editValue: editText(scaledAddedSugar), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableAddedSugar = $0 } })
                            ReviewNutritionValueRow(label: "Fiber", displayValue: displayText(scaledFiber), editValue: editText(scaledFiber), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableFiber = $0 } })
                            ReviewNutritionValueRow(label: "Saturated Fat", displayValue: displayText(scaledSaturatedFat), editValue: editText(scaledSaturatedFat), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableSaturatedFat = $0 } })
                            ReviewNutritionValueRow(label: "Mono Fat", displayValue: displayText(scaledMonounsaturatedFat), editValue: editText(scaledMonounsaturatedFat), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableMonounsaturatedFat = $0 } })
                            ReviewNutritionValueRow(label: "Poly Fat", displayValue: displayText(scaledPolyunsaturatedFat), editValue: editText(scaledPolyunsaturatedFat), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editablePolyunsaturatedFat = $0 } })
                            ReviewNutritionValueRow(label: "Cholesterol", displayValue: displayText(scaledCholesterol), editValue: editText(scaledCholesterol), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableCholesterol = $0 } })
                            ReviewNutritionValueRow(label: "Caffeine", displayValue: displayText(scaledCaffeine), editValue: editText(scaledCaffeine), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableCaffeine = $0 } })
                            ReviewNutritionValueRow(label: "Sodium", displayValue: displayText(scaledSodium), editValue: editText(scaledSodium), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableSodium = $0 } })
                            ReviewNutritionValueRow(label: "Potassium", displayValue: displayText(scaledPotassium), editValue: editText(scaledPotassium), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editablePotassium = $0 } })
                            ReviewNutritionValueRow(label: "Trans Fat", displayValue: displayText(scaledTransFat), editValue: editText(scaledTransFat), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableTransFat = $0 } })
                            ReviewNutritionValueRow(label: "Calcium", displayValue: displayText(scaledCalcium), editValue: editText(scaledCalcium), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableCalcium = $0 } })
                            ReviewNutritionValueRow(label: "Iron", displayValue: displayText(scaledIron), editValue: editText(scaledIron), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableIron = $0 } })
                            ReviewNutritionValueRow(label: "Magnesium", displayValue: displayText(scaledMagnesium), editValue: editText(scaledMagnesium), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableMagnesium = $0 } })
                            ReviewNutritionValueRow(label: "Zinc", displayValue: displayText(scaledZinc), editValue: editText(scaledZinc), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableZinc = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin A", displayValue: displayText(scaledVitaminA), editValue: editText(scaledVitaminA), unit: "mcg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminA = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin C", displayValue: displayText(scaledVitaminC), editValue: editText(scaledVitaminC), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminC = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin D", displayValue: displayText(scaledVitaminD), editValue: editText(scaledVitaminD), unit: "mcg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminD = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin B12", displayValue: displayText(scaledVitaminB12), editValue: editText(scaledVitaminB12), unit: "mcg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminB12 = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin E", displayValue: displayText(scaledVitaminE), editValue: editText(scaledVitaminE), unit: "mg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminE = $0 } })
                            ReviewNutritionValueRow(label: "Vitamin K", displayValue: displayText(scaledVitaminK), editValue: editText(scaledVitaminK), unit: "mcg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableVitaminK = $0 } })
                            ReviewNutritionValueRow(label: "Folate", displayValue: displayText(scaledFolate), editValue: editText(scaledFolate), unit: "mcg", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableFolate = $0 } })
                            ReviewNutritionValueRow(label: "Omega-3", displayValue: displayText(scaledOmega3), editValue: editText(scaledOmega3), unit: "g", isUnlocked: nutritionUnlocked, dim: true, onEdit: { updateOptionalBaseDouble(from: $0) { editableOmega3 = $0 } })
                            ForEach(SupplementalNutrient.allCases) { nutrient in
                                let value = scaledSupplementalNutrients[nutrient.rawValue]
                                ReviewNutritionValueRow(
                                    label: nutrient.displayName,
                                    displayValue: displayText(value),
                                    editValue: editText(value),
                                    unit: "g",
                                    isUnlocked: nutritionUnlocked,
                                    dim: true,
                                    onEdit: { text in
                                        updateOptionalBaseDouble(from: text) { value in
                                            if let value {
                                                editableSupplementalNutrients[nutrient.rawValue] = value
                                            } else {
                                                editableSupplementalNutrients.removeValue(forKey: nutrient.rawValue)
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .font(.system(.body, design: .rounded, weight: .black))
                        .tint(NeoAppColors.cobalt)
                        .neoReviewRow()
                    }

                    Section {
                        KitchenReviewSectionLabel(title: "Meal", accent: KitchenTablePalette.herb)
                            .neoReviewBareRow()

                        Picker("Meal Type", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { meal in
                                Label(meal.displayName, systemImage: meal.icon)
                                    .tag(meal)
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.system(.body, design: .rounded, weight: .black))
                        .tint(NeoAppColors.cobalt)
                        .neoReviewRow()
                    }

                }
                .listStyle(.plain)
                .listSectionSpacing(6)
                .environment(\.defaultMinListRowHeight, 1)
                .neoScreen()
                .background(KeyboardDismissTapInstaller())
                .accessibilityIdentifier("neo.reviewFood.screen")
                .safeAreaInset(edge: .bottom) {
                    if isQuantityEditing {
                        Color.clear.frame(height: 12)
                    } else {
                        reviewActions
                    }
                }
                .onChange(of: isQuantityEditing) { _, editing in
                    guard editing else { return }
                    scrollQuantityIntoView(scrollProxy)
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .tint(KitchenTablePalette.tomato)
                    }
                }
                .sheet(isPresented: $showWhatIfSheet) {
                    WhatIfMealImpactSheet(
                        entry: makeFoodEntry(includeImage: false),
                        dayEntries: dayEntries,
                        profile: profile,
                        weightMetric: weightMetric
                    )
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

    private func logFood() {
        let entry = makeFoodEntry(includeImage: true)
        onLog(entry)
        dismiss()
    }

    private func makeFoodEntry(includeImage: Bool) -> FoodEntry {
        FoodEntry(
            name: name,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            timestamp: logDate,
            imageData: includeImage ? images.first?.jpegData(compressionQuality: 0.5) : nil,
            additionalImageData: includeImage ? images.dropFirst().compactMap { $0.jpegData(compressionQuality: 0.5) } : [],
            emoji: emoji,
            source: source,
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
            progressiveMeal: progressiveMeal,
            ingredients: scaledIngredients
        )
    }

}

private struct NeoReviewNutritionBanner: View {
    let isUnlocked: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            KitchenReviewSectionLabel(
                title: "Nutrition",
                detail: isUnlocked ? "Unlocked" : "Locked",
                accent: KitchenTablePalette.cobalt
            )

            Button(action: action) {
                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.cobalt)
                    .frame(width: 44, height: 42)
                    .background(KitchenTablePalette.paperRaised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(KitchenTablePalette.rule, lineWidth: NeoAppMetrics.rule)
                    }
            }
            .buttonStyle(KitchenTablePressableButtonStyle())
            .accessibilityLabel(isUnlocked ? "Lock nutrition editing" : "Unlock nutrition editing")
        }
    }
}

private struct KitchenReviewSectionLabel: View {
    let title: String
    var detail: String? = nil
    var accent: Color = KitchenTablePalette.tomato

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(accent)
                .frame(width: 4, height: 20)

            Text(LocalizedStringKey(title))
                .font(.system(.subheadline, design: .serif, weight: .bold))
                .foregroundStyle(KitchenTablePalette.espresso)

            Spacer(minLength: 8)

            if let detail {
                Text(LocalizedStringKey(detail))
                    .textCase(.uppercase)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(KitchenTablePalette.rule)
                .frame(height: 1)
        }
    }
}

private extension View {
    func neoReviewRow(
        padding: CGFloat = 12,
        fill: Color = NeoAppColors.surface
    ) -> some View {
        self
            .padding(padding)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(KitchenTablePalette.rule, lineWidth: 1)
            }
            .shadow(color: KitchenTablePalette.shadow.opacity(0.7), radius: 3, x: 0, y: 2)
            .neoListRow()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: NeoAppMetrics.screenInset,
                    bottom: 0,
                    trailing: NeoAppMetrics.screenInset
                )
            )
    }

    func neoReviewBareRow() -> some View {
        self
            .neoListRow()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 0,
                    leading: NeoAppMetrics.screenInset,
                    bottom: 0,
                    trailing: NeoAppMetrics.screenInset
                )
            )
    }

    func neoReviewFieldLabel() -> some View {
        self
            .textCase(.uppercase)
            .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
            .foregroundStyle(NeoAppColors.mutedInk)
    }
}

struct IngredientEditorTarget: Identifiable {
    let id = UUID()
    let index: Int?
    let ingredient: MealIngredient
}

struct MealIngredientsSection: View {
    let ingredients: [MealIngredient]
    let onEdit: (Int) -> Void
    let onAdd: () -> Void

    var body: some View {
        Section {
            KitchenReviewSectionLabel(
                title: "Ingredients",
                accent: KitchenTablePalette.herb
            )
            .neoReviewBareRow()

            if ingredients.isEmpty {
                Text("No ingredient breakdown yet")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .neoReviewRow()
            } else {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    Button {
                        onEdit(index)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(ingredient.name)
                                    .font(.system(.body, design: .serif, weight: .semibold))
                                    .foregroundStyle(NeoAppColors.ink)
                                Spacer()
                                Text("\(MacroValueFormatter.string(ingredient.grams))g · \(ingredient.calories) kcal")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(NeoAppColors.cobalt)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(NeoAppColors.ink)
                            }
                            HStack(spacing: 6) {
                                macro("P", ingredient.protein, NeoAppColors.cobalt)
                                macro("C", ingredient.carbs, NeoAppColors.cobalt)
                                macro("F", ingredient.fat, NeoAppColors.cobalt)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .neoReviewRow()
                }
            }

            Button(action: onAdd) {
                Label("Add Ingredient", systemImage: "plus")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(KitchenTablePalette.herbDeep)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .neoReviewRow(fill: KitchenTablePalette.herb.opacity(0.12))

            Text("Ingredient changes update the meal's calorie and macro totals automatically.")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(NeoAppColors.mutedInk)
                .neoReviewRow(fill: NeoAppColors.subtleSurface)
        }
    }

    private func macro(_ label: String, _ value: Double, _ color: Color) -> some View {
        Text("\(label) \(MacroValueFormatter.string(value))g")
            .font(.system(.caption2, design: .monospaced, weight: .semibold))
            .foregroundStyle(KitchenTablePalette.cobaltDeep)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(color.opacity(0.28), lineWidth: NeoAppMetrics.compactRule)
            }
    }
}

struct IngredientEditorSheet: View {
    let target: IngredientEditorTarget
    let onSave: (MealIngredient) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var grams: String
    @State private var calories: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String

    init(target: IngredientEditorTarget, onSave: @escaping (MealIngredient) -> Void, onDelete: (() -> Void)?) {
        self.target = target
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: target.ingredient.name)
        _grams = State(initialValue: MacroValueFormatter.string(target.ingredient.grams))
        _calories = State(initialValue: String(target.ingredient.calories))
        _protein = State(initialValue: MacroValueFormatter.string(target.ingredient.protein))
        _carbs = State(initialValue: MacroValueFormatter.string(target.ingredient.carbs))
        _fat = State(initialValue: MacroValueFormatter.string(target.ingredient.fat))
    }

    private var parsedIngredient: MealIngredient? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let grams = decimal(grams), grams > 0,
              let calories = decimal(calories),
              let protein = decimal(protein),
              let carbs = decimal(carbs),
              let fat = decimal(fat)
        else { return nil }
        return MealIngredient(
            id: target.ingredient.id,
            name: trimmedName,
            grams: grams,
            calories: Int(round(calories)),
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "Meal builder",
                        title: target.index == nil ? "Add Ingredient" : "Edit Ingredient",
                        subtitle: "Ingredient changes recalculate the meal totals"
                    ) {
                        Image(systemName: target.index == nil ? "plus" : "square.and.pencil")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(KitchenTablePalette.onBrass)
                            .frame(width: 48, height: 48)
                            .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.rule)
                            }
                    }
                    .neoReviewBareRow()
                }

                Section {
                    NeoSectionBanner(title: "Ingredient", detail: "Details")
                        .neoReviewBareRow()

                    HStack {
                        Text("Name")
                            .neoReviewFieldLabel()
                        Spacer()
                        TextField("Name", text: $name)
                            .multilineTextAlignment(.trailing)
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .neoReviewRow()
                    valueRow("Weight", text: $grams, unit: "g")
                        .neoReviewRow()
                    valueRow("Calories", text: $calories, unit: "kcal")
                        .neoReviewRow()
                }

                Section {
                    NeoSectionBanner(title: "Macros", detail: "Per ingredient", style: .acid)
                        .neoReviewBareRow()

                    valueRow("Protein", text: $protein, unit: "g")
                        .neoReviewRow()
                    valueRow("Carbs", text: $carbs, unit: "g")
                        .neoReviewRow()
                    valueRow("Fat", text: $fat, unit: "g")
                        .neoReviewRow()
                }
                if let onDelete {
                    Section {
                        Button("Remove Ingredient", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                        .textCase(.uppercase)
                        .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                        .frame(maxWidth: .infinity)
                        .neoReviewRow(fill: NeoAppColors.warning.opacity(0.14))
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(10)
            .environment(\.defaultMinListRowHeight, 1)
            .neoScreen()
            .accessibilityIdentifier("neo.ingredientEditor.screen")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(NeoAppColors.cobalt)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let ingredient = parsedIngredient else { return }
                        onSave(ingredient)
                        dismiss()
                    }
                    .disabled(parsedIngredient == nil)
                    .font(.system(.body, design: .rounded, weight: .black))
                    .tint(NeoAppColors.cobalt)
                }
            }
        }
    }

    private func valueRow(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
                .neoReviewFieldLabel()
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded, weight: .black))
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(NeoAppColors.subtleSurface)
                .overlay {
                    Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }
                .frame(maxWidth: 110)
            Text(unit)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.cobalt)
        }
    }

    private func decimal(_ value: String) -> Double? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized), number >= 0 else { return nil }
        return number
    }
}

private struct WhatIfMealImpactSheet: View {
    let entry: FoodEntry
    let dayEntries: [FoodEntry]
    let profile: UserProfile
    let weightMetric: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var isLoadingSuggestion = true
    @State private var suggestion: String?
    @State private var suggestionError: String?

    private var currentTotals: WhatIfMacroTotals {
        WhatIfMacroTotals(entries: dayEntries)
    }

    private var mealTotals: WhatIfMacroTotals {
        WhatIfMacroTotals(entry: entry)
    }

    private var afterTotals: WhatIfMacroTotals {
        currentTotals + mealTotals
    }

    private var goals: WhatIfMacroTotals {
        WhatIfMacroTotals(
            calories: profile.effectiveCalories,
            protein: Double(profile.effectiveProtein),
            carbs: Double(profile.effectiveCarbs),
            fat: Double(profile.effectiveFat)
        )
    }

    private var suggestionTaskID: String {
        [
            entry.name,
            "\(entry.calories)",
            MacroValueFormatter.string(entry.protein),
            MacroValueFormatter.string(entry.carbs),
            MacroValueFormatter.string(entry.fat),
            "\(dayEntries.count)",
            "\(profile.effectiveCalories)",
            "\(profile.effectiveProtein)",
            "\(profile.effectiveCarbs)",
            "\(profile.effectiveFat)"
        ].joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "Meal simulation",
                        title: "What if?",
                        subtitle: "Preview this meal against today's goals without logging it"
                    ) {
                        Image(systemName: "scope")
                            .font(.system(size: 23, weight: .black))
                            .foregroundStyle(KitchenTablePalette.onBrass)
                            .frame(width: 48, height: 48)
                            .background(NeoAppColors.brass, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(KitchenTablePalette.brassDeep, lineWidth: NeoAppMetrics.rule)
                            }
                    }
                    .neoReviewBareRow()
                }

                Section {
                    NeoSectionBanner(title: "Impact on Today", detail: "After meal")
                        .neoReviewBareRow()

                    WhatIfImpactRow(
                        label: "Calories",
                        added: "+\(entry.calories) kcal",
                        after: "\(afterTotals.calories) / \(goals.calories) kcal",
                        remaining: remainingCaloriesText,
                        isOver: afterTotals.calories > goals.calories,
                        tint: NeoAppColors.cobalt
                    )
                    .neoReviewRow()
                    WhatIfImpactRow(
                        label: "Protein",
                        added: "+\(MacroValueFormatter.withUnit(entry.protein))",
                        after: "\(MacroValueFormatter.string(afterTotals.protein)) / \(profile.effectiveProtein)g",
                        remaining: remainingMacroText(afterTotals.protein, goal: Double(profile.effectiveProtein)),
                        isOver: false,
                        tint: NeoAppColors.cobalt
                    )
                    .neoReviewRow()
                    WhatIfImpactRow(
                        label: "Carbs",
                        added: "+\(MacroValueFormatter.withUnit(entry.carbs))",
                        after: "\(MacroValueFormatter.string(afterTotals.carbs)) / \(profile.effectiveCarbs)g",
                        remaining: remainingMacroText(afterTotals.carbs, goal: Double(profile.effectiveCarbs)),
                        isOver: afterTotals.carbs > Double(profile.effectiveCarbs),
                        tint: NeoAppColors.cobalt
                    )
                    .neoReviewRow()
                    WhatIfImpactRow(
                        label: "Fat",
                        added: "+\(MacroValueFormatter.withUnit(entry.fat))",
                        after: "\(MacroValueFormatter.string(afterTotals.fat)) / \(profile.effectiveFat)g",
                        remaining: remainingMacroText(afterTotals.fat, goal: Double(profile.effectiveFat)),
                        isOver: afterTotals.fat > Double(profile.effectiveFat),
                        tint: NeoAppColors.cobalt
                    )
                    .neoReviewRow()

                    Text("This does not log the meal. It shows what today would look like if you logged \(entry.name).")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(NeoAppColors.mutedInk)
                        .neoReviewRow(fill: NeoAppColors.subtleSurface)
                }

                Section {
                    NeoSectionBanner(title: "AI Suggestion", detail: "Goal fit", style: .acid)
                        .neoReviewBareRow()

                    if isLoadingSuggestion {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(NeoAppColors.cobalt)
                            Text("Checking fit with your goals...")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(NeoAppColors.mutedInk)
                        }
                        .neoReviewRow()
                    } else if let suggestion {
                        Text(suggestion)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(NeoAppColors.ink)
                            .textSelection(.enabled)
                            .neoReviewRow()
                    } else if let suggestionError {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(suggestionError)
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(NeoAppColors.mutedInk)
                            Button("Retry") {
                                Task { await loadSuggestion() }
                            }
                            .textCase(.uppercase)
                            .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                            .foregroundStyle(KitchenTablePalette.onStrongAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(NeoAppColors.tomato, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(KitchenTablePalette.tomatoDeep, lineWidth: NeoAppMetrics.rule)
                            }
                        }
                        .neoReviewRow()
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(10)
            .environment(\.defaultMinListRowHeight, 1)
            .neoScreen()
            .accessibilityIdentifier("neo.reviewFood.whatIf")
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .black))
                        .tint(NeoAppColors.cobalt)
                }
            }
            .task(id: suggestionTaskID) {
                await loadSuggestion()
            }
        }
    }

    private var remainingCaloriesText: String {
        let remaining = goals.calories - afterTotals.calories
        if remaining >= 0 {
            return "\(remaining) kcal left"
        }
        return "\(abs(remaining)) kcal over"
    }

    private func remainingMacroText(_ value: Double, goal: Double) -> String {
        let remaining = goal - value
        if remaining >= 0 {
            return "\(MacroValueFormatter.string(remaining))g left"
        }
        return "\(MacroValueFormatter.string(abs(remaining)))g over"
    }

    @MainActor
    private func loadSuggestion() async {
        isLoadingSuggestion = true
        suggestion = nil
        suggestionError = nil

        do {
            let text = try await GeminiService.suggestMealWhatIf(
                entry: entry,
                dayEntries: dayEntries,
                profile: profile,
                weightMetric: weightMetric
            )
            suggestion = text.isEmpty ? "No suggestion returned. You can still review the numbers above before logging." : text
        } catch {
            suggestionError = error.localizedDescription
        }

        isLoadingSuggestion = false
    }
}

private struct WhatIfImpactRow: View {
    let label: String
    let added: String
    let after: String
    let remaining: String
    let isOver: Bool
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(tint)
                .frame(width: 7, height: 52)
                .overlay {
                    Rectangle().stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedDisplayText.text(label))
                    .textCase(.uppercase)
                    .font(.system(.body, design: .rounded, weight: .black).width(.condensed))
                    .foregroundStyle(NeoAppColors.ink)
                Text(after)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(NeoAppColors.mutedInk)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(added)
                    .font(.system(.body, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                Text(remaining)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(isOver ? NeoAppColors.warning : NeoAppColors.mutedInk)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct WhatIfMacroTotals {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double

    static let zero = WhatIfMacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0)

    init(calories: Int, protein: Double, carbs: Double, fat: Double) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(entry: FoodEntry) {
        self.init(
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat
        )
    }

    init(entries: [FoodEntry]) {
        self = entries.reduce(.zero) { totals, entry in
            totals + WhatIfMacroTotals(entry: entry)
        }
    }

    static func + (lhs: WhatIfMacroTotals, rhs: WhatIfMacroTotals) -> WhatIfMacroTotals {
        WhatIfMacroTotals(
            calories: lhs.calories + rhs.calories,
            protein: lhs.protein + rhs.protein,
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat
        )
    }
}

struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissTapView {
        KeyboardDismissTapView()
    }

    func updateUIView(_ uiView: KeyboardDismissTapView, context: Context) {
        uiView.installIfNeeded()
    }

    static func dismantleUIView(_ uiView: KeyboardDismissTapView, coordinator: ()) {
        uiView.removeGesture()
    }
}

final class KeyboardDismissTapView: UIView, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private var tapGesture: UITapGestureRecognizer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        installIfNeeded()
    }

    func installIfNeeded() {
        guard let window, installedWindow !== window else { return }
        removeGesture()

        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        gesture.cancelsTouchesInView = false
        gesture.delegate = self
        window.addGestureRecognizer(gesture)

        installedWindow = window
        tapGesture = gesture
    }

    func removeGesture() {
        if let tapGesture, let installedWindow {
            installedWindow.removeGestureRecognizer(tapGesture)
        }
        tapGesture = nil
        installedWindow = nil
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !touch.viewContainsInputOrControl
    }
}

struct EndEditingDecimalTextField: UIViewRepresentable {
    @Binding var text: String
    let focusRequest: Int
    var onEditingChanged: (Bool) -> Void
    var keyboardType: UIKeyboardType = .decimalPad
    var placeholder: String = "0"
    var accessibilityLabel: String? = nil
    var showsCalculatorToolbar = false

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = keyboardType
        textField.textAlignment = .right
        textField.placeholder = placeholder
        textField.accessibilityLabel = accessibilityLabel
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        context.coordinator.textField = textField
        textField.inputAccessoryView = context.coordinator.makeInputAccessoryView()
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
        textField.keyboardType = keyboardType
        textField.placeholder = placeholder
        textField.accessibilityLabel = accessibilityLabel
        context.coordinator.refreshPreview(for: text)
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
                Self.moveCaretToEnd(in: textField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            focusRequest: focusRequest,
            onEditingChanged: onEditingChanged,
            showsCalculatorToolbar: showsCalculatorToolbar
        )
    }

    private static func moveCaretToEnd(in textField: UITextField) {
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        var lastFocusRequest: Int
        private let onEditingChanged: (Bool) -> Void
        private let showsCalculatorToolbar: Bool
        weak var textField: UITextField?
        private weak var equalsButton: UIButton?

        init(
            text: Binding<String>,
            focusRequest: Int,
            onEditingChanged: @escaping (Bool) -> Void,
            showsCalculatorToolbar: Bool
        ) {
            self._text = text
            self.lastFocusRequest = focusRequest
            self.onEditingChanged = onEditingChanged
            self.showsCalculatorToolbar = showsCalculatorToolbar
        }

        @objc func textDidChange(_ textField: UITextField) {
            text = textField.text ?? ""
            refreshPreview(for: text)
        }

        func makeInputAccessoryView() -> UIView {
            if showsCalculatorToolbar {
                return makeCalculatorAccessoryView()
            }

            let doneItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
            doneItem.tintColor = Self.cobaltTint

            let toolbar = UIToolbar()
            toolbar.items = [flexibleSpace(), doneItem]
            toolbar.sizeToFit()
            return toolbar
        }

        private func makeCalculatorAccessoryView() -> UIView {
            let accessory = UIView()
            accessory.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 52)
            accessory.autoresizingMask = [.flexibleWidth]
            accessory.backgroundColor = .clear

            let material: UIVisualEffect
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect(style: .regular)
                glass.tintColor = Self.cobaltTint.withAlphaComponent(0.10)
                material = glass
            } else {
                material = UIBlurEffect(style: .systemChromeMaterial)
            }
            let glassSurface = UIVisualEffectView(effect: material)
            glassSurface.clipsToBounds = true
            glassSurface.layer.cornerRadius = 2
            glassSurface.layer.cornerCurve = .continuous
            glassSurface.translatesAutoresizingMaskIntoConstraints = false
            accessory.addSubview(glassSurface)

            let clear = button("C", action: #selector(clearTapped), accessibilityLabel: "Clear")
            let add = button("+", action: #selector(addTapped), accessibilityLabel: "Add")
            let subtract = button("−", action: #selector(subtractTapped), accessibilityLabel: "Subtract")
            let multiply = button("×", action: #selector(multiplyTapped), accessibilityLabel: "Multiply")
            let divide = button("÷", action: #selector(divideTapped), accessibilityLabel: "Divide")
            let equals = button("=", action: #selector(equalsTapped), accessibilityLabel: "Equals")
            let done = button("Done", action: #selector(doneTapped), accessibilityLabel: "Done", emphasized: true)
            equalsButton = equals

            let stack = UIStackView(arrangedSubviews: [clear, add, subtract, multiply, divide, equals, done])
            stack.axis = .horizontal
            stack.alignment = .fill
            stack.distribution = .fillEqually
            stack.spacing = 5
            stack.translatesAutoresizingMaskIntoConstraints = false
            glassSurface.contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                glassSurface.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 8),
                glassSurface.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -8),
                glassSurface.topAnchor.constraint(equalTo: accessory.topAnchor, constant: 4),
                glassSurface.bottomAnchor.constraint(equalTo: accessory.bottomAnchor, constant: -4),
                stack.leadingAnchor.constraint(equalTo: glassSurface.contentView.leadingAnchor, constant: 5),
                stack.trailingAnchor.constraint(equalTo: glassSurface.contentView.trailingAnchor, constant: -5),
                stack.topAnchor.constraint(equalTo: glassSurface.contentView.topAnchor, constant: 4),
                stack.bottomAnchor.constraint(equalTo: glassSurface.contentView.bottomAnchor, constant: -4)
            ])
            return accessory
        }

        @objc func doneTapped() {
            collapseExpressionIfValid()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        @objc private func clearTapped() {
            replaceText(with: "")
        }

        @objc private func addTapped() { append(operation: "+") }
        @objc private func subtractTapped() { append(operation: "−") }
        @objc private func multiplyTapped() { append(operation: "×") }
        @objc private func divideTapped() { append(operation: "÷") }

        @objc private func equalsTapped() {
            collapseExpressionIfValid()
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            onEditingChanged(true)
            DispatchQueue.main.async {
                EndEditingDecimalTextField.moveCaretToEnd(in: textField)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            onEditingChanged(false)
        }

        func refreshPreview(for expression: String) {
            guard showsCalculatorToolbar,
                  ServingAmountExpression.containsOperation(expression),
                  let result = ServingAmountExpression.evaluate(expression),
                  result > 0
            else {
                equalsButton?.setTitle("=", for: .normal)
                return
            }
            equalsButton?.setTitle("= \(ServingUnitEditor.formatQuantity(result))", for: .normal)
        }

        private func append(operation: Character) {
            replaceText(with: ServingAmountExpression.appending(operation, to: text))
        }

        private func collapseExpressionIfValid() {
            guard let result = ServingAmountExpression.evaluate(text), result > 0 else { return }
            replaceText(with: ServingUnitEditor.formatQuantity(result))
        }

        private func replaceText(with newValue: String) {
            text = newValue
            textField?.text = newValue
            refreshPreview(for: newValue)
            if let textField {
                EndEditingDecimalTextField.moveCaretToEnd(in: textField)
            }
        }

        private func button(
            _ title: String,
            action: Selector,
            accessibilityLabel: String,
            emphasized: Bool = false
        ) -> UIButton {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(emphasized ? .black : Self.cobaltTint, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .black)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.72
            button.backgroundColor = emphasized ? Self.acidTint : .clear
            button.layer.cornerRadius = 2
            button.layer.borderWidth = 1
            button.layer.borderColor = (emphasized ? UIColor.black : Self.cobaltTint).cgColor
            button.accessibilityLabel = accessibilityLabel
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        private func flexibleSpace() -> UIBarButtonItem {
            UIBarButtonItem(systemItem: .flexibleSpace)
        }

        private static let cobaltTint = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.30, green: 0.47, blue: 1.0, alpha: 1.0)
                : UIColor(red: 0.024, green: 0.231, blue: 0.922, alpha: 1.0)
        }
        private static let acidTint = UIColor(red: 238.0 / 255.0, green: 1.0, blue: 0, alpha: 1.0)
    }
}

private extension UITouch {
    var viewContainsInputOrControl: Bool {
        var currentView = view
        while let view = currentView {
            if view is UITextField || view is UITextView || view is UIControl {
                return true
            }
            currentView = view.superview
        }
        return false
    }
}

private struct ReviewNutritionValueRow: View {
    let label: String
    let displayValue: String
    let editValue: String
    let unit: String
    let isUnlocked: Bool
    var dim = false
    let onEdit: (String) -> Void

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(dim ? NeoAppColors.mutedInk : NeoAppColors.ink)
            Spacer()
            if isUnlocked {
                TextField("0", text: Binding(
                    get: { isFocused ? draft : editValue },
                    set: { newValue in
                        draft = newValue
                        onEdit(newValue)
                    }
                ))
                .focused($isFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.ink)
                .frame(minWidth: 76, maxWidth: 118)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(NeoAppColors.subtleSurface)
                .overlay {
                    Rectangle().stroke(NeoAppColors.cobalt, lineWidth: NeoAppMetrics.compactRule)
                }
                .onAppear { draft = editValue }
                .onChange(of: editValue) { _, newValue in
                    if !isFocused {
                        draft = newValue
                    }
                }
                .onChange(of: isUnlocked) { _, unlocked in
                    if unlocked {
                        draft = editValue
                    } else {
                        isFocused = false
                    }
                }
            } else {
                Text(displayValue)
                    .font(.system(.body, design: .rounded, weight: .black))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .monospacedDigit()
            }
            Text(unit)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.mutedInk)
                .frame(width: 36, alignment: .leading)
        }
    }
}

struct NutritionDisplayRow: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(NeoAppColors.ink)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.cobalt)
                .monospacedDigit()
            Text(unit)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.mutedInk)
                .frame(width: 36, alignment: .leading)
        }
    }
}

struct OptionalNutritionDisplayRow: View {
    let label: String
    let value: Double?
    let unit: String

    var body: some View {
        HStack {
            Text(LocalizedDisplayText.text(label))
                .textCase(.uppercase)
                .font(.system(.caption, design: .rounded, weight: .black).width(.condensed))
                .foregroundStyle(NeoAppColors.mutedInk)
            Spacer()
            Text(value.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(.body, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.cobalt)
                .monospacedDigit()
            Text(unit)
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(NeoAppColors.mutedInk)
                .frame(width: 36, alignment: .leading)
        }
    }
}
