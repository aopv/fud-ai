import SwiftUI

/// Workout preferences embedded directly in Fud AI's main Settings list.
struct WorkoutLoggingSettingsSection: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore

    @State private var draft = StrengthWorkoutPreferences()
    @State private var hasLoaded = false

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
    }

    private func loadPreferences() {
        guard !hasLoaded else { return }
        draft = workoutStore.preferences
        hasLoaded = true
    }
}
