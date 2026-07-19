import SwiftUI

/// Workout logging controls embedded directly in Fud AI's main Settings list.
/// Enabling the diary reveals its Delts preferences inside the same compact card.
struct WorkoutLoggingSettingsSection: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    @Environment(ProfileStore.self) private var profileStore
    @AppStorage(StrengthWorkoutSettings.enabledKey) private var workoutLoggingEnabled = false

    @State private var draft = StrengthWorkoutPreferences()
    @State private var hasLoaded = false
    @State private var isTargetMusclePickerPresented = false

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
            .fullScreenCover(isPresented: $isTargetMusclePickerPresented) {
                WorkoutTargetMuscleSelectionView(
                    selection: $draft.targetMuscles,
                    allowedValues: Self.targetMuscleOptions,
                    gender: profileStore.profile.gender
                )
            }

            if workoutLoggingEnabled {
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
            }
        } header: {
            Text("Workout")
        }
        .listRowBackground(AppColors.appCard)
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
    }

    private func loadPreferences() {
        guard !hasLoaded else { return }
        draft = workoutStore.preferences
        hasLoaded = true
    }
}
