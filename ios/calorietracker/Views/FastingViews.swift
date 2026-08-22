import SwiftUI

struct ActiveFastingRow: View {
    let session: FastingSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = session.duration(at: context.date)
            let progress = min(1, elapsed / TimeInterval(session.goalMinutes * 60))
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(NeoAppColors.cobalt)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fast in progress")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                        Text("Started \(session.startedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(FastingDurationFormatter.compact(seconds: elapsed))
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(NeoAppColors.cobalt)
                            .monospacedDigit()
                        Text("\(FastingDurationFormatter.goal(minutes: session.goalMinutes)) goal")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(NeoAppColors.ink.opacity(0.14))
                        Rectangle()
                            .fill(NeoAppColors.cobalt)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 8)
                .overlay {
                    Rectangle()
                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.compactRule)
                        .allowsHitTesting(false)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct CompletedFastingRow: View {
    let session: FastingSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer.circle.fill")
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(NeoAppColors.cobalt)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(FastingDurationFormatter.compact(seconds: session.duration())) fast")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                if let endedAt = session.endedAt {
                    Text("\(session.startedAt.formatted(date: .omitted, time: .shortened)) – \(endedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(FastingDurationFormatter.goal(minutes: session.goalMinutes)) goal")
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

struct FastingStartSheet: View {
    @Environment(\.dismiss) private var dismiss
    let defaultGoalMinutes: Int
    let onStart: (Int) -> Void
    @State private var selectedHours: Int

    init(defaultGoalMinutes: Int, onStart: @escaping (Int) -> Void) {
        self.defaultGoalMinutes = defaultGoalMinutes
        self.onStart = onStart
        _selectedHours = State(initialValue: min(168, max(1, defaultGoalMinutes / 60)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: "timer")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(NeoAppColors.cobalt)
                    .frame(width: 72, height: 72)
                    .neoPanel(fill: NeoAppColors.surface)

                Text("Choose a fasting goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))

                HStack(spacing: 4) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(1...168, id: \.self) { hours in
                            Text("\(hours)").tag(hours)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 150, height: 170)
                    .clipped()
                    Text("hours")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .neoPanel(fill: NeoAppColors.surface)

                Button {
                    onStart(selectedHours * 60)
                    dismiss()
                } label: {
                    Label("Start Fast", systemImage: "play.fill")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Color.black)
                        .background(NeoAppColors.acid)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 24)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .navigationTitle("Start Fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct FastingGoalPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (Int) -> Void
    @State private var selectedHours: Int

    init(currentGoalMinutes: Int, onSave: @escaping (Int) -> Void) {
        self.onSave = onSave
        _selectedHours = State(initialValue: min(168, max(1, currentGoalMinutes / 60)))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Default Fasting Goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                HStack(spacing: 4) {
                    Picker("Hours", selection: $selectedHours) {
                        ForEach(1...168, id: \.self) { hours in
                            Text("\(hours)").tag(hours)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 150, height: 190)
                    .clipped()
                    Text("hours")
                        .font(.system(.title3, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .neoPanel(fill: NeoAppColors.surface)
                Button {
                    onSave(selectedHours * 60)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NeoAppColors.acid)
                        .foregroundStyle(Color.black)
                        .overlay {
                            Rectangle()
                                .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                .allowsHitTesting(false)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                Spacer()
            }
            .padding(.top, 24)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct FastingSessionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let session: FastingSession
    let onSave: (FastingSession) -> Void
    let onEndNow: (FastingSession) -> Void
    let onDelete: (FastingSession) -> Void

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var goalHours: Int

    init(
        session: FastingSession,
        onSave: @escaping (FastingSession) -> Void,
        onEndNow: @escaping (FastingSession) -> Void,
        onDelete: @escaping (FastingSession) -> Void
    ) {
        self.session = session
        self.onSave = onSave
        self.onEndNow = onEndNow
        self.onDelete = onDelete
        _startedAt = State(initialValue: session.startedAt)
        _endedAt = State(initialValue: session.endedAt ?? .now)
        _goalHours = State(initialValue: min(168, max(1, session.goalMinutes / 60)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NeoScreenHeader(
                        eyebrow: "FASTING SESSION",
                        title: session.isActive ? "Active Fast" : "Edit Fast",
                        subtitle: session.isActive
                            ? "Adjust the start and target, or finish the fast now."
                            : "Correct the timing and target without changing its history."
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    DatePicker("Started", selection: $startedAt)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .neoPanel(fill: NeoAppColors.surface)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    if !session.isActive {
                        DatePicker("Ended", selection: $endedAt, in: startedAt...)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .neoPanel(fill: NeoAppColors.surface)
                            .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Stepper("Goal: \(goalHours) hours", value: $goalHours, in: 1...168)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .neoPanel(fill: NeoAppColors.surface)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    NeoSectionBanner(title: "Session", detail: "\(goalHours) H GOAL", style: .cobalt)
                }

                Section {
                    if session.isActive {
                        Button {
                            var updated = session
                            updated.startedAt = startedAt
                            updated.goalMinutes = goalHours * 60
                            onEndNow(updated)
                            dismiss()
                        } label: {
                            Label("End Fast Now", systemImage: "stop.fill")
                                .font(.system(.body, design: .rounded, weight: .black))
                                .textCase(.uppercase)
                                .foregroundStyle(Color.black)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 52)
                                .background(NeoAppColors.acid)
                                .overlay {
                                    Rectangle()
                                        .stroke(NeoAppColors.ink, lineWidth: NeoAppMetrics.rule)
                                        .allowsHitTesting(false)
                                }
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    Button(role: .destructive) {
                        onDelete(session)
                        dismiss()
                    } label: {
                        Label(session.isActive ? "Cancel Fast" : "Delete Fast", systemImage: "trash")
                            .font(.system(.body, design: .rounded, weight: .black))
                            .textCase(.uppercase)
                            .foregroundStyle(NeoAppColors.warning)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(NeoAppColors.surface)
                            .overlay {
                                Rectangle()
                                    .stroke(NeoAppColors.warning, lineWidth: NeoAppMetrics.rule)
                                    .allowsHitTesting(false)
                            }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 14, bottom: 4, trailing: 14))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    NeoSectionBanner(title: "Actions", detail: session.isActive ? "LIVE" : "HISTORY", style: .ink)
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .listSectionSpacing(NeoAppMetrics.sectionSpacing)
            .background(NeoAppColors.canvas)
            .tint(NeoAppColors.cobalt)
            .navigationTitle(session.isActive ? "Active Fast" : "Edit Fast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(NeoAppColors.cobalt)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = session
                        updated.startedAt = startedAt
                        updated.endedAt = session.isActive ? nil : max(endedAt, startedAt)
                        updated.goalMinutes = goalHours * 60
                        onSave(updated)
                        dismiss()
                    }
                    .tint(NeoAppColors.cobalt)
                }
            }
        }
    }
}
