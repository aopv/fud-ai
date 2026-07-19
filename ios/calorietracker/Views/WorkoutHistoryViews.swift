import Charts
import SwiftUI

/// Standalone history surface for completed, local workout sessions.
struct WorkoutHistoryView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var pendingDeletion: StrengthWorkoutSession?

    var body: some View {
        NavigationStack {
            Group {
                if store.sortedCompletedSessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .background(WorkoutBackground())
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.workoutBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.workoutAccent)
                    .accessibilityHint("Closes workout history")
                }
            }
        }
        .tint(Color.workoutAccent)
        .confirmationDialog(
            "Delete Workout?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { isPresented in
                    if !isPresented { pendingDeletion = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { session in
            Button("Delete Workout", role: .destructive) {
                withAnimation(.snappy) {
                    _ = store.deleteCompletedSession(id: session.id)
                }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: { session in
            Text("This permanently removes \(session.workoutDisplayName) and its logged sets from this device.")
        }
    }

    private var sessionList: some View {
        List {
            Section {
                ForEach(store.sortedCompletedSessions) { session in
                    NavigationLink {
                        WorkoutSessionHistoryDetailView(session: session)
                    } label: {
                        WorkoutHistorySessionCard(session: session)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            pendingDeletion = session
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityHint("Opens this workout summary. Swipe left for delete.")
                }
            } header: {
                Text("Completed workouts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.workoutMutedText)
                    .textCase(nil)
                    .padding(.bottom, 2)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No completed workouts", systemImage: "figure.strengthtraining.traditional")
        } description: {
            Text("Finish your first workout and its sets, progress, and personal records will appear here.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .workoutScreen()
    }
}

/// Result surface shown immediately after a session is completed.
struct WorkoutCompletionSummaryView: View {
    @Environment(StrengthWorkoutStore.self) private var store

    let session: StrengthWorkoutSession
    let onDone: () -> Void

    var body: some View {
        ZStack {
            WorkoutBackground()

            ScrollView {
                VStack(spacing: 18) {
                    completionHeader

                    WorkoutSummaryMetricsCard(session: session, personalRecordCount: personalRecordCount)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your workout")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.workoutCharcoal)

                        ForEach(session.exercises.filter(\.hasRecordedSets)) { exercise in
                            WorkoutSummaryExerciseCard(
                                exercise: exercise,
                                comparison: store.personalRecordComparison(
                                    for: exercise.exerciseID,
                                    in: session
                                )
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 116)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onDone) {
                Text("Done")
                    .font(.headline.weight(.bold))
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
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.ultraThinMaterial)
            .accessibilityHint("Closes the completed workout summary")
        }
    }

    private var completionHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 27, weight: .black))
                .foregroundStyle(Color.workoutOnAccent)
                .frame(width: 66, height: 66)
                .background(
                    LinearGradient(
                        colors: AppColors.calorieGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .shadow(color: AppColors.calorie.opacity(0.24), radius: 8, y: 4)

            VStack(spacing: 5) {
                Text("Workout complete")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.workoutCharcoal)

                Text(session.workoutDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.workoutMutedText)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout complete, \(session.workoutDisplayName)")
    }

    private var personalRecordCount: Int {
        session.exercises.reduce(into: 0) { count, exercise in
            guard let comparison = store.personalRecordComparison(
                for: exercise.exerciseID,
                in: session
            ) else { return }
            if comparison.isRepetitionPR { count += 1 }
            if comparison.isWeightPR { count += 1 }
        }
    }
}

private struct WorkoutHistorySessionCard: View {
    @Environment(StrengthWorkoutStore.self) private var store

    let session: StrengthWorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.workoutDisplayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .lineLimit(1)

                    Text(session.historyDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(Color.workoutMutedText)
                }

                Spacer(minLength: 8)

                if personalRecordCount > 0 {
                    Label("\(personalRecordCount) PR\(personalRecordCount == 1 ? "" : "s")", systemImage: "trophy.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.workoutAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.workoutAccent.opacity(0.11), in: Capsule())
                }
            }

            HStack(spacing: 18) {
                WorkoutInlineMetric(
                    value: "\(session.exerciseCount)",
                    label: session.exerciseCount == 1 ? "exercise" : "exercises"
                )
                WorkoutInlineMetric(
                    value: "\(session.setCount)",
                    label: session.setCount == 1 ? "set" : "sets"
                )
                if let duration = session.duration {
                    WorkoutInlineMetric(value: duration.workoutDurationText, label: "duration")
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.workoutMutedText.opacity(0.65))
            }
        }
        .padding(16)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var personalRecordCount: Int {
        session.exercises.reduce(into: 0) { count, exercise in
            guard let comparison = store.personalRecordComparison(
                for: exercise.exerciseID,
                in: session
            ) else { return }
            if comparison.isRepetitionPR { count += 1 }
            if comparison.isWeightPR { count += 1 }
        }
    }

    private var accessibilitySummary: String {
        let recordText = personalRecordCount == 0
            ? ""
            : ", \(personalRecordCount) personal records"
        return "\(session.workoutDisplayName), \(session.historyDate.formatted(date: .long, time: .omitted)), \(session.exerciseCount) exercises, \(session.setCount) sets\(recordText)"
    }
}

private struct WorkoutSessionHistoryDetailView: View {
    @Environment(StrengthWorkoutStore.self) private var store

    let session: StrengthWorkoutSession

    var body: some View {
        ZStack {
            WorkoutBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.workoutDisplayName)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.workoutCharcoal)

                        Text(session.historyDate, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                            .font(.subheadline)
                            .foregroundStyle(Color.workoutMutedText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    WorkoutSummaryMetricsCard(
                        session: session,
                        personalRecordCount: personalRecordCount
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Exercises")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.workoutCharcoal)

                        ForEach(session.exercises.filter(\.hasRecordedSets)) { exercise in
                            NavigationLink {
                                WorkoutExerciseHistoryDetailView(
                                    exerciseID: exercise.exerciseID,
                                    exerciseName: exercise.exerciseName
                                )
                            } label: {
                                WorkoutSummaryExerciseCard(
                                    exercise: exercise,
                                    comparison: store.personalRecordComparison(
                                        for: exercise.exerciseID,
                                        in: session
                                    ),
                                    showsDisclosure: true
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Shows 30-day progress and all logged sets for this exercise")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var personalRecordCount: Int {
        session.exercises.reduce(into: 0) { count, exercise in
            guard let comparison = store.personalRecordComparison(
                for: exercise.exerciseID,
                in: session
            ) else { return }
            if comparison.isRepetitionPR { count += 1 }
            if comparison.isWeightPR { count += 1 }
        }
    }
}

private struct WorkoutExerciseHistoryDetailView: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    let exerciseID: String
    let exerciseName: String

    private var history: [StrengthExerciseHistoryEntry] {
        store.exerciseHistory(for: exerciseID)
    }

    private var chartPoints: [WorkoutExerciseChartPoint] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        return history.compactMap { entry in
            guard entry.completedAt >= start,
                  entry.completedAt <= .now,
                  let bestReps = entry.exercise.recordedSets.map(\.reps).max()
            else { return nil }
            return WorkoutExerciseChartPoint(
                id: entry.id,
                date: entry.completedAt,
                bestReps: bestReps
            )
        }
        .sorted { $0.date < $1.date }
    }

    var body: some View {
        ZStack {
            WorkoutBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    progressCard

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set history")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.workoutCharcoal)

                        if history.isEmpty {
                            Text("No completed sets yet.")
                                .font(.subheadline)
                                .foregroundStyle(Color.workoutMutedText)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 34)
                                .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            ForEach(history) { entry in
                                WorkoutExerciseHistoryCard(
                                    entry: entry,
                                    comparison: comparison(for: entry),
                                    useMetric: weightUnitRaw == WeightUnit.kg.rawValue
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Best reps")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.workoutCharcoal)

                Text("Last 30 days · best set per workout")
                    .font(.caption)
                    .foregroundStyle(Color.workoutMutedText)
            }

            if chartPoints.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundStyle(Color.workoutAccent)
                    Text("Complete a workout with this exercise to start the chart.")
                        .font(.subheadline)
                        .foregroundStyle(Color.workoutMutedText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                Chart(chartPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Best reps", point.bestReps)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.calorie.opacity(0.24), AppColors.calorie.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Best reps", point.bestReps)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Color.workoutAccent)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Best reps", point.bestReps)
                    )
                    .symbolSize(42)
                    .foregroundStyle(Color.workoutAccent)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine().foregroundStyle(Color.workoutHairline.opacity(0.18))
                        AxisTick().foregroundStyle(Color.workoutHairline.opacity(0.45))
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(Color.workoutMutedText)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.workoutHairline.opacity(0.22))
                        AxisValueLabel()
                            .foregroundStyle(Color.workoutMutedText)
                    }
                }
                .frame(height: 190)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Best repetitions over the last 30 days")
                .accessibilityValue(chartAccessibilityValue)
            }
        }
        .padding(16)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.6)
        }
    }

    private var chartAccessibilityValue: String {
        chartPoints
            .map { "\($0.date.formatted(date: .abbreviated, time: .omitted)): \($0.bestReps) reps" }
            .joined(separator: ", ")
    }

    private func comparison(
        for entry: StrengthExerciseHistoryEntry
    ) -> StrengthPersonalRecordComparison? {
        guard let session = store.completedSession(id: entry.sessionID) else { return nil }
        return store.personalRecordComparison(for: exerciseID, in: session)
    }
}

private struct WorkoutSummaryMetricsCard: View {
    let session: StrengthWorkoutSession
    let personalRecordCount: Int

    var body: some View {
        HStack(spacing: 0) {
            metric(value: "\(session.exerciseCount)", label: "Exercises")
            divider
            metric(value: "\(session.setCount)", label: "Sets")

            if let duration = session.duration {
                divider
                metric(value: duration.workoutDurationText, label: "Time")
            }

            if personalRecordCount > 0 {
                divider
                metric(value: "\(personalRecordCount)", label: "PRs", isAccent: true)
            }
        }
        .padding(.vertical, 16)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.exerciseCount) exercises, \(session.setCount) sets, \(personalRecordCount) personal records")
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.workoutHairline.opacity(0.32))
            .frame(width: 0.5, height: 32)
    }

    private func metric(value: String, label: String, isAccent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(isAccent ? Color.workoutAccent : Color.workoutCharcoal)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.workoutMutedText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WorkoutSummaryExerciseCard: View {
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    let exercise: StrengthWorkoutExercise
    let comparison: StrengthPersonalRecordComparison?
    var showsDisclosure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exerciseName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .lineLimit(2)

                    Text("\(exercise.recordedSets.count) \(exercise.recordedSets.count == 1 ? "set" : "sets")")
                        .font(.caption)
                        .foregroundStyle(Color.workoutMutedText)
                }

                Spacer(minLength: 8)

                if comparison?.hasPersonalRecord == true {
                    Label("PR", systemImage: "trophy.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.workoutAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.workoutAccent.opacity(0.11), in: Capsule())
                }

                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.workoutMutedText.opacity(0.65))
                }
            }

            if !recordLabels.isEmpty {
                HStack(spacing: 7) {
                    ForEach(recordLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.workoutAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.workoutAccent.opacity(0.10), in: Capsule())
                    }
                }
            }

            Text(setSummary)
                .font(.subheadline)
                .foregroundStyle(Color.workoutMutedText)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.exerciseName), \(exercise.recordedSets.count) sets, \(setSummary)\(recordLabels.isEmpty ? "" : ", " + recordLabels.joined(separator: ", "))")
    }

    private var recordLabels: [String] {
        guard let comparison else { return [] }
        var labels: [String] = []
        if comparison.isRepetitionPR {
            if let change = comparison.repetitionChange, change > 0 {
                labels.append("+\(change) reps PR")
            } else {
                labels.append("Reps PR")
            }
        }
        if comparison.isWeightPR {
            labels.append("Weight PR")
        }
        return labels
    }

    private var setSummary: String {
        exercise.recordedSets.enumerated().map { index, set in
            if set.isBodyweight {
                return "\(set.reps) reps · bodyweight"
            }
            if let weightKg = set.weightKg {
                return "\(set.reps) × \(formattedWeight(weightKg))"
            }
            return "\(set.reps) reps"
        }
        .joined(separator: "  ·  ")
    }

    private func formattedWeight(_ weightKg: Double) -> String {
        if weightUnitRaw == WeightUnit.kg.rawValue {
            return "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
        }
        let pounds = StrengthWorkoutWeight.pounds(fromKilograms: weightKg)
        return "\(pounds.formatted(.number.precision(.fractionLength(0...1)))) lb"
    }
}

private struct WorkoutExerciseHistoryCard: View {
    let entry: StrengthExerciseHistoryEntry
    let comparison: StrengthPersonalRecordComparison?
    let useMetric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.completedAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.workoutCharcoal)

                    if let sessionName = entry.sessionName {
                        Text(sessionName)
                            .font(.caption)
                            .foregroundStyle(Color.workoutMutedText)
                    }
                }

                Spacer(minLength: 8)

                if comparison?.hasPersonalRecord == true {
                    Label("PR", systemImage: "trophy.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.workoutAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.workoutAccent.opacity(0.11), in: Capsule())
                }
            }

            VStack(spacing: 9) {
                ForEach(Array(entry.exercise.recordedSets.enumerated()), id: \.element.id) { index, set in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(Color.workoutAccent)
                            .frame(width: 28, height: 28)
                            .background(Color.workoutAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Text("\(set.reps) reps")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.workoutCharcoal)

                        Spacer(minLength: 8)

                        Text(loadText(for: set))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.workoutMutedText)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Set \(index + 1), \(set.reps) reps, \(loadText(for: set))")

                    if set.id != entry.exercise.recordedSets.last?.id {
                        Divider()
                            .overlay(Color.workoutHairline.opacity(0.24))
                            .padding(.leading, 40)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.workoutCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.6)
        }
    }

    private func loadText(for set: StrengthWorkoutSet) -> String {
        if set.isBodyweight { return "Bodyweight" }
        guard let weightKg = set.weightKg else { return "No load" }

        if useMetric {
            return "\(weightKg.formatted(.number.precision(.fractionLength(0...1)))) kg"
        }
        let pounds = StrengthWorkoutWeight.pounds(fromKilograms: weightKg)
        return "\(pounds.formatted(.number.precision(.fractionLength(0...1)))) lb"
    }
}

private struct WorkoutInlineMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.workoutCharcoal)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.workoutMutedText)
        }
    }
}

private struct WorkoutExerciseChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let bestReps: Int
}

private extension StrengthWorkoutSession {
    var workoutDisplayName: String {
        name ?? "Workout"
    }

    var historyDate: Date {
        completedAt ?? startedAt
    }
}

private extension TimeInterval {
    var workoutDurationText: String {
        let totalMinutes = max(1, Int((self / 60).rounded()))
        if totalMinutes < 60 { return "\(totalMinutes)m" }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}
