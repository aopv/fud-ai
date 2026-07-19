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

            rpeScaleGuide

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

    private var rpeScaleGuide: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("**Strength 1–10:** Lifting effort based on how many reps you had left.")
            Text("**CR10 0–10:** General effort from rest to maximum.")
            Text("**Borg 6–20:** Endurance effort linked to breathing and heart rate.")
        }
        .font(.system(.footnote, design: .rounded))
        .foregroundStyle(.secondary)
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, 32)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "RPE scale guide. Strength 1 to 10 measures lifting effort by reps left. "
                + "CR10 0 to 10 measures general effort from rest to maximum. "
                + "Borg 6 to 20 measures endurance effort using breathing and heart rate."
        )
    }
}
