import SwiftUI

struct FoodResultView: View {
    private enum ScrollTarget: Hashable {
        case quantity
    }

    let image: UIImage?
    let emoji: String?
    let source: FoodSource

    // Base values (original nutrition from Gemini for the original serving size)
    let baseCalories: Int
    let baseProtein: Double
    let baseCarbs: Double
    let baseFat: Double
    let baseServingSizeGrams: Double
    let baseSugar: Double?
    let baseAddedSugar: Double?
    let baseFiber: Double?
    let baseSaturatedFat: Double?
    let baseMonounsaturatedFat: Double?
    let basePolyunsaturatedFat: Double?
    let baseCholesterol: Double?
    let baseSodium: Double?
    let basePotassium: Double?
    let baseTransFat: Double?
    let baseCalcium: Double?
    let baseIron: Double?
    let baseMagnesium: Double?
    let baseZinc: Double?
    let baseVitaminA: Double?
    let baseVitaminC: Double?
    let baseVitaminD: Double?
    let baseVitaminB12: Double?
    let baseVitaminE: Double?
    let baseVitaminK: Double?
    let baseFolate: Double?
    let baseOmega3: Double?
    @State private var servingUnitOptions: [ServingUnitOption]

    @State var name: String
    @State var servingSizeGrams: Double
    @State private var servingSizeText: String
    @State private var selectedServingUnitID: String
    @State private var quantityFocusRequest = 0
    @State private var isQuantityEditing = false
    @State var mealType: MealType = .currentMeal
    @State private var showingAddCustomPortion = false

    let logDate: Date
    var onLog: (FoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss

    // Scaling factor based on user-adjusted serving size
    private var scale: Double {
        guard baseServingSizeGrams > 0 else { return 1 }
        return servingSizeGrams / baseServingSizeGrams
    }

    // Computed scaled nutrition values
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

    init(
        image: UIImage?,
        emoji: String? = nil,
        source: FoodSource,
        name: String,
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        servingSizeGrams: Double = 100,
        sugar: Double? = nil,
        addedSugar: Double? = nil,
        fiber: Double? = nil,
        saturatedFat: Double? = nil,
        monounsaturatedFat: Double? = nil,
        polyunsaturatedFat: Double? = nil,
        cholesterol: Double? = nil,
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
        onLog: @escaping (FoodEntry) -> Void
    ) {
        let normalizedServingUnitOptions = ServingUnitOption.normalizedOptions(servingUnitOptions, totalGrams: servingSizeGrams)
        let preferredServingUnit = FoodMeasurementSettings.preferGramsByDefault ? nil : selectedServingUnit
        let initialServingUnitID = ServingUnitOption.initialUnitID(
            preferredUnit: preferredServingUnit,
            options: normalizedServingUnitOptions,
            defaultToGrams: FoodMeasurementSettings.preferGramsByDefault
        )
        self.image = image
        self.emoji = emoji
        self.source = source
        self.baseCalories = calories
        self.baseProtein = protein
        self.baseCarbs = carbs
        self.baseFat = fat
        self.baseServingSizeGrams = servingSizeGrams
        self.baseSugar = sugar
        self.baseAddedSugar = addedSugar
        self.baseFiber = fiber
        self.baseSaturatedFat = saturatedFat
        self.baseMonounsaturatedFat = monounsaturatedFat
        self.basePolyunsaturatedFat = polyunsaturatedFat
        self.baseCholesterol = cholesterol
        self.baseSodium = sodium
        self.basePotassium = potassium
        self.baseTransFat = transFat
        self.baseCalcium = calcium
        self.baseIron = iron
        self.baseMagnesium = magnesium
        self.baseZinc = zinc
        self.baseVitaminA = vitaminA
        self.baseVitaminC = vitaminC
        self.baseVitaminD = vitaminD
        self.baseVitaminB12 = vitaminB12
        self.baseVitaminE = vitaminE
        self.baseVitaminK = vitaminK
        self.baseFolate = folate
        self.baseOmega3 = omega3
        self._servingUnitOptions = State(initialValue: normalizedServingUnitOptions)
        self._name = State(initialValue: name)
        self._servingSizeGrams = State(initialValue: servingSizeGrams)
        self._servingSizeText = State(initialValue: ServingUnitOption.initialQuantityText(
            totalGrams: servingSizeGrams,
            selectedUnitID: initialServingUnitID,
            selectedQuantity: selectedServingQuantity,
            options: normalizedServingUnitOptions
        ))
        self._selectedServingUnitID = State(initialValue: initialServingUnitID)
        self.logDate = logDate
        self.onLog = onLog
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
                    if let image {
                        Section {
                            HStack {
                                Spacer()
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 240)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Spacer()
                            }
                            .listRowBackground(Color.clear)
                        }
                    } else if let emoji {
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
                .navigationTitle("Review Food")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Log", action: logFood)
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

    private func logFood() {
        let entry = FoodEntry(
            name: name,
            calories: scaledCalories,
            protein: scaledProtein,
            carbs: scaledCarbs,
            fat: scaledFat,
            timestamp: logDate,
            imageData: image?.jpegData(compressionQuality: 0.5),
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
        onLog(entry)
        dismiss()
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

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .decimalPad
        textField.textAlignment = .right
        textField.placeholder = "0"
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.inputAccessoryView = context.coordinator.makeToolbar()
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        if textField.text != text {
            textField.text = text
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async {
                textField.becomeFirstResponder()
                Self.moveCaretToEnd(in: textField)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, focusRequest: focusRequest, onEditingChanged: onEditingChanged)
    }

    private static func moveCaretToEnd(in textField: UITextField) {
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding private var text: String
        var lastFocusRequest: Int
        private let onEditingChanged: (Bool) -> Void

        init(text: Binding<String>, focusRequest: Int, onEditingChanged: @escaping (Bool) -> Void) {
            self._text = text
            self.lastFocusRequest = focusRequest
            self.onEditingChanged = onEditingChanged
        }

        @objc func textDidChange(_ textField: UITextField) {
            text = textField.text ?? ""
        }

        func makeToolbar() -> UIToolbar {
            let doneItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
            doneItem.tintColor = Self.calorieTint

            let toolbar = UIToolbar()
            toolbar.items = [
                UIBarButtonItem(systemItem: .flexibleSpace),
                doneItem
            ]
            toolbar.sizeToFit()
            return toolbar
        }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

        private static let calorieTint = UIColor(red: 1.0, green: 55.0 / 255.0, blue: 95.0 / 255.0, alpha: 1.0)
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

struct NutritionDisplayRow: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
            Text(unit)
                .foregroundStyle(.secondary)
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
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.map { String(format: "%.1f", $0) } ?? "—")
                .fontWeight(.medium)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
    }
}

struct NutritionEditRowInt: View {
    let label: String
    @Binding var baseValue: Int
    let scale: Double
    let unit: String

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: baseValue) { _, _ in updateText() }
                .onChange(of: scale) { _, _ in updateText() }
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        baseValue = 0
                    } else if let v = Double(newValue) {
                        baseValue = Int(round(v / scale))
                    }
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .onAppear { updateText() }
    }

    private func updateText() {
        let scaled = Double(baseValue) * scale
        let formatted = String(Int(round(scaled)))
        if let current = Double(text), abs(current - scaled) < 0.5 { return }
        text = formatted
    }
}

struct NutritionEditRow: View {
    let label: String
    @Binding var baseValue: Double
    let scale: Double
    let unit: String

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: baseValue) { _, _ in updateText() }
                .onChange(of: scale) { _, _ in updateText() }
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        baseValue = 0
                    } else if let v = Double(newValue) {
                        baseValue = v / scale
                    }
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .onAppear { updateText() }
    }

    private func updateText() {
        let scaled = baseValue * scale
        let formatted = MacroValueFormatter.string(scaled)
        if let current = Double(text), abs(current - scaled) < 0.05 { return }
        text = formatted
    }
}

struct OptionalNutritionEditRow: View {
    let label: String
    @Binding var baseValue: Double?
    let scale: Double
    let unit: String

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            TextField("—", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .onChange(of: baseValue) { _, _ in updateText() }
                .onChange(of: scale) { _, _ in updateText() }
                .onChange(of: text) { _, newValue in
                    if newValue.isEmpty {
                        baseValue = nil
                    } else if let v = Double(newValue) {
                        baseValue = v / scale
                    }
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
        }
        .onAppear { updateText() }
    }

    private func updateText() {
        guard let base = baseValue else {
            if !text.isEmpty { text = "" }
            return
        }
        let scaled = base * scale
        let formatted = String(format: "%.1f", scaled)
        if let current = Double(text), abs(current - scaled) < 0.05 { return }
        text = formatted
    }
}
