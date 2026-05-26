import SwiftUI

struct AddCustomPortionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUnit = "piece"
    @State private var gramsText = ""

    private let predefinedUnits = [
        "piece",
        "serving",
        "portion",
        "slice",
        "cup",
        "bowl",
        "plate",
        "container",
        "package",
        "can",
        "bottle",
        "glass",
        "cookie",
        "bar",
        "scoop"
    ]

    let currentGrams: Double
    var onAdd: (String, Double) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Portion Details") {
                    Picker("Unit Name", selection: $selectedUnit) {
                        ForEach(predefinedUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .tint(AppColors.calorie)

                    HStack {
                        Text("Weight in Grams")
                        Spacer()
                        TextField("Grams", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Add Custom Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let grams = ServingUnitEditor.parseDecimal(gramsText), grams > 0 {
                            onAdd(selectedUnit, grams)
                            dismiss()
                        }
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .tint(AppColors.calorie)
                    .disabled(ServingUnitEditor.parseDecimal(gramsText) == nil || (ServingUnitEditor.parseDecimal(gramsText) ?? 0) <= 0)
                }
            }
            .onAppear {
                if gramsText.isEmpty {
                    gramsText = ServingUnitEditor.formatQuantity(currentGrams)
                }
            }
        }
    }
}
