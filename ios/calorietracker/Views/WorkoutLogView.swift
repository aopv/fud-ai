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
                                    date: selectedDate,
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

                                    Button {
                                        workoutStore.toggleSaved(exercise.itemID)
                                    } label: {
                                        let isSaved = workoutStore.savedExerciseIDs.contains(exercise.itemID)
                                        Label(
                                            isSaved ? "Unsave" : "Save",
                                            systemImage: isSaved ? "bookmark.slash.fill" : "bookmark.fill"
                                        )
                                    }
                                    .tint(Color.workoutAccent)
                                }
                            }
                        }
                    } header: {
                        HStack(alignment: .center) {
                            Label(selectedDateTitle, systemImage: "dumbbell.fill")
                            Spacer()
                            Text("\(selectedExercises.count) \(selectedExercises.count == 1 ? "exercise" : "exercises")")
                                .font(.system(.caption, design: .rounded, weight: .bold))
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
            .toolbarBackground(Color.workoutBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
            .alert("Add exercises first", isPresented: $isEmptyWorkoutAlertPresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Add at least one exercise to \(selectedDateTitle) before starting the timer.")
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
                    Label("Saved", systemImage: "bookmark.fill")
                }

                Button {
                    isCopySheetPresented = true
                } label: {
                    Label("Copy from day", systemImage: "calendar.badge.plus")
                }
                .disabled(copyableDays.isEmpty)

                if splitGroups.isEmpty {
                    Button {
                        pickerRequest = WorkoutLogPickerRequest(context: .all, initialSource: .dataset)
                    } label: {
                        Label("All exercises", systemImage: "square.grid.2x2")
                    }
                } else {
                    ForEach(splitGroups) { group in
                        Button {
                            pickerRequest = WorkoutLogPickerRequest(
                                context: WorkoutLogPickerContext(title: group.title, muscles: group.muscles),
                                initialSource: .dataset
                            )
                        } label: {
                            Label(group.title, systemImage: WorkoutLogPickerContext.systemImage(for: group.title))
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
        }
        .tint(Color.workoutAccent)
        .accessibilityLabel("Add exercise")
        .accessibilityHint("Choose saved exercises, copy a prior day, or browse your workout split")
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
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if isTimerRunning {
            pauseTimer()
        } else if isTimerPaused {
            runningSegmentStartedAt = .now
        } else if activeSessionDateKey != nil {
            isOtherDateTimerDialogPresented = true
        } else if selectedExercises.isEmpty {
            isEmptyWorkoutAlertPresented = true
        } else {
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
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func discardTimer() {
        resetTimerState()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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
        .accessibilityValue("\(workoutCount) \(workoutCount == 1 ? "exercise" : "exercises")\(isSelected ? ", selected" : "")")
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
                ZStack {
                    WorkoutLogRedTimerSurface(isRunning: isRunning)

                    VStack(spacing: 10) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.52), radius: 2, y: 1)
                            .frame(height: 34)

                        Text(elapsedDisplay(at: context.date))
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.62), radius: 2, y: 1)
                    }
                }
                .frame(width: 176, height: 176)
            }
            .buttonStyle(WorkoutLogTimerButtonStyle(isRunning: isRunning))
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(elapsedDisplay(at: context.date))
            .accessibilityHint(isRunning ? "Double tap to pause and show stop controls" : "Double tap to start or resume logging")
        }
    }

    private var accessibilityLabel: String {
        if isRunning { return "Pause workout timer" }
        if isPaused || hasSession { return "Resume workout timer" }
        return "Start workout timer"
    }

    private func elapsedDisplay(at date: Date) -> String {
        let total = totalElapsedSeconds(at: date)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func totalElapsedSeconds(at date: Date) -> Int {
        guard let startedAt else { return elapsedSeconds }
        return elapsedSeconds + max(0, Int(date.timeIntervalSince(startedAt)))
    }
}

/// A vector rendering of Delts' recognizable red timer button, so the diary
/// keeps its visual signature without importing a separate bitmap or theme.
private struct WorkoutLogRedTimerSurface: View {
    let isRunning: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.30))
                .frame(width: 166, height: 166)
                .offset(y: 6)
                .blur(radius: 8)

            Circle()
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 0.45, green: 0.01, blue: 0.02),
                            Color(red: 0.96, green: 0.07, blue: 0.08),
                            Color(red: 0.56, green: 0.01, blue: 0.02),
                            Color(red: 0.98, green: 0.13, blue: 0.12),
                            Color(red: 0.45, green: 0.01, blue: 0.02)
                        ],
                        center: .center
                    )
                )
                .frame(width: 170, height: 170)
                .overlay {
                    Circle()
                        .stroke(Color.black.opacity(0.36), lineWidth: 3)
                        .padding(2)
                }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.96, green: 0.11, blue: 0.11),
                            Color(red: 0.62, green: 0.01, blue: 0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 148, height: 148)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.19), lineWidth: 1.5)
                }

            Circle()
                .trim(from: 0.08, to: 0.39)
                .stroke(
                    Color.white.opacity(isRunning ? 0.32 : 0.22),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 137, height: 137)
                .rotationEffect(.degrees(195))

            Ellipse()
                .fill(Color.white.opacity(0.13))
                .frame(width: 90, height: 38)
                .blur(radius: 4)
                .offset(x: -18, y: -44)
        }
        .shadow(color: Color.black.opacity(0.30), radius: 15, y: 8)
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
    enum Role { case stop, discard }

    let title: String
    let systemImage: String
    let role: Role
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(role == .stop ? Color.workoutAccent : .white)
                    .frame(width: 22, height: 22)
                    .background(role == .stop ? Color.workoutOnAccent.opacity(0.96) : Color.red.opacity(0.88), in: Circle())

                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, minHeight: 46)
            .foregroundStyle(role == .stop ? Color.workoutOnAccent : Color.red)
            .background(
                role == .stop ? Color.workoutAccent : Color.workoutCard.opacity(0.72),
                in: RoundedRectangle(cornerRadius: 21, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(role == .stop ? Color.workoutAccent.opacity(0.45) : Color.red.opacity(0.42), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .workoutPressable()
        .accessibilityLabel(title == "Stop" ? "Stop and save workout" : "Discard timer")
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
        .accessibilityElement(children: .contain)
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
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(active ? Color.workoutAccent : Color.workoutMutedText.opacity(0.72))
                Text(label)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(active ? Color.workoutAccent : Color.workoutCharcoal)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.42)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 5)
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
    let date: Date
    let weightUnit: String
    let rpeScale: StrengthWorkoutRPEScale
    let isLoggingEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding
    let openDetail: () -> Void
    let updateSetCount: (Int) -> Void
    let updateWeight: (UUID, String) -> Void
    let updateReps: (UUID, String) -> Void
    let updateRPE: (UUID, String) -> Void

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
                    .clipped()
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
                title: "Weight",
                placeholder: "Weight",
                suffix: set.weightUnit ?? weightUnit,
                text: Binding(get: { set.weight }, set: updateWeight),
                keyboardType: .decimalPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .weight),
                isEnabled: isEnabled,
                focusedField: focusedField
            )

            WorkoutLogSetValueField(
                title: "Reps",
                placeholder: "Reps",
                suffix: "reps",
                text: Binding(get: { set.reps }, set: updateReps),
                keyboardType: .numberPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .reps),
                isEnabled: isEnabled,
                focusedField: focusedField
            )

            WorkoutLogSetValueField(
                title: rpeScale.inputPlaceholder,
                placeholder: "RPE",
                suffix: set.rpeScale?.shortTitle ?? rpeScale.shortTitle,
                text: Binding(get: { set.rpe }, set: updateRPE),
                keyboardType: rpeScale.allowsDecimalInput ? .decimalPad : .numberPad,
                focus: WorkoutLogSetFocus(exerciseID: exerciseID, setID: set.id, field: .rpe),
                isEnabled: isEnabled,
                focusedField: focusedField
            )
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Set \(setIndex + 1)")
    }
}

private struct WorkoutLogSetValueField: View {
    let title: String
    let placeholder: String
    let suffix: String?
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let focus: WorkoutLogSetFocus
    let isEnabled: Bool
    let focusedField: FocusState<WorkoutLogSetFocus?>.Binding

    var body: some View {
        VStack(spacing: 1) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
                .font(.system(.subheadline, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(isEnabled ? Color.workoutCharcoal : Color.workoutMutedText.opacity(0.72))
                .multilineTextAlignment(.center)
                .focused(focusedField, equals: focus)

            if let suffix {
                Text(suffix)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(Color.workoutCard.opacity(isEnabled ? 0.74 : 0.38), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.workoutHairline.opacity(isEnabled ? 0.4 : 0.24), lineWidth: 0.6)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .accessibilityLabel(title)
        .accessibilityValue(text.isEmpty ? "Not set, \(suffix ?? "")" : "\(text) \(suffix ?? "")")
        .accessibilityHint(isEnabled ? "Set value" : "Start the workout timer to edit")
    }
}

private struct WorkoutLogEmptyRoutineRow: View {
    let splitTitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.workoutAccent)

            VStack(alignment: .leading, spacing: 3) {
                Text("No exercises logged")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)
                Text("Use + to pick \(splitTitle) exercises for this day")
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Exercise picker

private enum WorkoutLogPickerSource: String, CaseIterable, Identifiable {
    case dataset = "Dataset"
    case saved = "Saved"

    var id: String { rawValue }
}

private struct WorkoutLogPickerContext: Hashable {
    static let all = WorkoutLogPickerContext(title: "All Exercises", muscles: [])
    static let saved = WorkoutLogPickerContext(title: "Saved", muscles: [])

    let title: String
    let muscles: Set<String>

    static func systemImage(for title: String) -> String {
        let lowered = title.lowercased()
        if lowered.contains("push") { return "arrow.up.forward.circle" }
        if lowered.contains("pull") { return "arrow.down.backward.circle" }
        if lowered.contains("leg") || lowered.contains("quad") || lowered.contains("hamstring") { return "figure.run" }
        if lowered.contains("core") || lowered.contains("ab") { return "figure.core.training" }
        if lowered.contains("chest") { return "figure.strengthtraining.traditional" }
        if lowered.contains("back") { return "figure.pullup" }
        if lowered.contains("shoulder") { return "figure.strengthtraining.functional" }
        if lowered.contains("arm") || lowered.contains("bicep") || lowered.contains("tricep") { return "dumbbell.fill" }
        if lowered.contains("saved") { return "bookmark.fill" }
        return "square.grid.2x2"
    }
}

private struct WorkoutLogPickerRequest: Identifiable {
    let id = UUID()
    let context: WorkoutLogPickerContext
    let initialSource: WorkoutLogPickerSource
}

private struct WorkoutLogExercisePickerSheet: View {
    @Environment(StrengthWorkoutStore.self) private var workoutStore
    let request: WorkoutLogPickerRequest
    let selectedDate: Date
    let onDone: () -> Void

    @State private var source: WorkoutLogPickerSource
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
        _source = State(initialValue: request.initialSource)
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
                    Picker("Source", selection: $source) {
                        ForEach(WorkoutLogPickerSource.allCases) { source in
                            Text(source.rawValue).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    WorkoutLogSearchField(searchText: $searchText)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 10, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

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
                        ContentUnavailableView {
                            Label(source == .saved ? "No saved exercises" : "No exercises found", systemImage: "dumbbell")
                        } description: {
                            Text(source == .saved ? "Save exercises from the dataset to keep them here." : "Try changing your search or filters.")
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(filteredExercises) { item in
                            WorkoutLogPickerRow(
                                item: item,
                                isSelected: workoutStore.containsExercise(item.id, on: selectedDate)
                            ) {
                                workoutStore.toggleExercise(item, on: selectedDate)
                            }
                            .listRowBackground(
                                Color.workoutPanel.opacity(workoutStore.containsExercise(item.id, on: selectedDate) ? 0.30 : 0.18)
                            )
                            .listRowSeparatorTint(Color.workoutHairline.opacity(0.32))
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
            .listSectionSpacing(0)
            .background(Color.workoutBackground)
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Add \(request.context.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.workoutBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDone)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(Color.workoutAccent)
                }
            }
        }
        .workoutScreen()
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(filteredExercises.count) \(filteredExercises.count == 1 ? "exercise" : "exercises")")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)

                Text(selectedSort.title)
                    .font(.caption)
                    .foregroundStyle(Color.workoutMutedText)
            }

            Spacer()

            Button(action: resetFilters) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(hasActiveFilters ? Color.workoutInferno : Color.workoutMutedText)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(
                        (hasActiveFilters ? Color.workoutInferno : Color.workoutPanel).opacity(hasActiveFilters ? 0.10 : 0.22),
                        in: Capsule()
                    )
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
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Color.workoutPanel.opacity(selectedSort == .name ? 0.30 : 0.46), in: Capsule())
            }
            .buttonStyle(.plain)
            .workoutPressable()
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                filterMenu(
                    title: "Primary",
                    value: selectionTitle(selectedPrimaryMuscles),
                    systemImage: "scope"
                ) {
                    menuChoice("All Primary", isSelected: selectedPrimaryMuscles.isEmpty) { selectedPrimaryMuscles.removeAll() }
                    ForEach(contextPrimaryMuscles, id: \.self) { value in
                        menuChoice(value, isSelected: selectedPrimaryMuscles.contains(value)) { selectedPrimaryMuscles = [value] }
                    }
                }

                filterMenu(
                    title: "Secondary",
                    value: selectionTitle(selectedSecondaryMuscles),
                    systemImage: "scope"
                ) {
                    menuChoice("All Secondary", isSelected: selectedSecondaryMuscles.isEmpty) { selectedSecondaryMuscles.removeAll() }
                    ForEach(library.availableSecondaryMuscles, id: \.self) { value in
                        menuChoice(value, isSelected: selectedSecondaryMuscles.contains(value)) { selectedSecondaryMuscles = [value] }
                    }
                }

                filterMenu(
                    title: "Equipment",
                    value: selectionTitle(selectedEquipment),
                    systemImage: "dumbbell.fill"
                ) {
                    menuChoice("All Equipment", isSelected: selectedEquipment.isEmpty) { selectedEquipment.removeAll() }
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

    private func selectionTitle(_ selection: Set<String>) -> String {
        selection.first ?? "All"
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
}

private struct WorkoutLogSearchField: View {
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(searchText.isEmpty ? Color.workoutSecondaryAccent : Color.workoutAccent)

            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.workoutMutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 50)
        .workoutLiquidBarSurface(cornerRadius: 22)
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
        }
        .padding(.horizontal, 12)
        .frame(minWidth: 112, minHeight: 46, alignment: .leading)
        .background(
            Color.workoutPanel.opacity(isDefault ? 0.30 : 0.46),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke((isDefault ? Color.workoutHairline : Color.workoutAccent).opacity(0.32), lineWidth: 0.5)
        }
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
            .toolbarBackground(Color.workoutBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

    private var exerciseNames: String {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(dayTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.workoutCharcoal)
                    .lineLimit(1)
                Text(exerciseNames)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.workoutMutedText)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(day.exercises.count)")
                    .font(.system(.title3, design: .rounded, weight: .black).monospacedDigit())
                    .foregroundStyle(Color.workoutAccent)
                Text(day.exercises.count == 1 ? "exercise" : "exercises")
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Copies these exercises to \(targetDescription)")
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day.date) { return "Today" }
        if Calendar.current.isDateInYesterday(day.date) { return "Yesterday" }
        return day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private var targetDescription: String { "the selected day" }
}
