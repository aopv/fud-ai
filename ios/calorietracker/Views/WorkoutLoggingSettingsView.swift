import SwiftUI

/// Drop-in section for Fud AI's existing Settings list. The setup destination
/// only appears after the user opts into the workout diary.
struct WorkoutLoggingSettingsSection: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    @AppStorage(StrengthWorkoutSettings.enabledKey) private var workoutLoggingEnabled = false

    var body: some View {
        Section {
            HStack {
                Label {
                    Text("Strength Logging")
                } icon: {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(AppColors.calorie)
                }

                Spacer()

                Toggle("Strength Logging", isOn: $workoutLoggingEnabled)
                    .labelsHidden()
                    .tint(AppColors.calorie)
            }

            if workoutLoggingEnabled {
                NavigationLink {
                    WorkoutLoggingSettingsView()
                } label: {
                    Label {
                        HStack {
                            Text("Workout Preferences")
                            Spacer()
                            Text(preferenceSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
            }
        } header: {
            Text("Workout")
        } footer: {
            Text(
                workoutLoggingEnabled
                    ? "Your workout diary stays separate from nutrition. When you chat about training, plans, logged sets, and preferences may be sent to your selected AI provider so Coach can answer."
                    : "Adds a dedicated Workout Log to the app. Existing nutrition data is not changed."
            )
        }
        .listRowBackground(AppColors.appCard)
    }

    private var preferenceSummary: String {
        let preferences = workoutStore.preferences
        return "\(preferences.frequencyDays)× · \(preferences.duration.title)"
    }
}

struct WorkoutLoggingSettingsView: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    @State private var draft = StrengthWorkoutPreferences()
    @State private var hasLoaded = false

    @State private var benchPressText = ""
    @State private var squatText = ""
    @State private var deadliftText = ""
    @State private var overheadPressText = ""

    private static let targetMuscleOptions: [String] = {
        let libraryValues = ExerciseLibraryService.shared.availablePrimaryMuscles
            .filter { $0 != "Unspecified" }
        if !libraryValues.isEmpty { return libraryValues }
        return [
            "Abdominals", "Back", "Biceps", "Calves", "Chest", "Forearms",
            "Glutes", "Hamstrings", "Quadriceps", "Shoulders", "Triceps"
        ]
    }()

    private static let equipmentOptions: [String] = {
        let libraryValues = ExerciseLibraryService.shared.availableRawEquipment
            .filter { $0 != "Unspecified" }
        if !libraryValues.isEmpty { return libraryValues }
        return ["Body only", "Bands", "Barbell", "Dumbbell", "Cable", "Machine", "Kettlebell"]
    }()

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lbs
    }

    private var weightUnitLabel: String {
        weightUnit == .kg ? "kg" : "lb"
    }

    var body: some View {
        List {
            Section {
                WorkoutSettingsChoiceGrid(
                    values: Self.targetMuscleOptions,
                    selectedValues: draft.targetMuscles,
                    accessibilityPrefix: "Target muscle",
                    onToggle: toggleTargetMuscle
                )
            } header: {
                WorkoutSettingsHeader(
                    title: "Target Muscles",
                    count: draft.targetMuscles.count,
                    systemImage: "scope"
                )
            } footer: {
                Text("Choose any areas you want to prioritize. Leave all unselected for balanced training.")
            }
            .listRowBackground(AppColors.appCard)

            Section {
                WorkoutSettingsChoiceGrid(
                    values: StrengthWorkoutIssue.allCases.map(\.rawValue),
                    selectedValues: Set(draft.issues.map(\.rawValue)),
                    accessibilityPrefix: "Training issue",
                    onToggle: toggleIssue
                )

                if draft.issues.contains(.other) {
                    TextField("Describe anything else", text: $draft.additionalIssues, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
            } header: {
                WorkoutSettingsHeader(
                    title: "Issues & Injuries",
                    count: draft.issues.count,
                    systemImage: "cross.case.fill"
                )
            } footer: {
                Text("Used to keep workout suggestions relevant. This is not medical guidance—follow your clinician's advice.")
            }
            .listRowBackground(AppColors.appCard)

            Section("Schedule") {
                Stepper(value: $draft.frequencyDays, in: 1...7) {
                    Label {
                        HStack {
                            Text("Frequency")
                            Spacer()
                            Text("\(draft.frequencyDays) \(draft.frequencyDays == 1 ? "day" : "days") / week")
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(AppColors.calorie)
                    }
                }

                Picker(selection: $draft.duration) {
                    ForEach(StrengthWorkoutDuration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                } label: {
                    Label("Session Length", systemImage: "clock.fill")
                }
                .pickerStyle(.menu)
                .tint(.secondary)

                Picker(selection: $draft.split) {
                    ForEach(StrengthWorkoutSplit.allCases) { split in
                        Text(split.title).tag(split)
                    }
                } label: {
                    Label("Training Split", systemImage: "square.grid.2x2.fill")
                }
                .pickerStyle(.menu)
                .tint(.secondary)

                if draft.split == .custom {
                    TextField("e.g. Chest + back / Legs / Arms", text: $draft.customSplit, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .listRowBackground(AppColors.appCard)

            Section {
                WorkoutSettingsChoiceGrid(
                    values: Self.equipmentOptions,
                    selectedValues: draft.equipment,
                    accessibilityPrefix: "Equipment",
                    onToggle: toggleEquipment
                )
            } header: {
                WorkoutSettingsHeader(
                    title: "Available Equipment",
                    count: draft.equipment.count,
                    systemImage: "dumbbell.fill"
                )
            } footer: {
                Text("Leave all unselected if your available equipment changes from workout to workout.")
            }
            .listRowBackground(AppColors.appCard)

            Section {
                Picker("Effort Scale", selection: $draft.rpeScale) {
                    ForEach(StrengthWorkoutRPEScale.allCases) { scale in
                        Text(scale.title).tag(scale)
                    }
                }
                .pickerStyle(.segmented)

                Label {
                    Text(draft.rpeScale.subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "gauge.with.dots.needle.50percent")
                        .foregroundStyle(AppColors.calorie)
                }
            } header: {
                Text("RPE Scale")
            } footer: {
                Text("This controls the effort field shown beside each logged set.")
            }
            .listRowBackground(AppColors.appCard)

            Section {
                strengthField("Bench Press", text: benchPressBinding)
                strengthField("Squat", text: squatBinding)
                strengthField("Deadlift", text: deadliftBinding)
                strengthField("Overhead Press", text: overheadPressBinding)
            } header: {
                Text("Strength Numbers")
            } footer: {
                Text("Optional reference lifts. Values follow your app-wide weight unit and are stored in kilograms.")
            }
            .listRowBackground(AppColors.appCard)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle("Workout Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .tint(AppColors.calorie)
        .onAppear(perform: loadPreferences)
        .onChange(of: draft) { _, newValue in
            guard hasLoaded else { return }
            workoutStore.updatePreferences { $0 = newValue }
        }
        .onChange(of: draft.split) { _, split in
            if split != .custom { draft.customSplit = "" }
        }
        .onChange(of: draft.issues) { _, issues in
            if !issues.contains(.other) { draft.additionalIssues = "" }
        }
        .onChange(of: weightUnitRaw) { _, _ in
            syncStrengthText()
        }
    }

    private var benchPressBinding: Binding<String> {
        Binding(
            get: { benchPressText },
            set: { newValue in
                benchPressText = filteredLoadText(newValue)
                draft.strength.benchPressKg = canonicalKilograms(from: benchPressText)
            }
        )
    }

    private var squatBinding: Binding<String> {
        Binding(
            get: { squatText },
            set: { newValue in
                squatText = filteredLoadText(newValue)
                draft.strength.squatKg = canonicalKilograms(from: squatText)
            }
        )
    }

    private var deadliftBinding: Binding<String> {
        Binding(
            get: { deadliftText },
            set: { newValue in
                deadliftText = filteredLoadText(newValue)
                draft.strength.deadliftKg = canonicalKilograms(from: deadliftText)
            }
        )
    }

    private var overheadPressBinding: Binding<String> {
        Binding(
            get: { overheadPressText },
            set: { newValue in
                overheadPressText = filteredLoadText(newValue)
                draft.strength.overheadPressKg = canonicalKilograms(from: overheadPressText)
            }
        )
    }

    private func strengthField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField("Not set", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 86)
                    .accessibilityLabel("\(title) in \(weightUnitLabel)")
                Text(weightUnitLabel)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadPreferences() {
        guard !hasLoaded else { return }
        draft = workoutStore.preferences
        syncStrengthText()
        hasLoaded = true
    }

    private func syncStrengthText() {
        benchPressText = displayedLoad(draft.strength.benchPressKg)
        squatText = displayedLoad(draft.strength.squatKg)
        deadliftText = displayedLoad(draft.strength.deadliftKg)
        overheadPressText = displayedLoad(draft.strength.overheadPressKg)
    }

    private func displayedLoad(_ kilograms: Double?) -> String {
        guard let kilograms else { return "" }
        let value = weightUnit == .kg ? kilograms : kilograms * 2.204_622_621_8
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func canonicalKilograms(from text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return weightUnit == .kg ? value : value / 2.204_622_621_8
    }

    private func filteredLoadText(_ value: String) -> String {
        var output = ""
        var hasDecimal = false
        for character in value.replacingOccurrences(of: ",", with: ".") {
            if character.isNumber {
                output.append(character)
            } else if character == ".", !hasDecimal {
                output.append(character)
                hasDecimal = true
            }
            if output.count == 7 { break }
        }
        return output
    }

    private func toggleTargetMuscle(_ muscle: String) {
        if draft.targetMuscles.contains(muscle) {
            draft.targetMuscles.remove(muscle)
        } else {
            draft.targetMuscles.insert(muscle)
        }
    }

    private func toggleIssue(_ rawIssue: String) {
        guard let issue = StrengthWorkoutIssue(rawValue: rawIssue) else { return }
        if draft.issues.contains(issue) {
            draft.issues.remove(issue)
        } else {
            draft.issues.insert(issue)
        }
    }

    private func toggleEquipment(_ equipment: String) {
        if draft.equipment.contains(equipment) {
            draft.equipment.remove(equipment)
        } else {
            draft.equipment.insert(equipment)
        }
    }
}

private struct WorkoutSettingsHeader: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if count > 0 {
                Text("\(count) selected")
                    .font(.caption2)
                    .foregroundStyle(AppColors.calorie)
                    .textCase(nil)
            }
        }
    }
}

private struct WorkoutSettingsChoiceGrid: View {
    let values: [String]
    let selectedValues: Set<String>
    let accessibilityPrefix: String
    let onToggle: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                let isSelected = selectedValues.contains(value)
                Button {
                    onToggle(value)
                } label: {
                    HStack(spacing: 5) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(value)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 8)
                    .background(
                        isSelected ? AppColors.calorie : AppColors.calorie.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppColors.calorie.opacity(isSelected ? 0 : 0.16), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(accessibilityPrefix), \(value)")
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 3)
    }
}
