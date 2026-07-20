import SwiftUI

/// Compact link beside Weight History and Body Fat History on Progress.
struct WorkoutHistoryLink: View {
    let sessions: [StrengthWorkoutSession]
    let onTap: () -> Void

    private var burnRecordCount: Int {
        sessions.filter { $0.caloriesBurned != nil }.count
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppColors.calorie)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout History")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("\(burnRecordCount) \(burnRecordCount == 1 ? "entry" : "entries") · tap to view or delete")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppColors.appCard, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens workout calorie history")
    }
}

/// Full chronological calorie-burn log reached from Progress.
struct WorkoutHistoryView: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    let sessions: [StrengthWorkoutSession]
    @State private var pendingDeletion: StrengthWorkoutSession?
    @State private var locallyDeletedSessionIDs: Set<UUID> = []

    private var chronologicalSessions: [StrengthWorkoutSession] {
        sessions
            .filter { $0.caloriesBurned != nil && !locallyDeletedSessionIDs.contains($0.id) }
            .sorted {
                if $0.stableDiaryDateKey == $1.stableDiaryDateKey {
                    return $0.completedAt > $1.completedAt
                }
                return $0.stableDiaryDateKey > $1.stableDiaryDateKey
            }
    }

    var body: some View {
        Group {
            if chronologicalSessions.isEmpty {
                ContentUnavailableView(
                    "No Calorie Burns Yet",
                    systemImage: "flame",
                    description: Text("Calculated workout calories will appear here with every exercise and set.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.appBackground)
            } else {
                List {
                    Section {
                        WorkoutHistoryTotals(sessions: chronologicalSessions)
                    }
                    .listRowBackground(AppColors.appCard)

                    Section("Calorie Burn Records") {
                        ForEach(chronologicalSessions) { session in
                            NavigationLink {
                                WorkoutSessionDetailView(session: session)
                            } label: {
                                WorkoutHistoryRow(session: session)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    pendingDeletion = session
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                        }
                    }
                    .listRowBackground(AppColors.appCard)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppColors.appBackground)
            }
        }
        .navigationTitle("Workout History")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this calorie burn?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Burn Record", role: .destructive) {
                guard let session = pendingDeletion else { return }
                locallyDeletedSessionIDs.insert(session.id)
                workoutStore.deleteSession(session.id)
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This deletes the calorie burn record and its matching sample from Apple Health. The dated workout plan stays in your diary.")
        }
    }
}

private struct WorkoutHistoryTotals: View {
    let sessions: [StrengthWorkoutSession]

    private var totalSets: Int { sessions.reduce(0) { $0 + $1.performedSetCount } }
    private var totalReps: Int { sessions.reduce(0) { $0 + $1.repCount } }
    private var totalCalories: Int { sessions.reduce(0) { $0 + ($1.caloriesBurned ?? 0) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All calculated workout burns")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))

            HStack(spacing: 0) {
                historyTotal(value: "\(sessions.count)", label: "records")
                Divider().frame(height: 32)
                historyTotal(value: totalCalories.formatted(), label: "kcal")
                Divider().frame(height: 32)
                historyTotal(value: "\(totalSets)", label: "sets")
                Divider().frame(height: 32)
                historyTotal(value: "\(totalReps)", label: "reps")
            }
        }
        .padding(.vertical, 4)
    }

    private func historyTotal(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WorkoutHistoryRow: View {
    let session: StrengthWorkoutSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 1) {
                Text(session.calendarDiaryDate.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppColors.calorie)
                Text(session.calendarDiaryDate.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(width: 42, height: 48)
            .background(AppColors.calorie.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("\(session.exerciseCount) exercises · \(session.performedSetCount) sets · \(session.repCount) reps")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Label("\((session.caloriesBurned ?? 0).formatted()) kcal", systemImage: "flame.fill")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct WorkoutSessionDetailView: View {
    let session: StrengthWorkoutSession

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("\((session.caloriesBurned ?? 0).formatted()) kcal", systemImage: "flame.fill")
                        Spacer()
                        Label("\(session.performedSetCount) sets", systemImage: "square.stack.3d.up.fill")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)

                    Text(session.completedAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year().hour().minute()))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(AppColors.appCard)

            ForEach(session.exercises) { exercise in
                Section {
                    if exercise.sets.isEmpty {
                        Text("No sets recorded")
                            .foregroundStyle(.secondary)
                    } else {
                        WorkoutSetColumnHeader()
                        ForEach(exercise.sets) { set in
                            WorkoutCompletedSetRow(set: set)
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(exerciseMetadata(exercise))
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                    .padding(.bottom, 3)
                }
                .listRowBackground(AppColors.appCard)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle(session.calendarDiaryDate.formatted(.dateTime.month(.abbreviated).day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func exerciseMetadata(_ exercise: StrengthCompletedExercise) -> String {
        let muscles = exercise.targetMuscles.joined(separator: ", ")
        return [muscles, exercise.equipment]
            .filter { !$0.isEmpty && $0 != "Unspecified" }
            .joined(separator: " · ")
    }
}

private struct WorkoutSetColumnHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("SET").frame(width: 34, alignment: .leading)
            Text("WEIGHT").frame(maxWidth: .infinity, alignment: .leading)
            Text("REPS").frame(width: 48, alignment: .trailing)
            Text("RPE").frame(width: 58, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

private struct WorkoutCompletedSetRow: View {
    let set: StrengthCompletedSet

    var body: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .frame(width: 34, alignment: .leading)
            Text(displayedWeight)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(set.reps.isEmpty ? "—" : set.reps)
                .frame(width: 48, alignment: .trailing)
            VStack(alignment: .trailing, spacing: 1) {
                Text(set.rpe.isEmpty ? "—" : set.rpe)
                if !set.rpe.isEmpty {
                    Text(set.rpeScale?.shortTitle ?? "Unknown")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 58, alignment: .trailing)
        }
        .font(.system(.subheadline, design: .rounded, weight: set.isPerformed ? .medium : .regular))
        .foregroundStyle(set.isPerformed ? Color.primary : Color.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Set \(set.setNumber), weight \(displayedWeight), reps \(set.reps.isEmpty ? "not recorded" : set.reps), RPE \(set.rpe.isEmpty ? "not recorded" : "\(set.rpe) on \(set.rpeScale?.title ?? "an unknown scale")")"
        )
    }

    private var displayedWeight: String {
        guard !set.weight.isEmpty else { return "—" }
        return "\(set.weight) \(set.weightUnit)"
    }
}
