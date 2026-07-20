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

/// Full workout-calorie history, intentionally mirroring Weight and Body Fat History.
struct WorkoutHistoryView: View {
    let sessions: [StrengthWorkoutSession]
    let onDelete: (StrengthWorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeletion: StrengthWorkoutSession?
    @State private var visibleSessions: [StrengthWorkoutSession] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleSessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\((session.caloriesBurned ?? 0).formatted()) kcal")
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Text(workoutHistoryFormatter.string(from: session.calendarDiaryDate))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            pendingDeletion = session
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            visibleSessions = sessions
                .filter { $0.caloriesBurned != nil }
                .sorted {
                    if $0.stableDiaryDateKey == $1.stableDiaryDateKey {
                        return $0.completedAt > $1.completedAt
                    }
                    return $0.stableDiaryDateKey > $1.stableDiaryDateKey
                }
        }
        .alert("Delete Workout Entry", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let session = pendingDeletion {
                    visibleSessions.removeAll { $0.id == session.id }
                    onDelete(session)
                }
                pendingDeletion = nil
            }
        } message: {
            if let session = pendingDeletion {
                Text("Remove \(workoutHistoryFormatter.string(from: session.calendarDiaryDate))'s entry of \((session.caloriesBurned ?? 0).formatted()) kcal? This also deletes the matching sample from Apple Health. The dated workout plan stays in your diary.")
            }
        }
    }
}

private let workoutHistoryFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()
