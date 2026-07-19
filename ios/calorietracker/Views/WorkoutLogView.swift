import AudioToolbox
import SwiftUI
import UIKit

/// The optional strength diary. Its information stays in `StrengthWorkoutStore`,
/// separate from the food diary, while the visual language is bridged through
/// Fud AI's existing workout theme tokens.
struct WorkoutLogView: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    @AppStorage(WeightUnit.storageKey) private var weightUnitRaw = WeightUnit.lbs.rawValue
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue

    @State private var selectedDate = Date.now
    @State private var pickerRequest: WorkoutLogPickerRequest?
    @State private var isCopySheetPresented = false
    @State private var selectedDetailItem: ExerciseLibraryItem?

    // Timer state intentionally lasts for the current app session, matching the
    // original Delts diary. Planned and completed workouts remain persisted.
    @State private var activeSessionDate: Date?
    @State private var activeSessionDateKey: String?
    @State private var workoutStartedAt: Date?
    @State private var runningSegmentStartedAt: Date?
    @State private var accumulatedElapsedSeconds = 0
    @State private var isOtherDateTimerDialogPresented = false
    @State private var isEmptyWorkoutAlertPresented = false
    @FocusState private var focusedSetField: WorkoutLogSetFocus?

    private let library = ExerciseLibraryService.shared

    private var selectedDateKey: String {
        StrengthWorkoutStore.dateKey(for: selectedDate)
    }

    private var selectedExercises: [StrengthPlannedExercise] {
        workoutStore.exercises(for: selectedDate)
    }

    private var isSelectedSessionDate: Bool {
        activeSessionDateKey == selectedDateKey
    }

    private var isTimerRunning: Bool {
        isSelectedSessionDate && runningSegmentStartedAt != nil
    }

    private var isTimerPaused: Bool {
        isSelectedSessionDate && runningSegmentStartedAt == nil && activeSessionDateKey != nil
    }

    private var selectedTimerStartedAt: Date? {
        isSelectedSessionDate ? runningSegmentStartedAt : nil
    }

    private var selectedTimerElapsedSeconds: Int {
        isSelectedSessionDate ? accumulatedElapsedSeconds : 0
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lbs
    }

    private var completedSetCount: Int {
        // Match Delts: a set counts once reps are entered. Weight/RPE alone is
        // still a planned, incomplete set.
        selectedExercises.flatMap(\.sets).filter { !$0.reps.isEmpty }.count
    }

    private var completedRepCount: Int {
        selectedExercises.flatMap(\.sets).reduce(0) { $0 + (Int($1.reps) ?? 0) }
    }

    private var selectedCompletedSession: StrengthWorkoutSession? {
        workoutStore.latestSession(on: selectedDate)
    }

    private var splitGroups: [StrengthWorkoutSplitGroup] {
        let configured = StrengthWorkoutSplitGroup.groups(
            for: workoutStore.preferences.split,
            availableMuscles: library.availablePrimaryMuscles
        )
        .filter { !$0.muscles.isEmpty }
        if !configured.isEmpty { return configured }

        // Final Delts falls back to one picker entry per catalog muscle for
        // Full Body and Custom splits rather than hiding the add choices.
        return Set(library.availablePrimaryMuscles + library.availableSecondaryMuscles)
            .sorted()
            .map { StrengthWorkoutSplitGroup(title: $0, muscles: [$0]) }
    }

    private var copyableDays: [WorkoutLogCopyDay] {
        workoutStore.previousPlanDates(before: selectedDate).map { date in
            WorkoutLogCopyDay(date: date, exercises: workoutStore.exercises(for: date))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        WorkoutLogWeekStrip(
                            selectedDate: $selectedDate,
                            workoutCountForDate: workoutStore.workoutCount
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    Section {
                        WorkoutLogTimerHero(
                            workoutCount: selectedExercises.count,
                            setCount: completedSetCount,
                            repCount: completedRepCount,
                            timerStartedAt: selectedTimerStartedAt,
                            timerElapsedSeconds: selectedTimerElapsedSeconds,
                            isTimerRunning: isTimerRunning,
                            isTimerPaused: isTimerPaused,
                            hasTimerSession: isTimerRunning || isTimerPaused,
                            completedDurationMinutes: selectedCompletedSession?.durationMinutes,
                            toggleTimer: handleTimerTap,
                            stopTimer: stopTimer,
                            discardTimer: discardTimer
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    Section {
                        if selectedExercises.isEmpty {
                            WorkoutLogEmptyRoutineRow(splitTitle: workoutStore.preferences.split.title)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        } else {
                            ForEach(selectedExercises) { exercise in
                                WorkoutLogExerciseCard(
                                    exercise: exercise,
                                    weightUnit: weightUnit.rawValue,
                                    rpeScale: workoutStore.preferences.rpeScale,
                                    isLoggingEnabled: isTimerRunning,
                                    focusedField: $focusedSetField,
                                    openDetail: {
                                        guard focusedSetField == nil else { return }
                                        selectedDetailItem = exercise.libraryItem
                                    },
                                    updateSetCount: { count in
                                        guard isTimerRunning else { return }
                                        workoutStore.setSetCount(count, exerciseID: exercise.id, on: selectedDate)
                                    },
                                    updateWeight: { setID, value in
                                        guard isTimerRunning else { return }
                                        workoutStore.updateSet(
                                            exerciseID: exercise.id,
                                            setID: setID,
                                            on: selectedDate,
                                            weight: value,
                                            weightUnit: weightUnit
                                        )
                                    },
                                    updateReps: { setID, value in
                                        guard isTimerRunning else { return }
                                        workoutStore.updateSet(
                                            exerciseID: exercise.id,
                                            setID: setID,
                                            on: selectedDate,
                                            reps: value
                                        )
                                    },
                                    updateRPE: { setID, value in
                                        guard isTimerRunning else { return }
                                        workoutStore.updateSet(
                                            exerciseID: exercise.id,
                                            setID: setID,
                                            on: selectedDate,
                                            rpe: value
                                        )
                                    }
                                )
                                .id(exercise.id)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        workoutStore.removeExercise(exercise.id, on: selectedDate)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .tint(Color(red: 0.58, green: 0.10, blue: 0.08))

                                    Button {
                                        workoutStore.toggleSaved(exercise.itemID)
                                    } label: {
                                        let isSaved = workoutStore.savedExerciseIDs.contains(exercise.itemID)
                                        Label(
                                            isSaved ? "Unsave" : "Save",
                                            systemImage: isSaved ? "bookmark.slash.fill" : "bookmark.fill"
                                        )
                                    }
                                    .tint(Color(red: 0.18, green: 0.42, blue: 0.16))
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center) {
                            Label(selectedDateTitle, systemImage: "dumbbell.fill")
                            Spacer()
                            Text("\(selectedExercises.count) workout\(selectedExercises.count == 1 ? "" : "s")")
                                .font(.caption.weight(.bold))
                        }
                        .textCase(nil)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.workoutBackground.ignoresSafeArea())
                .listSectionSpacing(8)
                .scrollDismissesKeyboard(.interactively)
                .animation(.snappy, value: selectedDate)
                .onChange(of: focusedSetField) { oldValue, newValue in
                    guard let exerciseID = newValue?.exerciseID,
                          exerciseID != oldValue?.exerciseID
                    else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.snappy(duration: 0.25)) {
                            proxy.scrollTo(exerciseID, anchor: UnitPoint(x: 0.5, y: 0.8))
                        }
                    }
                }
            }
            // Delts' diary deliberately kept the chrome quiet: the tab label
            // names the feature while the date strip and timer lead the page.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    addExerciseMenu
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedSetField = nil
                        dismissKeyboard()
                    }
                }
            }
            .navigationDestination(item: $selectedDetailItem) { item in
                ExerciseLibraryDetailView(item: item)
            }
            .confirmationDialog(
                "Timer already running",
                isPresented: $isOtherDateTimerDialogPresented,
                titleVisibility: .visible
            ) {
                Button("Go to \(activeSessionDateTitle)") {
                    if let activeSessionDate {
                        selectedDate = activeSessionDate
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Stop or discard the \(activeSessionDateTitle) timer before starting another.")
            }
            .alert("Add workouts first", isPresented: $isEmptyWorkoutAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add at least one workout to \(selectedDateTitle) before starting the timer.")
            }
            .sheet(item: $pickerRequest) { request in
                WorkoutLogExercisePickerSheet(
                    request: request,
                    selectedDate: selectedDate,
                    onDone: { pickerRequest = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isCopySheetPresented) {
                WorkoutLogCopySheet(
                    days: copyableDays,
                    targetTitle: selectedDateTitle,
                    onCopy: { sourceDate in
                        workoutStore.copyPlan(from: sourceDate, to: selectedDate)
                        isCopySheetPresented = false
                    },
                    onClose: { isCopySheetPresented = false }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: isTimerRunning) { _, isRunning in
                guard !isRunning else { return }
                focusedSetField = nil
                dismissKeyboard()
            }
        }
        .workoutScreen()
        // Observe theme changes without re-keying this view; re-keying would
        // destroy an in-progress session-only timer.
        .animation(.easeInOut(duration: 0.2), value: appThemeColorRaw)
    }

    private var addExerciseMenu: some View {
        Menu {
            Section {
                Button {
                    pickerRequest = WorkoutLogPickerRequest(context: .saved, initialSource: .saved)
                } label: {
                    WorkoutLogPickerContextMenuLabel(context: .saved)
                }

                Button {
                    isCopySheetPresented = true
                } label: {
                    Label("Copy from day", systemImage: "calendar.badge.plus")
                }

                if splitGroups.isEmpty {
                    Button {
                        pickerRequest = WorkoutLogPickerRequest(context: .all, initialSource: .dataset)
                    } label: {
                        WorkoutLogPickerContextMenuLabel(context: .all)
                    }
                } else {
                    ForEach(splitGroups) { group in
                        Button {
                            pickerRequest = WorkoutLogPickerRequest(
                                context: WorkoutLogPickerContext(title: group.title, muscles: group.muscles),
                                initialSource: .dataset
                            )
                        } label: {
                            WorkoutLogPickerContextMenuLabel(
                                context: WorkoutLogPickerContext(title: group.title, muscles: group.muscles)
                            )
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        }
        .tint(Color.workoutAccent)
        .accessibilityLabel("Add workout")
    }

    private var selectedDateTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var activeSessionDateTitle: String {
        guard let activeSessionDate else { return "active day" }
        if Calendar.current.isDateInToday(activeSessionDate) { return "Today" }
        if Calendar.current.isDateInTomorrow(activeSessionDate) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(activeSessionDate) { return "Yesterday" }
        return activeSessionDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func handleTimerTap() {
        if isTimerRunning {
            playTimerClick()
            pauseTimer()
        } else if isTimerPaused {
            playTimerClick()
            runningSegmentStartedAt = .now
        } else if activeSessionDateKey != nil {
            playTimerClick()
            isOtherDateTimerDialogPresented = true
        } else if selectedExercises.isEmpty {
            isEmptyWorkoutAlertPresented = true
        } else {
            playTimerClick()
            startTimer()
        }
    }

    private func startTimer() {
        let now = Date.now
        activeSessionDate = Calendar.current.startOfDay(for: selectedDate)
        activeSessionDateKey = selectedDateKey
        workoutStartedAt = now
        runningSegmentStartedAt = now
        accumulatedElapsedSeconds = 0
    }

    private func pauseTimer() {
        guard let runningSegmentStartedAt else { return }
        accumulatedElapsedSeconds += max(0, Int(Date.now.timeIntervalSince(runningSegmentStartedAt)))
        self.runningSegmentStartedAt = nil
    }

    private func stopTimer() {
        playTimerClick()
        let elapsed = currentElapsedSeconds(at: .now)
        let startedAt = workoutStartedAt ?? Date.now.addingTimeInterval(TimeInterval(-elapsed))

        _ = workoutStore.completeWorkout(
            on: selectedDate,
            startedAt: startedAt,
            completedAt: .now,
            elapsedSeconds: elapsed,
            weightUnit: weightUnit
        )
        resetTimerState()
    }

    private func discardTimer() {
        playTimerClick()
        resetTimerState()
    }

    private func playTimerClick() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1104)
    }

    private func resetTimerState() {
        activeSessionDate = nil
        activeSessionDateKey = nil
        workoutStartedAt = nil
        runningSegmentStartedAt = nil
        accumulatedElapsedSeconds = 0
    }

    private func currentElapsedSeconds(at date: Date) -> Int {
        guard let runningSegmentStartedAt else { return accumulatedElapsedSeconds }
        return accumulatedElapsedSeconds + max(0, Int(date.timeIntervalSince(runningSegmentStartedAt)))
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - 53-week diary strip

private struct WorkoutLogWeekStrip: View {
    @Binding var selectedDate: Date
    let workoutCountForDate: (Date) -> Int
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = true
    @State private var hasScrolledToInitialWeek = false

    private static let totalWeeks = 53
    private static let currentWeekIndex = totalWeeks - 1

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = weekStartsOnMonday ? 2 : 1
        return value
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<Self.totalWeeks, id: \.self) { weekIndex in
                        weekRow(for: weekIndex)
                            .containerRelativeFrame(.horizontal)
                            .id(weekIndex)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .onAppear {
                guard !hasScrolledToInitialWeek else { return }
                hasScrolledToInitialWeek = true
                proxy.scrollTo(boundedWeekIndex(for: selectedDate), anchor: .trailing)
            }
            .onChange(of: weekStartsOnMonday) { _, _ in
                proxy.scrollTo(Self.currentWeekIndex, anchor: .trailing)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout diary dates")
    }

    private func weekRow(for weekIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(weekDates(for: weekIndex), id: \.self) { date in
                dayTile(for: date)
            }
        }
    }

    private func dayTile(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let workoutCount = workoutCountForDate(date)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.snappy(duration: 0.3)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 6) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(isSelected ? Color.workoutAccent : Color.workoutMutedText.opacity(0.62))

                Text(date.formatted(.dateTime.day()))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.workoutOnAccent : (isToday ? Color.workoutAccent : Color.workoutCharcoal))
                    .frame(width: 36, height: 36)
                    .background {
                        if isSelected {
                            Circle()
                                .fill(Color.workoutAccent)
                                .shadow(color: Color.workoutAccent.opacity(0.28), radius: 6, y: 3)
                        } else if isToday {
                            Circle()
                                .strokeBorder(Color.workoutAccent.opacity(0.35), lineWidth: 1.5)
                        }
                    }

                Circle()
                    .fill(workoutCount > 0 ? Color.workoutAccent : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(workoutCount) workout\(workoutCount == 1 ? "" : "s")\(isSelected ? ", selected" : "")")
    }

    private func weekDates(for weekIndex: Int) -> [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysBack = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
        let weekOffset = weekIndex - Self.currentWeekIndex
        let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) ?? currentWeekStart
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func boundedWeekIndex(for date: Date) -> Int {
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today)
        let daysBack = (weekday - calendar.firstWeekday + 7) % 7
        let currentWeekStart = calendar.date(byAdding: .day, value: -daysBack, to: today) ?? today
        let components = calendar.dateComponents([.weekOfYear], from: currentWeekStart, to: calendar.startOfDay(for: date))
        return min(max(Self.currentWeekIndex + (components.weekOfYear ?? 0), 0), Self.currentWeekIndex)
    }
}

// MARK: - Signature timer and stats

private struct WorkoutLogTimerHero: View {
    let workoutCount: Int
    let setCount: Int
    let repCount: Int
    let timerStartedAt: Date?
    let timerElapsedSeconds: Int
    let isTimerRunning: Bool
    let isTimerPaused: Bool
    let hasTimerSession: Bool
    let completedDurationMinutes: Int?
    let toggleTimer: () -> Void
    let stopTimer: () -> Void
    let discardTimer: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 12) {
                Spacer(minLength: 0)

                WorkoutLogTimerButton(
                    startedAt: timerStartedAt,
                    elapsedSeconds: timerElapsedSeconds,
                    isRunning: isTimerRunning,
                    isPaused: isTimerPaused,
                    hasSession: hasTimerSession,
                    action: toggleTimer
                )

                if isTimerPaused {
                    WorkoutLogTimerSideControls(stopTimer: stopTimer, discardTimer: discardTimer)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }

                Spacer(minLength: 0)
            }
            .animation(.snappy(duration: 0.28), value: isTimerPaused)

            WorkoutLogStatsStrip(
                setCount: setCount,
                workoutCount: workoutCount,
                repCount: repCount,
                durationText: completedDurationMinutes.map { "\($0) min" } ?? "-- min"
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

private struct WorkoutLogTimerButton: View {
    let startedAt: Date?
    let elapsedSeconds: Int
    let isRunning: Bool
    let isPaused: Bool
    let hasSession: Bool
    let action: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Button(action: action) {
                VStack(spacing: 10) {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Color.white)
                        .shadow(color: Color.black.opacity(0.52), radius: 2, y: 1)
                        .frame(height: 34)

                    Text(elapsedDisplay(at: context.date))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                        .lineLimit(1)
                        .shadow(color: Color.black.opacity(0.62), radius: 2, y: 1)
                }
                .frame(width: 156, height: 156)
                .background {
                    Image("timer_button_red")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 176, height: 176)
                        .shadow(color: Color.black.opacity(0.34), radius: 16, y: 8)
                }
            }
            .buttonStyle(WorkoutLogTimerButtonStyle(isRunning: isRunning))
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var accessibilityLabel: String {
        if isRunning { return "Pause workout timer" }
        if isPaused || hasSession { return "Resume workout timer" }
        return "Start workout timer"
    }

    private func elapsedDisplay(at date: Date) -> String {
        let total = totalElapsedSeconds(at: date)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func totalElapsedSeconds(at date: Date) -> Int {
        guard let startedAt else { return elapsedSeconds }
        return elapsedSeconds + max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

private struct WorkoutLogTimerSideControls: View {
    let stopTimer: () -> Void
    let discardTimer: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            WorkoutLogTimerSideButton(
                title: "Stop",
                systemImage: "stop.fill",
                role: .stop,
                action: stopTimer
            )
            WorkoutLogTimerSideButton(
                title: "Discard",
                systemImage: "trash.fill",
                role: .discard,
                action: discardTimer
            )
        }
        .frame(width: 118)
    }
}

private struct WorkoutLogTimerSideButton: View {
    let title: String
    let systemImage: String
    let role: WorkoutLogTimerSideButtonStyle.Role
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(iconForeground)
                    .frame(width: 22, height: 22)
                    .background(iconBackground, in: Circle())

                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Spacer(minLength: 0)
            }
            .padding(.leading, 7)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(WorkoutLogTimerSideButtonStyle(role: role))
        .accessibilityLabel(title)
    }

    private var iconForeground: Color {
        switch role {
        case .stop: return Color.workoutAccent
        case .discard: return Color.white
        }
    }

    private var iconBackground: Color {
        switch role {
        case .stop: return Color.workoutOnAccent.opacity(0.96)
        case .discard: return Color.red.opacity(0.88)
        }
    }
}

private struct WorkoutLogTimerSideButtonStyle: ButtonStyle {
    enum Role { case stop, discard }

    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(height: 46)
            .background(
                configuration.isPressed ? pressedBackground : background,
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(border, lineWidth: role == .stop ? 0.8 : 1)
            }
            .shadow(color: shadowColor, radius: role == .stop ? 7 : 0, x: 0, y: role == .stop ? 4 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch role {
        case .stop: return Color.workoutOnAccent
        case .discard: return Color.red.opacity(0.92)
        }
    }

    private var background: Color {
        switch role {
        case .stop: return Color.workoutAccent
        case .discard: return Color.workoutCard.opacity(0.72)
        }
    }

    private var pressedBackground: Color {
        switch role {
        case .stop: return Color.workoutAccent.opacity(0.82)
        case .discard: return Color.red.opacity(0.10)
        }
    }

    private var border: Color {
        switch role {
        case .stop: return Color.workoutAccent.opacity(0.45)
        case .discard: return Color.red.opacity(0.42)
        }
    }

    private var shadowColor: Color {
        switch role {
        case .stop: return Color.workoutAccent.opacity(0.24)
        case .discard: return Color.clear
        }
    }
}

private struct WorkoutLogTimerButtonStyle: ButtonStyle {
    let isRunning: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : (isRunning ? 0.985 : 1))
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
            .animation(.snappy(duration: 0.18), value: isRunning)
    }
}

private struct WorkoutLogStatsStrip: View {
    let setCount: Int
    let workoutCount: Int
    let repCount: Int
    let durationText: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            metric(label: "Sets", value: "\(setCount)", systemImage: "checklist", active: setCount > 0)
            divider
            metric(label: "Workouts", value: "\(workoutCount)", systemImage: "dumbbell.fill", active: workoutCount > 0)
            divider
            metric(label: "Reps", value: "\(repCount)", systemImage: "repeat", active: repCount > 0)
            divider
            metric(label: "Time", value: durationText, systemImage: "clock.fill", active: durationText != "-- min")
            divider
            metric(label: "Burn", value: "-- kcal", systemImage: "flame.fill", active: false)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(Color.workoutPanel.opacity(0.84), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.72), lineWidth: 0.8)
        }
        .shadow(color: shadowColor, radius: colorScheme == .light ? 0 : 12, x: 0, y: colorScheme == .light ? 0 : 8)
        .accessibilityElement(children: .contain)
    }

    private var shadowColor: Color {
        colorScheme == .light ? .clear : Color.black.opacity(0.18)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.workoutHairline.opacity(0.52))
            .frame(width: 1, height: 44)
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }

    private func metric(label: String, value: String, systemImage: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(active ? Color.workoutAccent : Color.workoutMutedText.opacity(0.72))
                    .frame(width: 14, height: 14)
                Text(label)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(active ? Color.workoutAccent : Color.workoutCharcoal)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value.replacingOccurrences(of: "--", with: "not available"))
    }
}

// MARK: - Planned workout cards

private struct WorkoutLogSetFocus: Hashable {
    enum Field: Hashable { case weight, reps, rpe }

    let exerciseID: UUID
    let setID: UUID
    let field: Field
}

private struct WorkoutLogExerciseCard: View {
    let exercise: StrengthPlannedExercise
    let weightUnit: String
    let rpeScale: StrengthWorkoutRPEScale
    let isLoggingEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding
    let openDetail: () -> Void
    let updateSetCount: (Int) -> Void
    let updateWeight: (UUID, String) -> Void
    let updateReps: (UUID, String) -> Void
    let updateRPE: (UUID, String) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: openDetail) {
                HStack(alignment: .center, spacing: 12) {
                    AnimatedExerciseVisual(
                        exerciseName: exercise.name,
                        imagePaths: exercise.imagePaths,
                        height: 64,
                        fillsWidth: false,
                        allowsDerivedImageLookup: false
                    )
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.workoutHairline.opacity(0.48), lineWidth: 0.7)
                    }
                    .clipped()
                    .layoutPriority(0)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name)
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.workoutCharcoal)
                            .lineLimit(2)

                        Text("\(exercise.primaryMuscles.joined(separator: ", ")) - \(exercise.rawEquipment)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.workoutMutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.workoutMutedText.opacity(0.72))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscles.joined(separator: ", ")), \(exercise.rawEquipment)")
            .accessibilityHint("Opens exercise instructions")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Label("Sets", systemImage: "list.number")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Color.workoutMutedText)

                    Spacer(minLength: 8)

                    Stepper(
                        value: Binding(get: { exercise.sets.count }, set: updateSetCount),
                        in: 1...12
                    ) {
                        Text("\(exercise.sets.count) \(exercise.sets.count == 1 ? "set" : "sets")")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(isLoggingEnabled ? Color.workoutCharcoal : Color.workoutMutedText.opacity(0.70))
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .disabled(!isLoggingEnabled)
                    .opacity(isLoggingEnabled ? 1 : 0.54)
                    .accessibilityHint(isLoggingEnabled ? "Adjust from one to twelve sets" : "Start the timer to edit sets")
                }

                VStack(spacing: 0) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        WorkoutLogSetRow(
                            exerciseID: exercise.id,
                            setIndex: index,
                            set: set,
                            rpeScale: rpeScale,
                            weightUnit: weightUnit,
                            isEnabled: isLoggingEnabled,
                            focusedField: focusedField,
                            updateWeight: { updateWeight(set.id, $0) },
                            updateReps: { updateReps(set.id, $0) },
                            updateRPE: { updateRPE(set.id, $0) }
                        )

                        if index < exercise.sets.count - 1 {
                            Divider()
                                .overlay(Color.workoutHairline.opacity(0.5))
                                .padding(.leading, 64)
                        }
                    }
                }
            }
            .opacity(isLoggingEnabled ? 1 : 0.62)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.workoutPanel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.82), lineWidth: 0.8)
        }
        .shadow(color: shadowColor, radius: colorScheme == .light ? 0 : 12, x: 0, y: colorScheme == .light ? 0 : 7)
    }

    private var shadowColor: Color {
        colorScheme == .light ? .clear : Color.black.opacity(0.22)
    }
}

private struct WorkoutLogSetRow: View {
    let exerciseID: UUID
    let setIndex: Int
    let set: StrengthPlannedSet
    let rpeScale: StrengthWorkoutRPEScale
    let weightUnit: String
    let isEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding
    let updateWeight: (String) -> Void
    let updateReps: (String) -> Void
    let updateRPE: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Set \(setIndex + 1)")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.workoutMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(width: 46, alignment: .leading)

            WorkoutLogSetValueField(
                placeholder: set.weightUnit ?? weightUnit,
                text: Binding(get: { set.weight }, set: updateWeight),
                keyboardType: .decimalPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .weight),
                isEnabled: isEnabled,
                focusedField: focusedField
            )
            .frame(maxWidth: .infinity)

            WorkoutLogSetValueField(
                placeholder: "Reps",
                text: Binding(get: { set.reps }, set: updateReps),
                keyboardType: .numberPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .reps),
                isEnabled: isEnabled,
                focusedField: focusedField
            )
            .frame(maxWidth: .infinity)

            WorkoutLogSetValueField(
                placeholder: set.rpeScale?.inputPlaceholder ?? rpeScale.inputPlaceholder,
                text: Binding(get: { set.rpe }, set: updateRPE),
                keyboardType: rpeScale.allowsDecimalInput ? .decimalPad : .numberPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .rpe),
                isEnabled: isEnabled,
                focusedField: focusedField
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .accessibilityHint("Opens set weight, reps and RPE input")
    }
}

private struct WorkoutLogSetValueField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let focus: WorkoutLogSetFocus
    let isEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                WorkoutLogSetSelectionTextField(
                    placeholder: placeholder,
                    text: $text,
                    keyboardType: keyboardType,
                    focus: focus,
                    isEnabled: isEnabled,
                    focusedField: focusedField
                )
            } else {
                baseTextField
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.workoutCard.opacity(isEnabled ? 0.74 : 0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.workoutHairline.opacity(isEnabled ? 0.4 : 0.24), lineWidth: 0.6)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
    }

    private var baseTextField: some View {
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .textFieldStyle(.plain)
            .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundStyle(isEnabled ? Color.workoutCharcoal : Color.workoutMutedText.opacity(0.72))
            .multilineTextAlignment(.center)
            .focused(focusedField, equals: focus)
    }
}

@available(iOS 18.0, *)
private struct WorkoutLogSetSelectionTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let focus: WorkoutLogSetFocus
    let isEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding
    @State private var selection: TextSelection?

    var body: some View {
        TextField(placeholder, text: $text, selection: $selection)
            .keyboardType(keyboardType)
            .textFieldStyle(.plain)
            .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundStyle(isEnabled ? Color.workoutCharcoal : Color.workoutMutedText.opacity(0.72))
            .multilineTextAlignment(.center)
            .focused(focusedField, equals: focus)
            .onTapGesture {
                if focusedField.wrappedValue == focus {
                    moveCursorToEnd()
                } else {
                    focusedField.wrappedValue = focus
                }
            }
            .onChange(of: focusedField.wrappedValue) { _, value in
                guard value == focus else { return }
                moveCursorToEnd()
            }
    }

    private func moveCursorToEnd() {
        DispatchQueue.main.async {
            selection = TextSelection(insertionPoint: text.endIndex)
        }
    }
}

private struct WorkoutLogEmptyRoutineRow: View {
    let splitTitle: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.workoutAccent)

            VStack(alignment: .leading, spacing: 3) {
                Text("No workouts logged")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)
                Text("Use + to pick \(splitTitle) workouts for this day")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.workoutMutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.workoutPanel.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.workoutHairline.opacity(0.95), lineWidth: 1)
        }
        .shadow(color: shadowColor, radius: colorScheme == .light ? 0 : 10, x: 0, y: colorScheme == .light ? 0 : 5)
        .accessibilityElement(children: .combine)
    }

    private var shadowColor: Color {
        colorScheme == .light ? .clear : Color.black.opacity(0.16)
    }
}

// MARK: - Exercise picker

private enum WorkoutLogPickerSource: String, CaseIterable, Identifiable {
    case dataset = "Dataset"
    case saved = "Saved"

    var id: String { rawValue }
}

private struct WorkoutLogPickerContext: Hashable {
    static let all = WorkoutLogPickerContext(title: "All Workouts", muscles: [])
    static let saved = WorkoutLogPickerContext(title: "Saved", muscles: [])

    let title: String
    let muscles: Set<String>

    var id: String { title }
}

private struct WorkoutLogPickerRequest: Identifiable {
    let id = UUID()
    let context: WorkoutLogPickerContext
    let initialSource: WorkoutLogPickerSource
}

private struct WorkoutLogPickerContextMenuLabel: View {
    let context: WorkoutLogPickerContext

    var body: some View {
        if context.id == WorkoutLogPickerContext.saved.id {
            Label(context.title, systemImage: "bookmark.fill")
        } else {
            Label(
                context.title,
                image: MuscleGlyphAsset.name(title: context.title, muscles: context.muscles)
            )
        }
    }
}

private struct WorkoutLogPickerFilterState: Codable, Equatable {
    var searchText = ""
    var levels: Set<String> = []
    var equipment: Set<String> = []
    var primaryMuscles: Set<String> = []
    var secondaryMuscles: Set<String> = []
    var forces: Set<String> = []
    var mechanics: Set<String> = []
    var categories: Set<String> = []
    var sort: ExerciseLibrarySort = .name
}

private enum WorkoutLogPickerFilterStateStore {
    static func load(contextID: String) -> WorkoutLogPickerFilterState {
        guard let data = UserDefaults.standard.data(forKey: key(contextID)),
              let state = try? JSONDecoder().decode(WorkoutLogPickerFilterState.self, from: data)
        else { return WorkoutLogPickerFilterState() }
        return state
    }

    static func save(_ state: WorkoutLogPickerFilterState, contextID: String) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: key(contextID))
    }

    private static func key(_ contextID: String) -> String {
        "fudai.workouts.picker.filter.v1.\(contextID)"
    }
}

private struct WorkoutLogExercisePickerSheet: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    let request: WorkoutLogPickerRequest
    let selectedDate: Date
    let onDone: () -> Void

    @AppStorage("fudai.workouts.picker.source.v1") private var sourceRaw = WorkoutLogPickerSource.dataset.rawValue
    @State private var searchText = ""
    @State private var selectedLevels: Set<String> = []
    @State private var selectedEquipment: Set<String> = []
    @State private var selectedPrimaryMuscles: Set<String> = []
    @State private var selectedSecondaryMuscles: Set<String> = []
    @State private var selectedForces: Set<String> = []
    @State private var selectedMechanics: Set<String> = []
    @State private var selectedCategories: Set<String> = []
    @State private var selectedSort: ExerciseLibrarySort = .name

    private let library = ExerciseLibraryService.shared

    init(request: WorkoutLogPickerRequest, selectedDate: Date, onDone: @escaping () -> Void) {
        self.request = request
        self.selectedDate = selectedDate
        self.onDone = onDone
        let state = WorkoutLogPickerFilterStateStore.load(contextID: request.context.id)
        _searchText = State(initialValue: state.searchText)
        _selectedLevels = State(initialValue: state.levels)
        _selectedEquipment = State(initialValue: state.equipment)
        _selectedPrimaryMuscles = State(initialValue: state.primaryMuscles)
        _selectedSecondaryMuscles = State(initialValue: state.secondaryMuscles)
        _selectedForces = State(initialValue: state.forces)
        _selectedMechanics = State(initialValue: state.mechanics)
        _selectedCategories = State(initialValue: state.categories)
        _selectedSort = State(initialValue: state.sort)
    }

    private var isSavedContext: Bool {
        request.context.id == WorkoutLogPickerContext.saved.id
    }

    private var showsSourcePicker: Bool { !isSavedContext }

    private var source: WorkoutLogPickerSource {
        isSavedContext ? .saved : (WorkoutLogPickerSource(rawValue: sourceRaw) ?? .dataset)
    }

    private var sourceBinding: Binding<WorkoutLogPickerSource> {
        Binding(
            get: { source },
            set: { sourceRaw = $0.rawValue }
        )
    }

    private var hidesPrimaryFilter: Bool {
        (workoutStore.preferences.split == .fullBody || workoutStore.preferences.split == .custom)
            && !request.context.muscles.isEmpty
    }

    private var filterState: WorkoutLogPickerFilterState {
        WorkoutLogPickerFilterState(
            searchText: searchText,
            levels: selectedLevels,
            equipment: selectedEquipment,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            forces: selectedForces,
            mechanics: selectedMechanics,
            categories: selectedCategories,
            sort: selectedSort
        )
    }

    private var filteredExercises: [ExerciseLibraryItem] {
        let effectiveEquipment = selectedEquipment.isEmpty
            ? Set(availableEquipment)
            : selectedEquipment
        let filtered = library.filtered(
            levels: selectedLevels,
            rawEquipment: effectiveEquipment,
            primaryMuscles: selectedPrimaryMuscles,
            secondaryMuscles: selectedSecondaryMuscles,
            forces: selectedForces,
            mechanics: selectedMechanics,
            categories: selectedCategories,
            sort: selectedSort,
            searchText: searchText
        )

        return filtered.filter { item in
            let matchesContext = request.context.muscles.isEmpty
                || item.primaryMuscles.contains(where: request.context.muscles.contains)
                || item.secondaryMuscles.contains(where: request.context.muscles.contains)
            let matchesSource = source == .dataset || workoutStore.savedExerciseIDs.contains(item.id)
            return matchesContext && matchesSource
        }
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty
            || !selectedLevels.isEmpty
            || !selectedEquipment.isEmpty
            || !selectedPrimaryMuscles.isEmpty
            || !selectedSecondaryMuscles.isEmpty
            || !selectedForces.isEmpty
            || !selectedMechanics.isEmpty
            || !selectedCategories.isEmpty
            || selectedSort != .name
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if showsSourcePicker {
                        Picker("Source", selection: sourceBinding) {
                            ForEach(WorkoutLogPickerSource.allCases) { source in
                                Text(source.rawValue).tag(source)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    filterStrip
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    resultsHeader
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    if filteredExercises.isEmpty {
                        Text(!showsSourcePicker || source == .saved ? "No saved workouts yet." : "No dataset workouts found.")
                            .foregroundStyle(Color.workoutMutedText)
                            .listRowBackground(Color.workoutPanel.opacity(0.22))
                    } else {
                        ForEach(filteredExercises.prefix(120)) { item in
                            WorkoutLogPickerRow(
                                item: item,
                                isSelected: workoutStore.containsExercise(item.id, on: selectedDate)
                            ) {
                                workoutStore.toggleExercise(item, on: selectedDate)
                            }
                            .listRowBackground(
                                Color.workoutPanel.opacity(workoutStore.containsExercise(item.id, on: selectedDate) ? 0.28 : 0.18)
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    workoutStore.toggleSaved(item.id)
                                } label: {
                                    let isSaved = workoutStore.savedExerciseIDs.contains(item.id)
                                    Label(
                                        isSaved ? "Unsave" : "Save",
                                        systemImage: isSaved ? "bookmark.slash.fill" : "bookmark.fill"
                                    )
                                }
                                .tint(Color.workoutAccent)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .contentMargins(.top, 0, for: .scrollContent)
            .background(Color.workoutBackground)
            .scrollDismissesKeyboard(.immediately)
            .contentShape(Rectangle())
            .onTapGesture {
                dismissKeyboard()
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search workouts")
            .listSectionSpacing(0)
            .navigationTitle("Add \(request.context.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.workoutAccent)
                }
            }
            .keepsWorkoutLogToolbarDuringSearch()
        }
        .onAppear {
            normalizePrimaryFilterSelection()
            normalizeEquipmentFilterSelection()
        }
        .onChange(of: request.context.muscles) {
            normalizePrimaryFilterSelection()
        }
        .onChange(of: hidesPrimaryFilter) {
            normalizePrimaryFilterSelection()
        }
        .onChange(of: availableEquipment) {
            normalizeEquipmentFilterSelection()
        }
        .onChange(of: filterState) { _, state in
            WorkoutLogPickerFilterStateStore.save(state, contextID: request.context.id)
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredExercises.count) \(filteredExercises.count == 1 ? "exercise" : "exercises")")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)
                    .textCase(nil)

                Text(selectedSort.title)
                    .font(.caption)
                    .foregroundStyle(Color.workoutMutedText)
                    .textCase(nil)
            }

            Spacer()

            Button(action: resetFilters) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hasActiveFilters ? Color.workoutInferno : Color.workoutMutedText)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(
                        (hasActiveFilters ? Color.workoutInferno : Color.workoutPanel).opacity(hasActiveFilters ? 0.10 : 0.22),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                (hasActiveFilters ? Color.workoutInferno : Color.workoutHairline).opacity(hasActiveFilters ? 0.28 : 0.24),
                                lineWidth: 0.5
                            )
                    }
            }
            .disabled(!hasActiveFilters)
            .buttonStyle(.plain)
            .workoutPressable()

            Menu {
                ForEach(ExerciseLibrarySort.allCases) { sort in
                    menuChoice(sort.title, isSelected: selectedSort == sort) {
                        selectedSort = sort
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selectedSort == .name ? Color.workoutMutedText : Color.workoutAccent)
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Color.workoutPanel.opacity(selectedSort == .name ? 0.30 : 0.46), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(
                                (selectedSort == .name ? Color.workoutHairline : Color.workoutAccent).opacity(0.32),
                                lineWidth: 0.5
                            )
                    }
            }
            .buttonStyle(.plain)
            .workoutPressable()
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                if !hidesPrimaryFilter {
                    filterMenu(
                        title: "Primary",
                        value: primaryFilterTitle,
                        systemImage: "scope"
                    ) {
                        menuChoice("All Primary (\(contextPrimaryMuscles.count))", isSelected: selectedPrimaryMuscles.isEmpty) {
                            selectedPrimaryMuscles.removeAll()
                        }
                        ForEach(contextPrimaryMuscles, id: \.self) { value in
                            muscleMenuChoice(value, muscles: [value], isSelected: selectedPrimaryMuscles.contains(value)) {
                                selectedPrimaryMuscles = [value]
                            }
                        }
                    }
                }

                filterMenu(
                    title: "Secondary",
                    value: selectionTitle(selectedSecondaryMuscles),
                    systemImage: "scope"
                ) {
                    menuChoice("All Secondary", isSelected: selectedSecondaryMuscles.isEmpty) { selectedSecondaryMuscles.removeAll() }
                    ForEach(library.availableSecondaryMuscles, id: \.self) { value in
                        muscleMenuChoice(value, muscles: [value], isSelected: selectedSecondaryMuscles.contains(value)) {
                            selectedSecondaryMuscles = [value]
                        }
                    }
                }

                filterMenu(
                    title: "Equipment",
                    value: equipmentFilterTitle,
                    systemImage: "dumbbell.fill"
                ) {
                    menuChoice("All Equipment (\(availableEquipment.count))", isSelected: selectedEquipment.isEmpty) {
                        selectedEquipment.removeAll()
                    }
                    ForEach(availableEquipment, id: \.self) { value in
                        menuChoice(value, isSelected: selectedEquipment.contains(value)) { selectedEquipment = [value] }
                    }
                }

                filterMenu(title: "Level", value: selectionTitle(selectedLevels), systemImage: "chart.bar.fill") {
                    menuChoice("All Levels", isSelected: selectedLevels.isEmpty) { selectedLevels.removeAll() }
                    ForEach(library.availableLevels, id: \.self) { value in
                        menuChoice(value, isSelected: selectedLevels.contains(value)) { selectedLevels = [value] }
                    }
                }

                filterMenu(title: "Force", value: selectionTitle(selectedForces), systemImage: "arrow.left.arrow.right") {
                    menuChoice("All Forces", isSelected: selectedForces.isEmpty) { selectedForces.removeAll() }
                    ForEach(library.availableForces, id: \.self) { value in
                        menuChoice(value, isSelected: selectedForces.contains(value)) { selectedForces = [value] }
                    }
                }

                filterMenu(title: "Mechanic", value: selectionTitle(selectedMechanics), systemImage: "gearshape") {
                    menuChoice("All Mechanics", isSelected: selectedMechanics.isEmpty) { selectedMechanics.removeAll() }
                    ForEach(library.availableMechanics, id: \.self) { value in
                        menuChoice(value, isSelected: selectedMechanics.contains(value)) { selectedMechanics = [value] }
                    }
                }

                filterMenu(title: "Category", value: selectionTitle(selectedCategories), systemImage: "tag") {
                    menuChoice("All Categories", isSelected: selectedCategories.isEmpty) { selectedCategories.removeAll() }
                    ForEach(library.availableCategoryCounts) { value in
                        menuChoice(value.category, isSelected: selectedCategories.contains(value.category)) {
                            selectedCategories = [value.category]
                        }
                    }
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var contextPrimaryMuscles: [String] {
        guard !request.context.muscles.isEmpty else { return library.availablePrimaryMuscles }
        return library.availablePrimaryMuscles.filter(request.context.muscles.contains)
    }

    private var availableEquipment: [String] {
        let preferred = workoutStore.preferences.equipment
        guard !preferred.isEmpty else { return library.availableRawEquipment }
        return library.availableRawEquipment.filter(preferred.contains)
    }

    private var equipmentFilterTitle: String {
        selectedEquipment.isEmpty ? "All \(availableEquipment.count)" : selectionTitle(selectedEquipment)
    }

    private var primaryFilterTitle: String {
        selectedPrimaryMuscles.isEmpty ? "All \(contextPrimaryMuscles.count)" : selectionTitle(selectedPrimaryMuscles)
    }

    private func selectionTitle(_ selection: Set<String>) -> String {
        if selection.isEmpty { return "All" }
        if selection.count == 1 { return selection.first ?? "All" }
        return "\(selection.count) selected"
    }

    private func filterMenu<Content: View>(
        title: String,
        value: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu(content: content) {
            WorkoutLogFilterPill(title: title, value: value, systemImage: systemImage)
        }
        .workoutPressable()
    }

    private func menuChoice(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func muscleMenuChoice(
        _ title: String,
        muscles: Set<String>,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Label(title, image: MuscleGlyphAsset.name(title: title, muscles: muscles))
            }
        }
    }

    private func normalizePrimaryFilterSelection() {
        if hidesPrimaryFilter {
            selectedPrimaryMuscles.removeAll()
            return
        }
        let valid = Set(contextPrimaryMuscles)
        selectedPrimaryMuscles = singleStoredSelection(selectedPrimaryMuscles.intersection(valid))
    }

    private func normalizeEquipmentFilterSelection() {
        let valid = Set(availableEquipment)
        selectedEquipment = singleStoredSelection(selectedEquipment.intersection(valid))
    }

    private func singleStoredSelection(_ selection: Set<String>) -> Set<String> {
        guard let value = selection.sorted().first else { return [] }
        return [value]
    }

    private func resetFilters() {
        searchText = ""
        selectedLevels.removeAll()
        selectedEquipment.removeAll()
        selectedPrimaryMuscles.removeAll()
        selectedSecondaryMuscles.removeAll()
        selectedForces.removeAll()
        selectedMechanics.removeAll()
        selectedCategories.removeAll()
        selectedSort = .name
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private extension View {
    @ViewBuilder
    func keepsWorkoutLogToolbarDuringSearch() -> some View {
        if #available(iOS 17.1, *) {
            searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            self
        }
    }
}

private struct WorkoutLogFilterPill: View {
    let title: String
    let value: String
    let systemImage: String

    private var isDefault: Bool { value == "All" || value == "Name" }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isDefault ? Color.workoutSecondaryAccent : Color.workoutAccent)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.workoutMutedText)
                    .textCase(.uppercase)
                    .lineLimit(1)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.workoutCharcoal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.workoutMutedText)
                .padding(.leading, 1)
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 112, minHeight: 46, alignment: .leading)
        .background(
            Color.workoutPanel.opacity(isDefault ? 0.30 : 0.46),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    (isDefault ? Color.workoutHairline : Color.workoutAccent).opacity(isDefault ? 0.30 : 0.42),
                    lineWidth: 0.5
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

private struct WorkoutLogPickerRow: View {
    let item: ExerciseLibraryItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AnimatedExerciseVisual(
                    exerciseName: item.name,
                    imagePaths: item.imagePaths,
                    height: 58,
                    fillsWidth: false,
                    allowsDerivedImageLookup: false
                )
                .frame(width: 76, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipped()
                .layoutPriority(0)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(item.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.workoutCharcoal)
                        .lineLimit(2)

                    Text("\(item.primaryMusclesTitle) - \(item.rawEquipment)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.workoutMutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isSelected ? Color.workoutAccent : Color.workoutMutedText)
                    .frame(width: 34, height: 34)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.primaryMusclesTitle), \(item.rawEquipment)")
        .accessibilityValue(isSelected ? "Added" : "Not added")
        .accessibilityHint(isSelected ? "Double tap to remove from this day" : "Double tap to add to this day")
    }
}

// MARK: - Copy prior day

private struct WorkoutLogCopyDay: Identifiable {
    let date: Date
    let exercises: [StrengthPlannedExercise]

    var id: String { StrengthWorkoutStore.dateKey(for: date) }
}

private struct WorkoutLogCopySheet: View {
    let days: [WorkoutLogCopyDay]
    let targetTitle: String
    let onCopy: (Date) -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if days.isEmpty {
                    ContentUnavailableView("No previous workouts", systemImage: "calendar.badge.exclamationmark")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(days) { day in
                        Button {
                            onCopy(day.date)
                        } label: {
                            WorkoutLogCopyDayRow(day: day)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.workoutPanel.opacity(0.24))
                        .listRowSeparatorTint(Color.workoutHairline.opacity(0.28))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
            .background(Color.workoutBackground)
            .navigationTitle("Copy to \(targetTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onClose)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.workoutAccent)
                }
            }
        }
    }
}

private struct WorkoutLogCopyDayRow: View {
    let day: WorkoutLogCopyDay

    private var workoutNames: String {
        let names = day.exercises.prefix(3).map(\.name).joined(separator: ", ")
        let remaining = day.exercises.count - 3
        return remaining > 0 ? "\(names) + \(remaining)" : names
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.headline.weight(.black))
                .foregroundStyle(Color.workoutAccent)
                .frame(width: 38, height: 38)
                .background(Color.workoutCard.opacity(0.60), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.workoutHairline.opacity(0.34), lineWidth: 0.7)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)
                    .lineLimit(1)
                Text(workoutNames)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(day.exercises.count)")
                    .font(.system(.title3, design: .rounded, weight: .black).monospacedDigit())
                    .foregroundStyle(Color.workoutAccent)
                Text(day.exercises.count == 1 ? "workout" : "workouts")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Color.workoutMutedText)
            }

            Image(systemName: "plus")
                .font(.caption.weight(.black))
                .foregroundStyle(Color.workoutOnAccent)
                .frame(width: 28, height: 28)
                .background(Color.workoutAccent, in: Circle())
        }
        .padding(.vertical, 4)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        if Calendar.current.isDateInYesterday(day.date) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}
