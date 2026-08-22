import SwiftUI

struct WaterProgressRow: View {
    let current: Int
    let goal: Int
    let unit: WaterUnit

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(max(Double(current) / Double(goal), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .fontWidth(.condensed)
                    .textCase(.uppercase)
                    .foregroundStyle(NeoAppColors.cobalt)
                Spacer()
                Text("\(unit.displayValue(forMilliliters: current)) / \(unit.formatted(milliliters: goal))")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(NeoAppColors.ink.opacity(0.14))
                    Rectangle()
                        .fill(NeoAppColors.cobalt)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 8)
            .overlay {
                Rectangle()
                    .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                    .allowsHitTesting(false)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Water, \(unit.displayValue(forMilliliters: current)) of \(unit.displayValue(forMilliliters: goal)) \(unit.accessibilityName)")
    }
}

struct WaterCustomAmountSheet: View {
    let unit: WaterUnit
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customAmount = ""
    @FocusState private var customFocused: Bool

    private var selectedAmountMl: Int? {
        Double(customAmount.replacingOccurrences(of: ",", with: "."))
            .flatMap { $0 > 0 ? unit.milliliters(fromDisplayedValue: $0) : nil }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("How much water?")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                HStack {
                    TextField("Custom amount", text: $customAmount)
                        .keyboardType(unit == .milliliters ? .numberPad : .decimalPad)
                        .focused($customFocused)
                        .onChange(of: customAmount) { _, value in
                            let filtered = value.filter { $0.isNumber || (unit == .fluidOunces && ($0 == "." || $0 == ",")) }
                            let normalized = filtered.replacingOccurrences(of: ",", with: ".")
                            let pieces = normalized.split(separator: ".", omittingEmptySubsequences: false)
                            customAmount = String((pieces.count > 1 ? "\(pieces[0]).\(pieces[1].prefix(1))" : normalized).prefix(6))
                        }
                    Text(unit.symbol)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .neoPanel(fill: NeoAppColors.surface)

                Button {
                    guard let selectedAmountMl else { return }
                    onAdd(selectedAmountMl)
                    dismiss()
                } label: {
                    Label("Add Water", systemImage: "drop.fill")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.black)
                        .background(NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(.plain)
                .disabled(selectedAmountMl == nil)

                Spacer()
            }
            .padding(20)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
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
    let unit: WaterUnit
    @State private var selectedGoalDisplay: Int

    init(currentGoal: Int, unit: WaterUnit, onSave: @escaping (Int) -> Void) {
        self.onSave = onSave
        self.unit = unit
        if unit == .milliliters {
            let clamped = min(10_000, max(50, currentGoal))
            _selectedGoalDisplay = State(initialValue: min(10_000, max(50, ((clamped + 25) / 50) * 50)))
        } else {
            let ounces = Int((Double(currentGoal) / WaterUnit.millilitersPerFluidOunce).rounded())
            _selectedGoalDisplay = State(initialValue: min(338, max(2, ounces)))
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Daily Water Goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                HStack(spacing: 4) {
                    Picker(unit.title, selection: $selectedGoalDisplay) {
                        ForEach(unit == .milliliters ? Array(stride(from: 50, through: 10_000, by: 50)) : Array(2...338), id: \.self) { amount in
                            Text(amount.formatted())
                                .tag(amount)
                                .font(.system(.title2, design: .rounded, weight: .medium))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 180, height: 190)
                    .clipped()

                    Text(unit.symbol)
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .neoPanel(fill: NeoAppColors.surface)

                Button {
                    onSave(unit.milliliters(fromDisplayedValue: Double(selectedGoalDisplay)))
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NeoAppColors.acid)
                        .foregroundStyle(Color.black)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 24)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
