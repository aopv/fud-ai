import SwiftUI
import UIKit

struct ActiveWorkoutSessionView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    let onFinished: (StrengthWorkoutSession) -> Void
    let onClosed: () -> Void

    @State private var sessionName = ""
    @State private var hasLoadedSessionName = false
    @State private var showsExercisePicker = false
    @State private var showsDiscardConfirmation = false

    init(
        onFinished: @escaping (StrengthWorkoutSession) -> Void,
        onClosed: @escaping () -> Void
    ) {
        self.onFinished = onFinished
        self.onClosed = onClosed
    }

    private var session: StrengthWorkoutSession? {
        store.activeSession
    }

    private var usesMetricWeight: Bool {
        weightUnitRaw == WeightUnit.kg.rawValue
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WorkoutBackground()

                if let session {
                    sessionEditor(session)
                } else {
                    ProgressView("Preparing workout…")
                        .tint(Color.workoutAccent)
                        .foregroundStyle(Color.workoutMutedText)
                }
            }
            .navigationTitle("Active workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.workoutBackground.opacity(0.96), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClosed) {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                    .foregroundStyle(Color.workoutCharcoal)
                    .accessibilityLabel("Close workout")
                    .accessibilityHint("Keeps this workout so you can resume it later")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Weight unit", selection: $weightUnitRaw) {
                            Text("Kilograms").tag(WeightUnit.kg.rawValue)
                            Text("Pounds").tag(WeightUnit.lbs.rawValue)
                        }

                        Divider()

                        Button("Discard workout", systemImage: "trash", role: .destructive) {
                            showsDiscardConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .frame(width: 34, height: 34)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                    .foregroundStyle(Color.workoutCharcoal)
                    .accessibilityLabel("Workout options")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                finishBar
            }
        }
        .tint(Color.workoutAccent)
        .onAppear(perform: prepareSession)
        .onChange(of: sessionName) { _, newName in
            guard hasLoadedSessionName else { return }
            store.renameActiveSession(newName)
        }
        .sheet(isPresented: $showsExercisePicker) {
            WorkoutExercisePicker { exercise in
                addExercise(exercise)
            }
            .environment(store)
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard workout", role: .destructive) {
                store.discardActiveSession()
                onClosed()
            }
            Button("Keep workout", role: .cancel) {}
        } message: {
            Text("Your completed workout history will stay safe, but this in-progress workout will be deleted.")
        }
    }

    private func sessionEditor(_ session: StrengthWorkoutSession) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                WorkoutSessionHeader(
                    startedAt: session.startedAt,
                    sessionName: $sessionName
                )

                if session.exercises.isEmpty {
                    emptyExercises
                } else {
                    ForEach(session.exercises) { exercise in
                        WorkoutExerciseCard(
                            exercise: exercise,
                            sessionStartedAt: session.startedAt,
                            usesMetricWeight: usesMetricWeight,
                            onRemoveExercise: {
                                performAnimated {
                                    store.removeExercise(id: exercise.id)
                                }
                            }
                        )
                        .environment(store)
                    }
                }

                Button {
                    showsExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.headline)
                        .foregroundStyle(Color.workoutAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .workoutPressable()
                .workoutLiquidBarSurface(cornerRadius: 18)
                .accessibilityHint("Opens the exercise library")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .workoutScreen()
    }

    private var emptyExercises: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.workoutAccent.opacity(0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "dumbbell.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.workoutAccent)
            }

            VStack(spacing: 5) {
                Text("Build your workout")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.workoutCharcoal)

                Text("Add an exercise, then record reps and weight set by set.")
                    .font(.subheadline)
                    .foregroundStyle(Color.workoutMutedText)
                    .multilineTextAlignment(.center)
            }

            Button {
                showsExercisePicker = true
            } label: {
                Label("Choose an exercise", systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.workoutOnAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .background(
                        LinearGradient(
                            colors: AppColors.calorieGradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .workoutPressable()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 30)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.35), lineWidth: 0.7)
        }
    }

    private var finishBar: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.workoutHairline.opacity(0.45))

            Button(action: finishWorkout) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.black))

                    Text("Finish workout")
                        .font(.headline)
                }
                .foregroundStyle(Color.workoutOnAccent)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    LinearGradient(
                        colors: AppColors.calorieGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(
                    color: canFinish ? Color.workoutAccent.opacity(0.22) : .clear,
                    radius: 8,
                    y: 4
                )
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .disabled(!canFinish)
            .accessibilityHint(canFinish ? "Saves this workout to your history" : "Record at least one set first")
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .background(Color.workoutBackground.opacity(0.96))
    }

    private var canFinish: Bool {
        session?.hasRecordedSets == true
    }

    private func prepareSession() {
        if store.activeSession == nil {
            store.startSession()
        }

        sessionName = store.activeSession?.name ?? ""
        hasLoadedSessionName = true
    }

    private func addExercise(_ exercise: ExerciseLibraryItem) {
        guard let entryID = store.addExercise(
            exerciseID: exercise.id,
            exerciseName: exercise.name
        ) else { return }

        if store.activeSession?.exercises.first(where: { $0.id == entryID })?.sets.isEmpty == true {
            store.addSet(to: entryID)
        }
        showsExercisePicker = false
    }

    private func finishWorkout() {
        guard let completed = store.completeActiveSession() else { return }
        onFinished(completed)
    }

    private func performAnimated(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.snappy(duration: 0.25), change)
        }
    }
}

private struct WorkoutSessionHeader: View {
    let startedAt: Date
    @Binding var sessionName: String

    @FocusState private var nameIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.workoutOnAccent)
                            .frame(width: 7, height: 7)
                            .accessibilityHidden(true)

                        Text(elapsedTime(at: context.date))
                            .font(.title2.weight(.bold).monospacedDigit())
                            .contentTransition(.numericText())
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(elapsedAccessibilityValue(at: context.date))
                }

                Spacer(minLength: 8)

                Text("IN PROGRESS")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 28)
                    .background(Color.workoutOnAccent.opacity(0.16), in: Capsule())
            }
            .foregroundStyle(Color.workoutOnAccent)

            VStack(alignment: .leading, spacing: 5) {
                Text("WORKOUT NAME")
                    .font(.caption2.weight(.bold))
                    .tracking(0.65)
                    .foregroundStyle(Color.workoutOnAccent.opacity(0.72))

                TextField("Today’s workout", text: $sessionName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.workoutOnAccent)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .focused($nameIsFocused)
                    .submitLabel(.done)
                    .onSubmit { nameIsFocused = false }
                    .accessibilityLabel("Workout name")
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: AppColors.calorieGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .shadow(color: Color.workoutAccent.opacity(0.18), radius: 8, y: 4)
    }

    private func elapsedTime(at date: Date) -> String {
        let totalSeconds = max(0, Int(date.timeIntervalSince(startedAt)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func elapsedAccessibilityValue(at date: Date) -> String {
        let totalSeconds = max(0, Int(date.timeIntervalSince(startedAt)))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return "\(hours) hours, \(minutes) minutes, \(seconds) seconds"
    }
}

private struct WorkoutExerciseCard: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let exercise: StrengthWorkoutExercise
    let sessionStartedAt: Date
    let usesMetricWeight: Bool
    let onRemoveExercise: () -> Void

    private var previousSets: [StrengthWorkoutSet] {
        store.previousSets(for: exercise.exerciseID, before: sessionStartedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader

            Divider()
                .overlay(Color.workoutHairline.opacity(0.38))

            if exercise.sets.isEmpty {
                noSetsContent
            } else {
                VStack(spacing: 0) {
                    setColumnHeader

                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        WorkoutSetEditorRow(
                            exerciseEntryID: exercise.id,
                            exerciseName: exercise.exerciseName,
                            setNumber: index + 1,
                            set: set,
                            previousSet: previousSets.indices.contains(index) ? previousSets[index] : nil,
                            usesMetricWeight: usesMetricWeight
                        )
                        .environment(store)

                        if set.id != exercise.sets.last?.id {
                            Divider()
                                .overlay(Color.workoutHairline.opacity(0.22))
                                .padding(.leading, 42)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }

            Divider()
                .overlay(Color.workoutHairline.opacity(0.38))

            HStack(spacing: 10) {
                Button {
                    performAnimated {
                        store.addSet(to: exercise.id)
                    }
                } label: {
                    Label("Add set", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.workoutAccent)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.plain)
                .workoutPressable()

                if exercise.sets.isEmpty && !previousSets.isEmpty {
                    Divider()
                        .frame(height: 22)

                    Button {
                        performAnimated {
                            store.autofillActiveExercise(id: exercise.id)
                        }
                    } label: {
                        Label("Use last", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.workoutAccent)
                            .frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                    .accessibilityHint("Copies the sets from your last \(exercise.exerciseName) workout")
                }
            }
            .padding(.horizontal, 8)
        }
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.38), lineWidth: 0.7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.workoutAccent.opacity(0.12))

                Image(systemName: "dumbbell.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.workoutAccent)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .foregroundStyle(Color.workoutCharcoal)
                    .lineLimit(2)

                Text(previousSummary)
                    .font(.caption)
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Remove exercise", systemImage: "trash", role: .destructive, action: onRemoveExercise)

                if !exercise.sets.isEmpty {
                    Divider()
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        Button("Remove set \(index + 1)", systemImage: "minus.circle", role: .destructive) {
                            store.removeSet(exerciseID: exercise.id, setID: set.id)
                        }
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline)
                    .foregroundStyle(Color.workoutMutedText)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .accessibilityLabel("Options for \(exercise.exerciseName)")
        }
        .padding(14)
    }

    private var setColumnHeader: some View {
        HStack(spacing: 8) {
            Text("SET")
                .frame(width: 44, alignment: .leading)
            Text("LAST")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("REPS")
                .frame(width: 58)
            Text(usesMetricWeight ? "KG" : "LBS")
                .frame(width: 120)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Color.workoutMutedText)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    private var noSetsContent: some View {
        VStack(spacing: 8) {
            Text(previousSets.isEmpty ? "No sets yet" : "Your last sets are ready")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.workoutCharcoal)

            Text(previousSets.isEmpty ? "Add a set to start logging." : "Use them as a starting point or add a blank set.")
                .font(.caption)
                .foregroundStyle(Color.workoutMutedText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var previousSummary: String {
        if exercise.sets.contains(where: { !$0.isPerformed && $0.reps > 0 }) {
            return previousSets.isEmpty
                ? "Tap each set number when completed"
                : "Copied from last time · tap each set number to confirm"
        }
        guard !previousSets.isEmpty else { return "No previous sets" }
        let recordedCount = previousSets.filter(\.isRecorded).count
        return "Last time · \(recordedCount) \(recordedCount == 1 ? "set" : "sets")"
    }

    private func performAnimated(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.snappy(duration: 0.22), change)
        }
    }
}

private struct WorkoutSetEditorRow: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let exerciseEntryID: UUID
    let exerciseName: String
    let setNumber: Int
    let set: StrengthWorkoutSet
    let previousSet: StrengthWorkoutSet?
    let usesMetricWeight: Bool

    @State private var repsText: String
    @State private var weightText: String
    @State private var isBodyweight: Bool

    init(
        exerciseEntryID: UUID,
        exerciseName: String,
        setNumber: Int,
        set: StrengthWorkoutSet,
        previousSet: StrengthWorkoutSet?,
        usesMetricWeight: Bool
    ) {
        self.exerciseEntryID = exerciseEntryID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.set = set
        self.previousSet = previousSet
        self.usesMetricWeight = usesMetricWeight
        _repsText = State(initialValue: set.reps == 0 ? "" : String(set.reps))
        _weightText = State(initialValue: Self.displayWeight(set.weightKg, usesMetric: usesMetricWeight))
        _isBodyweight = State(initialValue: set.isBodyweight)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .padding(.vertical, 9)
        .onChange(of: repsText) { _, _ in persist() }
        .onChange(of: weightText) { _, _ in persist() }
        .onChange(of: usesMetricWeight) { oldValue, newValue in
            guard oldValue != newValue else { return }
            weightText = Self.displayWeight(set.weightKg, usesMetric: newValue)
        }
    }

    private var compactLayout: some View {
        HStack(spacing: 8) {
            performedButton

            Text(previousValue)
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.workoutMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(exerciseName), set \(setNumber), previous value")

            setTextField(
                title: "\(exerciseName), set \(setNumber), reps",
                text: $repsText,
                keyboard: .numberPad,
                width: 58
            )

            weightControl(width: 120)
        }
        .contextMenu {
            Button("Remove set", systemImage: "minus.circle", role: .destructive, action: removeSet)
        }
        .accessibilityAction(named: "Remove set") {
            removeSet()
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                performedButton

                Spacer()

                Button("Remove", systemImage: "minus.circle", role: .destructive) {
                    store.removeSet(exerciseID: exerciseEntryID, setID: set.id)
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .workoutPressable()
                .frame(minHeight: 44)
                .accessibilityLabel("Remove \(exerciseName), set \(setNumber)")
            }

            LabeledContent("Last") {
                Text(previousValue)
                    .monospacedDigit()
                    .foregroundStyle(Color.workoutMutedText)
            }

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                    setTextField(
                        title: "\(exerciseName), set \(setNumber), reps",
                        text: $repsText,
                        keyboard: .numberPad,
                        width: nil
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(usesMetricWeight ? "Weight (kg)" : "Weight (lbs)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                    weightControl(width: nil)
                }
            }
        }
    }

    private func setTextField(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        width: CGFloat?
    ) -> some View {
        TextField("—", text: text)
            .keyboardType(keyboard)
            .multilineTextAlignment(.center)
            .font(.body.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.workoutCharcoal)
            .frame(maxWidth: width == nil ? .infinity : width, minHeight: 44)
            .background(Color.workoutPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.workoutHairline.opacity(0.4), lineWidth: 0.6)
            }
            .accessibilityLabel(title)
            .accessibilityValue(text.wrappedValue.isEmpty ? "Not entered" : text.wrappedValue)
    }

    private func weightControl(width: CGFloat?) -> some View {
        Group {
            if isBodyweight {
                Button {
                    isBodyweight = false
                    persist()
                } label: {
                    Text("BW")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color.workoutOnAccent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.workoutAccent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .workoutPressable()
                .accessibilityLabel("\(exerciseName), set \(setNumber), bodyweight enabled")
                .accessibilityHint("Double tap to enter an external weight instead")
            } else {
                HStack(spacing: 4) {
                    TextField("—", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Color.workoutCharcoal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.workoutPanel.opacity(0.72), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.workoutHairline.opacity(0.4), lineWidth: 0.6)
                        }
                        .accessibilityLabel("\(exerciseName), set \(setNumber), weight in \(usesMetricWeight ? "kilograms" : "pounds")")

                    Button {
                        isBodyweight = true
                        weightText = ""
                        persist()
                    } label: {
                        Text("BW")
                            .font(.system(.caption2, design: .rounded, weight: .black))
                            .foregroundStyle(Color.workoutAccent)
                            .frame(width: 44, height: 44)
                            .background(Color.workoutAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .workoutPressable()
                    .accessibilityLabel("Use bodyweight for \(exerciseName), set \(setNumber)")
                }
            }
        }
        .frame(maxWidth: width == nil ? .infinity : width)
    }

    private var previousValue: String {
        guard let previousSet, previousSet.isRecorded else { return "—" }
        if previousSet.isBodyweight {
            return "\(previousSet.reps) × BW"
        }
        if let weightKg = previousSet.weightKg {
            let value = usesMetricWeight
                ? weightKg
                : StrengthWorkoutWeight.pounds(fromKilograms: weightKg)
            return "\(previousSet.reps) × \(Self.formattedNumber(value))"
        }
        return "\(previousSet.reps) reps"
    }

    private func persist() {
        let reps = max(0, Int(repsText) ?? 0)
        let enteredWeight = Self.parsedNumber(weightText)
        let kilograms: Double?
        if let enteredWeight {
            kilograms = usesMetricWeight
                ? enteredWeight
                : StrengthWorkoutWeight.kilograms(fromPounds: enteredWeight)
        } else {
            kilograms = nil
        }

        let normalizedWeightText = weightText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let displayedStoredWeight = Self.displayWeight(set.weightKg, usesMetric: usesMetricWeight)
        let weightIsUnchanged = isBodyweight
            ? set.isBodyweight
            : !set.isBodyweight && normalizedWeightText == displayedStoredWeight
        guard reps != set.reps || !weightIsUnchanged else { return }

        store.updateSet(
            exerciseID: exerciseEntryID,
            setID: set.id,
            reps: reps,
            weightKg: isBodyweight ? nil : kilograms,
            isBodyweight: isBodyweight
        )
    }

    private var performedButton: some View {
        Button {
            store.setPerformed(
                exerciseID: exerciseEntryID,
                setID: set.id,
                isPerformed: !set.isPerformed
            )
        } label: {
            Group {
                if set.isPerformed {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color.workoutOnAccent)
                } else {
                    Text("\(setNumber)")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.workoutAccent)
                }
            }
            .frame(width: 44, height: 44)
            .background(
                set.isPerformed ? Color.workoutAccent : Color.workoutAccent.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .workoutPressable()
        .disabled(set.reps <= 0)
        .accessibilityLabel("\(exerciseName), set \(setNumber)")
        .accessibilityValue(set.isPerformed ? "Completed" : "Not completed")
        .accessibilityHint(set.reps > 0 ? "Double tap to toggle completion" : "Enter repetitions before completing this set")
    }

    private func removeSet() {
        store.removeSet(exerciseID: exerciseEntryID, setID: set.id)
    }

    private static func displayWeight(_ kilograms: Double?, usesMetric: Bool) -> String {
        guard let kilograms else { return "" }
        let value = usesMetric ? kilograms : StrengthWorkoutWeight.pounds(fromKilograms: kilograms)
        return formattedNumber(value)
    }

    private static func formattedNumber(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded.rounded() == rounded {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    private static func parsedNumber(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }
}

private struct WorkoutExercisePicker: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ExerciseLibraryItem) -> Void

    @State private var searchText = ""
    private let service = ExerciseLibraryService.shared

    private var activeExerciseIDs: Set<String> {
        Set(store.activeSession?.exercises.map(\.exerciseID) ?? [])
    }

    private var availableExercises: [ExerciseLibraryItem] {
        service.exercises.filter { !activeExerciseIDs.contains($0.id) }
    }

    private var filteredExercises: [ExerciseLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableExercises }
        return availableExercises.filter { $0.searchableText.contains(query) }
    }

    private var recentExercises: [ExerciseLibraryItem] {
        let catalogByID = Dictionary(uniqueKeysWithValues: availableExercises.map { ($0.id, $0) })
        var seen = Set<String>()
        var result: [ExerciseLibraryItem] = []

        for session in store.sortedCompletedSessions {
            for exercise in session.exercises.reversed() where seen.insert(exercise.exerciseID).inserted {
                if let item = catalogByID[exercise.exerciseID] {
                    result.append(item)
                }
                if result.count == 6 { return result }
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WorkoutBackground()

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 14)

                    Divider()
                        .overlay(Color.workoutHairline.opacity(0.4))

                    if filteredExercises.isEmpty {
                        ContentUnavailableView {
                            Label("No exercises found", systemImage: "magnifyingglass")
                        } description: {
                            Text("Try another exercise, muscle, or equipment name.")
                        }
                    } else {
                        exerciseList
                    }
                }
            }
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.workoutBackground.opacity(0.96), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .workoutPressable()
                }
            }
        }
        .tint(Color.workoutAccent)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.workoutBackground)
    }

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.workoutSecondaryAccent)

            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.workoutMutedText)
                }
                .buttonStyle(.plain)
                .workoutPressable()
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .workoutLiquidBarSurface(cornerRadius: 20)
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   !recentExercises.isEmpty {
                    Section {
                        ForEach(recentExercises) { exercise in
                            pickerRow(exercise, isRecent: true)
                        }
                    } header: {
                        pickerSectionHeader("Recently logged")
                    }
                }

                Section {
                    ForEach(filteredExercises) { exercise in
                        pickerRow(exercise, isRecent: false)
                    }
                } header: {
                    pickerSectionHeader(searchText.isEmpty ? "All exercises" : "Results")
                }
            }
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func pickerSectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.65)
            .foregroundStyle(Color.workoutMutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 7)
            .background(Color.workoutBackground.opacity(0.96))
    }

    private func pickerRow(_ exercise: ExerciseLibraryItem, isRecent: Bool) -> some View {
        Button {
            onSelect(exercise)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.workoutAccent.opacity(0.11))

                    Image(systemName: isRecent ? "clock.arrow.circlepath" : "dumbbell.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.workoutAccent)
                }
                .frame(width: 42, height: 42)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text([exercise.primaryMuscles.first, exercise.rawEquipment]
                        .compactMap { $0 }
                        .filter { $0 != "Unspecified" }
                        .joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(Color.workoutMutedText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.workoutAccent)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .workoutPressable()
        .accessibilityLabel("Add \(exercise.name)")
    }
}
