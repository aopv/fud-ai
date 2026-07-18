import Charts
import SwiftUI

// MARK: - Strength log

/// The local strength-log surface shown inside the existing Workouts navigation stack.
struct StrengthWorkoutLogView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @State private var isQuickAddPresented = false

    private var groupedSessions: [StrengthSessionDay] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: store.sortedSessions) {
            calendar.startOfDay(for: $0.date)
        }

        return groups
            .map { StrengthSessionDay(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                StrengthLogHeader(
                    sessionCount: store.sessions.count,
                    latestDate: store.sortedSessions.first?.date,
                    onAdd: { isQuickAddPresented = true }
                )
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 14, trailing: 20))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if groupedSessions.isEmpty {
                Section {
                    StrengthLogEmptyState(onAdd: { isQuickAddPresented = true })
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 120, trailing: 20))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(groupedSessions) { day in
                    Section {
                        ForEach(day.sessions) { session in
                            StrengthSessionCard(session: session)
                                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 9, trailing: 20))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        withAnimation(.snappy) {
                                            _ = store.deleteSession(session)
                                        }
                                    } label: {
                                        Label("Delete workout", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.workoutMutedText)
                            .textCase(nil)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(.compact)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 104, for: .scrollContent)
        .background(WorkoutBackground())
        .sheet(isPresented: $isQuickAddPresented) {
            StrengthWorkoutQuickAddView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct StrengthSessionDay: Identifiable {
    let date: Date
    let sessions: [StrengthWorkoutSession]

    var id: Date { date }
}

private struct StrengthLogHeader: View {
    let sessionCount: Int
    let latestDate: Date?
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Strength log")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.workoutCharcoal)

                if let latestDate {
                    Text("Last workout \(latestDate.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(Color.workoutMutedText)
                } else {
                    Text("Sets, reps, and weight stay on this device.")
                        .font(.subheadline)
                        .foregroundStyle(Color.workoutMutedText)
                }

                if sessionCount > 0 {
                    Text("\(sessionCount) \(sessionCount == 1 ? "workout" : "workouts") logged")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutSecondaryAccent)
                }
            }

            Spacer(minLength: 8)

            Button(action: onAdd) {
                Label("Log workout", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.workoutOnAccent)
                    .labelStyle(.iconOnly)
                    .frame(width: 52, height: 52)
                    .background(Color.workoutAccent, in: Circle())
                    .shadow(color: Color.workoutAccent.opacity(0.28), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .accessibilityLabel("Log workout")
            .accessibilityHint("Opens a form to record exercises and sets")
        }
        .padding(18)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.35), lineWidth: 0.7)
        }
    }
}

private struct StrengthLogEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.workoutAccent)
                .frame(width: 64, height: 64)
                .background(Color.workoutAccent.opacity(0.12), in: Circle())

            VStack(spacing: 6) {
                Text("Log your first workout")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.workoutCharcoal)

                Text("Pick an exercise, confirm your sets, and save. Your previous numbers will be ready next time.")
                    .font(.subheadline)
                    .foregroundStyle(Color.workoutMutedText)
                    .multilineTextAlignment(.center)
            }

            Button(action: onAdd) {
                Label("Log workout", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.workoutOnAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 46)
                    .background(Color.workoutAccent, in: Capsule())
            }
            .buttonStyle(.plain)
            .workoutPressable()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 34)
        .background(Color.workoutPanel.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.28), style: StrokeStyle(lineWidth: 0.7, dash: [5, 5]))
        }
    }
}

private struct StrengthSessionCard: View {
    @Environment(StrengthWorkoutStore.self) private var store
    let session: StrengthWorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(session.name?.trimmed.nilIfEmpty ?? "Workout")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.workoutCharcoal)

                    Text(session.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                }

                Spacer(minLength: 8)

                Text("\(session.setCount) \(session.setCount == 1 ? "set" : "sets")")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.workoutSecondaryAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.workoutSecondaryAccent.opacity(0.11), in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                if index > 0 {
                    Divider()
                        .overlay(Color.workoutHairline.opacity(0.28))
                        .padding(.leading, 56)
                }

                NavigationLink {
                    StrengthExerciseProgressView(
                        exerciseID: exercise.exerciseID,
                        exerciseName: exercise.exerciseName
                    )
                } label: {
                    StrengthSessionExerciseRow(
                        exercise: exercise,
                        session: session,
                        comparison: store.personalRecordComparison(
                            for: exercise.exerciseID,
                            in: session
                        ),
                        previous: store.previousExercise(
                            for: exercise.exerciseID,
                            before: session.date,
                            excludingSessionID: session.id
                        )
                    )
                }
                .buttonStyle(.plain)
                .workoutPressable()
            }
        }
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.32), lineWidth: 0.6)
        }
    }
}

private struct StrengthSessionExerciseRow: View {
    let exercise: StrengthWorkoutExercise
    let session: StrengthWorkoutSession
    let comparison: StrengthPersonalRecordComparison?
    let previous: StrengthExerciseHistoryEntry?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.workoutAccent)
                .frame(width: 32, height: 32)
                .background(Color.workoutAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(exercise.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .lineLimit(2)

                    if comparison?.hasPersonalRecord == true {
                        Label("PR", systemImage: "sparkles")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(Color.green)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }

                StrengthLastCurrentLabel(
                    current: exercise,
                    previous: previous?.exercise,
                    comparison: comparison
                )
            }

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.workoutHairline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct StrengthLastCurrentLabel: View {
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue
    let current: StrengthWorkoutExercise
    let previous: StrengthWorkoutExercise?
    let comparison: StrengthPersonalRecordComparison?

    private var useMetric: Bool { weightUnitRaw == WeightUnit.kg.rawValue }
    private var currentPerformance: StrengthExercisePerformance { .init(sets: current.sets) }
    private var previousPerformance: StrengthExercisePerformance? {
        previous.map { StrengthExercisePerformance(sets: $0.sets) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(bestSummary)
                .foregroundStyle(Color.workoutMutedText)

            Text(progressSummary)
                .foregroundStyle(comparison?.hasPersonalRecord == true ? Color.green : Color.workoutMutedText)
        }
        .font(.caption)
        .monospacedDigit()
        .lineLimit(1)
    }

    private var bestSummary: String {
        let setSummary = "\(current.sets.count) \(current.sets.count == 1 ? "set" : "sets")"
        guard let currentReps = currentPerformance.bestReps else { return setSummary }

        if let currentWeight = currentPerformance.bestWeightKg {
            return "\(setSummary) · Best \(currentReps) reps · \(StrengthWeightFormat.display(currentWeight, metric: useMetric)) \(StrengthWeightFormat.unit(metric: useMetric))"
        }
        return "\(setSummary) · Best \(currentReps) reps"
    }

    private var progressSummary: String {
        guard let previousPerformance else { return "First log" }

        if comparison?.isWeightPR == true,
           let currentWeight = currentPerformance.bestWeightKg,
           let previousWeight = previousPerformance.bestWeightKg {
            let currentValue = StrengthWeightFormat.display(currentWeight, metric: useMetric)
            let previousValue = StrengthWeightFormat.display(previousWeight, metric: useMetric)
            let delta = StrengthWeightFormat.display(currentWeight - previousWeight, metric: useMetric)
            return "Last \(previousValue) → \(currentValue) \(StrengthWeightFormat.unit(metric: useMetric)) · +\(delta) PR"
        }

        if comparison?.isRepetitionPR == true,
           let currentReps = currentPerformance.bestReps,
           let previousReps = previousPerformance.bestReps {
            return "Last \(previousReps) → \(currentReps) reps · +\(currentReps - previousReps) PR"
        }

        if let currentReps = currentPerformance.bestReps,
           let previousReps = previousPerformance.bestReps {
            return "Last \(previousReps) → \(currentReps) reps"
        }

        return "Previous workout available"
    }
}

// MARK: - Quick add

struct StrengthWorkoutQuickAddView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    @State private var date = Date.now
    @State private var sessionName = ""
    @State private var exercises: [StrengthExerciseDraft] = []
    @State private var isExercisePickerPresented = false
    @State private var didApplyPreselectedExercise = false

    let preselectedExercise: ExerciseLibraryItem?

    init(preselectedExercise: ExerciseLibraryItem? = nil) {
        self.preselectedExercise = preselectedExercise
    }

    private var useMetric: Bool { weightUnitRaw == WeightUnit.kg.rawValue }

    private var canSave: Bool {
        let hasCompletedSet = exercises.contains { exercise in
            exercise.sets.contains { (Int($0.repsText) ?? 0) > 0 }
        }
        let allWeightsAreValid = exercises
            .flatMap(\.sets)
            .allSatisfy { set in
                let text = set.weightText.trimmed
                guard !text.isEmpty else { return true }
                guard let value = StrengthWeightFormat.parse(text) else { return false }
                return value > 0
            }
        return hasCompletedSet && allWeightsAreValid
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Workout time", selection: $date)

                    TextField("Workout name (optional)", text: $sessionName)
                        .textInputAutocapitalization(.words)
                }

                ForEach($exercises) { $exercise in
                    Section {
                        StrengthDraftExerciseEditor(
                            exercise: $exercise,
                            useMetric: useMetric
                        )
                    } header: {
                        HStack(spacing: 8) {
                            Text(exercise.exerciseName)
                                .lineLimit(1)

                            if exercise.sets.contains(where: \.wasPrefilled) {
                                Text("Previous")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.workoutAccent)
                            }

                            Spacer(minLength: 4)

                            Button(role: .destructive) {
                                exercises.removeAll { $0.id == exercise.id }
                            } label: {
                                Image(systemName: "trash")
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(exercise.exerciseName)")
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    Button {
                        isExercisePickerPresented = true
                    } label: {
                        Label(exercises.isEmpty ? "Choose exercise" : "Add another exercise", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.workoutAccent)
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .center)
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                } footer: {
                    Label("Saved only on this device", systemImage: "lock.fill")
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(WorkoutBackground())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isExercisePickerPresented) {
                StrengthExercisePicker(
                    selectedExerciseIDs: Set(exercises.map(\.exerciseID)),
                    onSelect: addExercise
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                guard !didApplyPreselectedExercise, let preselectedExercise else { return }
                didApplyPreselectedExercise = true
                addExercise(preselectedExercise)
            }
        }
    }

    private func addExercise(_ item: ExerciseLibraryItem) {
        guard !exercises.contains(where: { $0.exerciseID == item.id }) else {
            isExercisePickerPresented = false
            return
        }

        let previousSets = store.previousSets(for: item.id, before: date)
        let draftSets: [StrengthSetDraft]
        if previousSets.isEmpty {
            draftSets = [StrengthSetDraft()]
        } else {
            draftSets = previousSets.map {
                StrengthSetDraft(
                    repsText: $0.reps > 0 ? String($0.reps) : "",
                    weightText: $0.weightKg.map {
                        StrengthWeightFormat.editable($0, metric: useMetric)
                    } ?? "",
                    originalWeightKg: $0.weightKg,
                    wasPrefilled: true
                )
            }
        }

        exercises.append(
            StrengthExerciseDraft(
                exerciseID: item.id,
                exerciseName: item.name,
                sets: draftSets
            )
        )
        isExercisePickerPresented = false
    }

    private func save() {
        guard canSave else { return }
        let savedExercises = exercises.compactMap { draft -> StrengthWorkoutExercise? in
            let savedSets = draft.sets.compactMap { set -> StrengthWorkoutSet? in
                guard let reps = Int(set.repsText), reps > 0 else { return nil }
                let weightKg: Double?
                if !set.weightWasEdited {
                    weightKg = set.originalWeightKg
                } else {
                    let displayWeight = StrengthWeightFormat.parse(set.weightText)
                    weightKg = displayWeight.flatMap {
                        $0 > 0 ? StrengthWeightFormat.kilograms($0, metric: useMetric) : nil
                    }
                }
                return StrengthWorkoutSet(
                    reps: reps,
                    weightKg: weightKg,
                    isBodyweight: weightKg == nil
                )
            }

            guard !savedSets.isEmpty else { return nil }
            return StrengthWorkoutExercise(
                exerciseID: draft.exerciseID,
                exerciseName: draft.exerciseName,
                sets: savedSets
            )
        }

        guard !savedExercises.isEmpty else { return }
        let session = StrengthWorkoutSession(
            date: date,
            name: sessionName.trimmed.nilIfEmpty,
            exercises: savedExercises
        )
        guard store.addSession(session) else { return }
        dismiss()
    }
}

private struct StrengthExerciseDraft: Identifiable {
    let id = UUID()
    var exerciseID: String
    var exerciseName: String
    var sets: [StrengthSetDraft]
}

private struct StrengthSetDraft: Identifiable {
    let id = UUID()
    var repsText = ""
    var weightText = ""
    var originalWeightKg: Double?
    var weightWasEdited = false
    var wasPrefilled = false
}

private struct StrengthDraftExerciseEditor: View {
    @Binding var exercise: StrengthExerciseDraft
    let useMetric: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("SET")
                    .frame(width: 32, alignment: .leading)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text(useMetric ? "KG" : "LBS")
                    .frame(maxWidth: .infinity)
                Color.clear.frame(width: 36)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color.workoutMutedText)

            ForEach($exercise.sets) { $set in
                let index = exercise.sets.firstIndex { $0.id == set.id } ?? 0
                StrengthSetEditorRow(
                    set: $set,
                    setNumber: index + 1,
                    useMetric: useMetric,
                    canRemove: exercise.sets.count > 1,
                    onRemove: { exercise.sets.removeAll { $0.id == set.id } }
                )
            }

            Button {
                exercise.sets.append(StrengthSetDraft())
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.workoutAccent)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .workoutPressable()
        }
        .padding(.vertical, 4)
    }
}

private struct StrengthSetEditorRow: View {
    @Binding var set: StrengthSetDraft
    let setNumber: Int
    let useMetric: Bool
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(set.wasPrefilled ? Color.workoutAccent : Color.workoutMutedText)
                .frame(width: 32, alignment: .leading)

            TextField("0", text: $set.repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.workoutPanel.opacity(0.34), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Set \(setNumber) repetitions")

            TextField("BW", text: $set.weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.workoutPanel.opacity(0.34), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Set \(setNumber) weight in \(useMetric ? "kilograms" : "pounds"), blank for bodyweight")

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
                    .foregroundStyle(canRemove ? Color.red : Color.clear)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canRemove)
            .accessibilityLabel("Remove set \(setNumber)")
            .accessibilityHidden(!canRemove)
        }
        .onChange(of: set.repsText) { _, value in
            let filtered = value.filter(\.isNumber)
            if filtered != value { set.repsText = filtered }
            set.wasPrefilled = false
        }
        .onChange(of: set.weightText) { _, _ in
            set.weightWasEdited = true
            set.wasPrefilled = false
        }
    }
}

private struct StrengthExercisePicker: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let selectedExerciseIDs: Set<String>
    let onSelect: (ExerciseLibraryItem) -> Void

    @State private var searchText = ""
    private let service = ExerciseLibraryService.shared

    private var recentItems: [ExerciseLibraryItem] {
        var seen = Set<String>()
        let recentIDs = store.sortedSessions
            .flatMap(\.exercises)
            .compactMap { exercise -> String? in
                guard seen.insert(exercise.exerciseID).inserted else { return nil }
                return exercise.exerciseID
            }
            .prefix(5)
        let byID = Dictionary(uniqueKeysWithValues: service.exercises.map { ($0.id, $0) })
        return recentIDs.compactMap { byID[$0] }
    }

    private var results: [ExerciseLibraryItem] {
        service.filtered(
            levels: [],
            rawEquipment: [],
            primaryMuscles: [],
            secondaryMuscles: [],
            forces: [],
            mechanics: [],
            categories: [],
            sort: .name,
            searchText: searchText
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if searchText.trimmed.isEmpty, !recentItems.isEmpty {
                    Section("Recent") {
                        ForEach(recentItems) { item in
                            pickerButton(item)
                        }
                    }
                }

                Section(searchText.trimmed.isEmpty ? "All exercises" : "Results") {
                    if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ForEach(results) { item in
                            pickerButton(item)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WorkoutBackground())
            .navigationTitle("Choose exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func pickerButton(_ item: ExerciseLibraryItem) -> some View {
        let isSelected = selectedExerciseIDs.contains(item.id)

        return Button {
            guard !isSelected else { return }
            onSelect(item)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.workoutAccent)
                    .frame(width: 36, height: 36)
                    .background(Color.workoutAccent.opacity(0.11), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .multilineTextAlignment(.leading)

                    Text([item.primaryMusclesTitle, item.rawEquipment].filter { $0 != "Unspecified" }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Color.workoutMutedText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.workoutAccent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSelected)
        .accessibilityLabel(item.name)
        .accessibilityValue(isSelected ? "Already added" : "")
    }
}

// MARK: - Exercise progress

struct StrengthExerciseProgressView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    let exerciseID: String
    let exerciseName: String

    private var useMetric: Bool { weightUnitRaw == WeightUnit.kg.rawValue }
    private var history: [StrengthExerciseHistoryEntry] { store.exerciseHistory(for: exerciseID) }
    private var chartPoints: [StrengthProgressPoint] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return history
            .filter { $0.date >= cutoff }
            .compactMap { entry in
                let performance = StrengthExercisePerformance(sets: entry.exercise.sets)
                guard let reps = performance.bestReps else { return nil }
                return StrengthProgressPoint(id: entry.id, date: entry.date, value: Double(reps))
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        List {
            Section {
                StrengthProgressChart(
                    points: chartPoints,
                    metricName: "reps"
                )
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 12, trailing: 20))
            } header: {
                Text("Last 30 days")
                    .textCase(nil)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section("History") {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Log this exercise to start its progress history.")
                    )
                } else {
                    ForEach(history) { entry in
                        StrengthExerciseHistoryRow(entry: entry, useMetric: useMetric)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(WorkoutBackground())
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color.workoutBackground, for: .navigationBar)
    }
}

private struct StrengthProgressPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

private struct StrengthProgressChart: View {
    let points: [StrengthProgressPoint]
    let metricName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Best set")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                    Text(latestValue)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.workoutCharcoal)
                }

                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.workoutAccent)
                    .frame(width: 42, height: 42)
                    .background(Color.workoutAccent.opacity(0.11), in: Circle())
            }

            if points.isEmpty {
                ContentUnavailableView(
                    "No recent workouts",
                    systemImage: "calendar.badge.clock",
                    description: Text("Your next log will appear here.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value(metricName, point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.workoutAccent.opacity(0.28), Color.workoutAccent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value(metricName, point.value)
                    )
                    .foregroundStyle(Color.workoutAccent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value(metricName, point.value)
                    )
                    .foregroundStyle(Color.workoutAccent)
                    .symbolSize(45)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.workoutHairline.opacity(0.20))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.workoutHairline.opacity(0.25))
                        AxisValueLabel()
                    }
                }
                .frame(height: 190)
                .accessibilityLabel("30-day best set chart in \(metricName)")
            }
        }
        .padding(18)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.34), lineWidth: 0.7)
        }
    }

    private var latestValue: String {
        guard let value = points.last?.value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(metricName)"
    }
}

private struct StrengthExerciseHistoryRow: View {
    @Environment(StrengthWorkoutStore.self) private var store
    let entry: StrengthExerciseHistoryEntry
    let useMetric: Bool

    private var comparison: StrengthPersonalRecordComparison? {
        guard let session = store.session(id: entry.sessionID) else { return nil }
        return store.personalRecordComparison(for: entry.exercise.exerciseID, in: session)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.subheadline.weight(.semibold))
                    Text(entry.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(Color.workoutMutedText)
                }

                Spacer(minLength: 8)

                if comparison?.hasPersonalRecord == true {
                    Label("PR", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.green)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(Array(entry.exercise.sets.enumerated()), id: \.element.id) { index, set in
                        Text(setLabel(index: index, set: set))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.workoutCharcoal)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.workoutPanel.opacity(0.38), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private func setLabel(index: Int, set: StrengthWorkoutSet) -> String {
        if let weightKg = set.weightKg {
            return "\(index + 1) · \(set.reps) × \(StrengthWeightFormat.display(weightKg, metric: useMetric)) \(StrengthWeightFormat.unit(metric: useMetric))"
        }
        return set.isBodyweight
            ? "\(index + 1) · \(set.reps) reps · BW"
            : "\(index + 1) · \(set.reps) reps"
    }
}

// MARK: - Formatting

private enum StrengthWeightFormat {
    private static let poundsPerKilogram = 2.204_622_621_8

    static func unit(metric: Bool) -> String { metric ? "kg" : "lb" }

    static func displayValue(_ kilograms: Double, metric: Bool) -> Double {
        metric ? kilograms : kilograms * poundsPerKilogram
    }

    static func kilograms(_ displayValue: Double, metric: Bool) -> Double {
        metric ? displayValue : displayValue / poundsPerKilogram
    }

    static func display(_ kilograms: Double, metric: Bool) -> String {
        displayValue(kilograms, metric: metric)
            .formatted(.number.precision(.fractionLength(0...1)))
    }

    static func editable(_ kilograms: Double, metric: Bool) -> String {
        display(kilograms, metric: metric)
    }

    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        guard let value = Double(trimmed.replacingOccurrences(of: decimalSeparator, with: ".")),
              value.isFinite
        else { return nil }
        return value
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
