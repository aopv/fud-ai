import SwiftUI

struct WaterProgressRow: View {
    let current: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(current) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)
                Spacer()
                Text("\(current.formatted()) / \(goal.formatted()) ml")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(AppColors.calorie)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Water, \(current) of \(goal) milliliters")
    }
}

struct WaterCustomAmountSheet: View {
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customAmount = ""
    @FocusState private var customFocused: Bool

    private var selectedAmount: Int? {
        Int(customAmount).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("How much water?")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                HStack {
                    TextField("Custom amount", text: $customAmount)
                        .keyboardType(.numberPad)
                        .focused($customFocused)
                        .onChange(of: customAmount) { _, value in
                            customAmount = String(value.filter(\.isNumber).prefix(4))
                        }
                    Text("ml")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(AppColors.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    guard let selectedAmount else { return }
                    onAdd(selectedAmount)
                    dismiss()
                } label: {
                    Label("Add Water", systemImage: "drop.fill")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(AppColors.calorie, in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedAmount == nil)

                Spacer()
            }
            .padding(20)
            .background(AppColors.appBackground)
            .navigationTitle("Custom Water Amount")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { customFocused = true }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WaterGoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Int) -> Void
    @State private var selectedGoal: Int

    init(currentGoal: Int, onSave: @escaping (Int) -> Void) {
        self.onSave = onSave
        let clamped = min(10_000, max(50, currentGoal))
        let snapped = min(10_000, max(50, ((clamped + 25) / 50) * 50))
        _selectedGoal = State(initialValue: snapped)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Daily Water Goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                HStack(spacing: 4) {
                    Picker("Milliliters", selection: $selectedGoal) {
                        ForEach(Array(stride(from: 50, through: 10_000, by: 50)), id: \.self) { amount in
                            Text(amount.formatted())
                                .tag(amount)
                                .font(.system(.title2, design: .rounded, weight: .medium))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 180, height: 190)
                    .clipped()

                    Text("ml")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Button {
                    onSave(selectedGoal)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: AppColors.calorieGradient, startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
