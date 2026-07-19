import Foundation
import SwiftUI

/// The single session-first entry point shown above the Workouts tab bar.
/// It starts a local draft on first tap and becomes a compact resume surface
/// while that draft is active.
struct WorkoutSessionDock: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onOpen: () -> Void

    init(onOpen: @escaping () -> Void) {
        self.onOpen = onOpen
    }

    var body: some View {
        Button(action: openWorkout) {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: AppColors.calorieGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Image(systemName: store.activeSession == nil ? "play.fill" : "figure.strengthtraining.traditional")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.workoutOnAccent)
                    }
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.activeSession == nil ? "Start workout" : resumeTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.workoutCharcoal)
                            .lineLimit(1)

                        Text(detailText(at: context.date))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.workoutMutedText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Text(store.activeSession == nil ? "Start" : "Resume")
                            .font(.subheadline.weight(.bold))

                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.workoutOnAccent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(
                        LinearGradient(
                            colors: AppColors.calorieGradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .padding(10)
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .workoutPressable()
        .workoutLiquidBarSurface(cornerRadius: 24)
        .animation(reduceMotion ? nil : .snappy(duration: 0.28), value: store.activeSession?.id)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(store.activeSession == nil ? "Starts a new workout." : "Opens your saved workout in progress.")
    }

    private var resumeTitle: String {
        store.activeSession?.name ?? String(localized: "Workout in progress")
    }

    private var accessibilityLabel: String {
        guard let session = store.activeSession else { return String(localized: "Start workout") }
        return String(localized: "Resume \(resumeTitle), \(session.exercises.count) exercises, \(session.setCount) completed sets")
    }

    private func detailText(at date: Date) -> String {
        guard let session = store.activeSession else {
            return String(localized: "Sets, reps, and weight — saved locally")
        }

        let elapsed = max(0, Int(date.timeIntervalSince(session.startedAt)))
        let minutes = elapsed / 60
        let duration = minutes >= 60
            ? String(format: "%d:%02d", minutes / 60, minutes % 60)
            : String(localized: "\(minutes) min")
        let exerciseWord = session.exercises.count == 1 ? String(localized: "exercise") : String(localized: "exercises")
        let setWord = session.setCount == 1 ? String(localized: "set") : String(localized: "sets")
        return "\(duration)  •  \(session.exercises.count) \(exerciseWord)  •  \(session.setCount) \(setWord)"
    }

    private func openWorkout() {
        if store.activeSession == nil {
            store.startSession()
        }
        onOpen()
    }
}

/// A contextual bridge from an exercise detail page into the active session.
/// The card stays informative when no history exists and becomes a one-tap
/// “add and resume” action when a workout is already underway.
struct ExerciseWorkoutActionCard: View {
    @Environment(StrengthWorkoutStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue

    let item: ExerciseLibraryItem
    let onOpen: () -> Void

    init(item: ExerciseLibraryItem, onOpen: @escaping () -> Void) {
        self.item = item
        self.onOpen = onOpen
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lbs
    }

    private var latest: StrengthExerciseHistoryEntry? {
        store.exerciseHistory(for: item.id).first
    }

    private var latestPerformance: StrengthExercisePerformance? {
        latest.map { StrengthExercisePerformance(sets: $0.exercise.sets) }
    }

    private var isAdded: Bool {
        store.activeSession?.exercises.contains { $0.exerciseID == item.id } == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.workoutAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.workoutAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Track this exercise")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.workoutCharcoal)

                    if let latest {
                        Text("Last logged \(latest.completedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.workoutMutedText)
                    } else {
                        Text("Your first set starts a private, local history.")
                            .font(.caption)
                            .foregroundStyle(Color.workoutMutedText)
                    }
                }

                Spacer(minLength: 0)
            }

            if let performance = latestPerformance {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        performanceMetric(title: "Best reps", value: performance.bestReps.map(String.init) ?? "—")
                        performanceMetric(title: "Best weight", value: formattedWeight(performance.bestWeightKg))
                    }

                    VStack(spacing: 10) {
                        performanceMetric(title: "Best reps", value: performance.bestReps.map(String.init) ?? "—")
                        performanceMetric(title: "Best weight", value: formattedWeight(performance.bestWeightKg))
                    }
                }
            }

            Button(action: addAndOpen) {
                HStack(spacing: 8) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : (store.activeSession == nil ? "play.fill" : "plus"))
                    Text(buttonTitle)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.workoutOnAccent)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    LinearGradient(
                        colors: AppColors.calorieGradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .workoutPressable()
            .accessibilityHint(isAdded ? "Opens this exercise in your workout." : "Adds this exercise and opens your workout.")
        }
        .padding(18)
        .workoutLiquidBarSurface(cornerRadius: 22)
        .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: isAdded)
        .accessibilityElement(children: .contain)
    }

    private var buttonTitle: String {
        if isAdded { return String(localized: "Added — open workout") }
        if store.activeSession != nil { return String(localized: "Add to workout") }
        return String(localized: "Start with this exercise")
    }

    private func performanceMetric(title: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.workoutMutedText)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Color.workoutCharcoal)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.workoutPanel.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.26), lineWidth: 0.5)
        }
    }

    private func formattedWeight(_ kilograms: Double?) -> String {
        guard let kilograms else { return "—" }
        let value = weightUnit == .kg
            ? kilograms
            : StrengthWorkoutWeight.pounds(fromKilograms: kilograms)
        let number = value.formatted(.number.precision(.fractionLength(0...1)))
        return "\(number) \(weightUnit.rawValue)"
    }

    private func addAndOpen() {
        if store.activeSession == nil {
            store.startSession()
        }

        if !isAdded,
           let entryID = store.addExercise(
               exerciseID: item.id,
               exerciseName: item.name,
               autofillFromHistory: true
           ),
           store.activeSession?.exercises.first(where: { $0.id == entryID })?.sets.isEmpty == true {
            store.addSet(to: entryID)
        }

        onOpen()
    }
}
