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
                    : "Adds a strength diary inside Workouts. Existing nutrition data is not changed."
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
    @Environment(ProfileStore.self) private var profileStore
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    @State private var draft = StrengthWorkoutPreferences()
    @State private var hasLoaded = false
    @State private var isTargetMusclePickerPresented = false

    @State private var benchPressText = ""
    @State private var squatText = ""
    @State private var deadliftText = ""
    @State private var overheadPressText = ""

    private static let targetMuscleOptions: [String] = {
        let libraryValues = ExerciseLibraryService.shared.availablePrimaryMuscles
            .filter { $0 != "Unspecified" }
        if !libraryValues.isEmpty { return libraryValues }
        return [
            "Abdominals", "Abductors", "Adductors", "Biceps", "Calves", "Chest",
            "Forearms", "Glutes", "Hamstrings", "Lats", "Lower Back", "Middle Back",
            "Neck", "Quadriceps", "Shoulders", "Traps", "Triceps"
        ]
    }()

    private static let equipmentOptions: [String] = {
        let libraryValues = ExerciseLibraryService.shared.availableRawEquipment
            .filter { $0 != "Unspecified" }
        if !libraryValues.isEmpty { return libraryValues }
        return [
            "Bands", "Barbell", "Body Only", "Cable", "Dumbbell", "E-Z Curl Bar",
            "Exercise Ball", "Foam Roll", "Kettlebells", "Machine", "Medicine Ball", "Other"
        ]
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
                WorkoutTargetMuscleSelectorRow(
                    selection: $draft.targetMuscles,
                    allowedValues: Self.targetMuscleOptions,
                    isPresented: $isTargetMusclePickerPresented
                )

                WorkoutIssueMultiSelectRow(
                    title: "Issues & Injuries",
                    systemImage: "cross.case.fill",
                    selection: $draft.issues
                )

                if draft.issues.contains(.other) {
                    TextField("Describe anything else", text: $draft.additionalIssues, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                }
            } header: {
                Text("Training Focus")
            } footer: {
                Text("Choose areas to prioritize, or leave target muscles empty for balanced training. Issues help keep suggestions relevant; follow your clinician's advice.")
            }
            .listRowBackground(AppColors.appCard)

            Section("Schedule") {
                WorkoutPreferenceMenuRow(
                    title: "Frequency",
                    systemImage: "calendar.badge.clock",
                    selection: $draft.frequencyDays,
                    options: Array(1...7),
                    label: { "\($0) \($0 == 1 ? "day" : "days") / week" }
                )

                WorkoutPreferenceMenuRow(
                    title: "Session Length",
                    systemImage: "clock.fill",
                    selection: $draft.duration,
                    options: StrengthWorkoutDuration.allCases,
                    label: \.title
                )

                WorkoutSplitPickerRow(
                    title: "Training Split",
                    systemImage: "square.grid.2x2.fill",
                    selection: $draft.split
                )

                if draft.split == .custom {
                    TextField("e.g. Chest + back / Legs / Arms", text: $draft.customSplit, axis: .vertical)
                        .lineLimit(1...3)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .listRowBackground(AppColors.appCard)

            Section {
                WorkoutRPEScalePickerRow(
                    title: "RPE Scale",
                    systemImage: "gauge.with.dots.needle.50percent",
                    selection: $draft.rpeScale
                )

                WorkoutEquipmentImagePickerRow(
                    title: "Available Equipment",
                    systemImage: "dumbbell.fill",
                    options: Self.equipmentOptions,
                    exercises: ExerciseLibraryService.shared.exercises,
                    selection: $draft.equipment,
                    label: { $0 }
                )
            } header: {
                Text("Workout Setup")
            } footer: {
                Text("Leave equipment empty if it changes between workouts. Your RPE choice controls the effort field beside every logged set.")
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
        .fullScreenCover(isPresented: $isTargetMusclePickerPresented) {
            WorkoutTargetMuscleSelectionView(
                selection: $draft.targetMuscles,
                allowedValues: Self.targetMuscleOptions,
                gender: profileStore.profile.gender
            )
        }
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

}
