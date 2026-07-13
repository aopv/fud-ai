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
                    .foregroundStyle(.cyan)
                Spacer()
                Text("\(current.formatted()) / \(goal.formatted()) ml")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(.cyan)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Water, \(current) of \(goal) milliliters")
    }
}

struct WaterLogSheet: View {
    let onAdd: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount = 250
    @State private var customAmount = ""
    @FocusState private var customFocused: Bool

    private let presets = [250, 500, 750]

    private var selectedAmount: Int? {
        if customFocused || !customAmount.isEmpty {
            return Int(customAmount).flatMap { $0 > 0 ? $0 : nil }
        }
        return amount
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("How much water?")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            amount = preset
                            customAmount = ""
                            customFocused = false
                        } label: {
                            Text("\(preset) ml")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(amount == preset && customAmount.isEmpty ? Color.cyan.opacity(0.22) : AppColors.appCard)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

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
            .navigationTitle("Log Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WaterSettingsView: View {
    @Environment(NotificationManager.self) private var notificationManager
    @AppStorage(WaterSettings.enabledKey) private var enabled = false
    @AppStorage(WaterSettings.dailyGoalKey) private var dailyGoal = WaterSettings.defaultDailyGoalMl
    @State private var goalText = ""
    @FocusState private var goalFocused: Bool

    var body: some View {
        List {
            Section {
                Toggle("Water Tracking", isOn: $enabled)
                    .tint(AppColors.calorie)
                    .onChange(of: enabled) { _, isEnabled in
                        if !isEnabled {
                            notificationManager.scheduleWaterReminder(enabled: false, hour: 14, minute: 0)
                            UserDefaults.standard.set(false, forKey: WaterSettings.reminderEnabledKey)
                        }
                    }
            } footer: {
                Text("When enabled, Water appears in the add menu and your daily progress is shown on Home.")
            }
            .listRowBackground(AppColors.appCard)

            if enabled {
                Section {
                    HStack {
                        Text("Goal")
                        Spacer()
                        TextField("2,000", text: $goalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($goalFocused)
                            .onChange(of: goalText) { _, value in
                                let digits = value.filter(\.isNumber)
                                if digits != value { goalText = digits }
                                if let goal = Int(digits), goal > 0 {
                                    dailyGoal = goal
                                }
                            }
                        Text("ml")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Daily Goal")
                } footer: {
                    Text("Enter any positive amount. Water reminders are optional and can be enabled under Notifications.")
                }
                .listRowBackground(AppColors.appCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle("Water Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { goalText = String(dailyGoal) }
        .onDisappear {
            if Int(goalText) == nil || Int(goalText) == 0 {
                goalText = String(dailyGoal)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { goalFocused = false }
            }
        }
    }
}
