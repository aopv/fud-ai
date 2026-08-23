import SwiftUI
import Flutter
import FlutterPluginRegistrant

/// Shared Progress rendering backed by the existing native stores. Flutter only
/// receives display snapshots; writes and destructive actions remain in Swift.
struct ProgressTabView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(StrengthWorkoutStore.self) private var strengthWorkoutStore
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @State private var showLogWeight = false
    @State private var showLogBodyFat = false
    @State private var showGoalReached = false
    @State private var showAllWeights = false
    @State private var showAllBodyFat = false
    @State private var showWorkoutHistory = false

    private var userProfile: UserProfile { profileStore.profile }

    private var workoutCalorieSessions: [StrengthWorkoutSession] {
        strengthWorkoutStore.completedSessions.filter { $0.caloriesBurned != nil }
    }

    /// Changes whenever a visible Progress dependency changes. Rebuilding the
    /// embedded engine after a native sheet saves guarantees Flutter cannot show
    /// stale values without introducing a second persistence layer.
    private var snapshotRevision: String {
        let nutritionRevision = foodStore.entries.reduce(into: (0, 0.0, 0.0, 0.0)) { totals, entry in
            totals.0 += entry.calories
            totals.1 += entry.protein
            totals.2 += entry.carbs
            totals.3 += entry.fat
        }
        let workoutCaloriesRevision = workoutCalorieSessions.reduce(0) {
            $0 + ($1.caloriesBurned ?? 0)
        }

        return [
            weightStore.latestEntry?.id.uuidString ?? "weight-empty",
            bodyFatStore.latestEntry?.id.uuidString ?? "body-fat-empty",
            String(foodStore.entries.count),
            String(nutritionRevision.0),
            String(nutritionRevision.1),
            String(nutritionRevision.2),
            String(nutritionRevision.3),
            String(workoutCalorieSessions.count),
            String(workoutCaloriesRevision),
            String(userProfile.effectiveCalories),
            String(userProfile.effectiveProtein),
            String(userProfile.effectiveCarbs),
            String(userProfile.effectiveFat),
            weightUnitRaw,
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            if CommandLine.arguments.contains("--native-progress") {
                NativeProgressTabView()
            } else {
                FlutterProgressHost(
                    snapshotProvider: progressSnapshot,
                    actionHandler: handleFlutterAction
                )
                .id(snapshotRevision)
                .background(NeoAppColors.canvas)
            }
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightSheet(
                currentWeightKg: weightStore.latestEntry?.weightKg ?? userProfile.weightKg
            ) { weightKg in
                weightStore.addEntry(WeightEntry(weightKg: weightKg))
            }
        }
        .sheet(isPresented: $showLogBodyFat) {
            let seed = bodyFatStore.latestEntry?.bodyFatFraction
                ?? userProfile.bodyFatPercentage
                ?? 0.20
            LogBodyFatSheet(currentFraction: seed) { fraction in
                bodyFatStore.addEntry(BodyFatEntry(bodyFatFraction: fraction))
            }
        }
        .alert("Congratulations!", isPresented: $showGoalReached) {
            Button("Keep Going", role: .cancel) { }
        } message: {
            Text("You've reached your goal weight! Head to Settings to switch your goal (Maintain, Lose, or Gain) and tap Recalculate Goals to refresh your targets.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .weightGoalReached)) { _ in
            showGoalReached = true
        }
        .sheet(isPresented: $showAllWeights) {
            AllWeightHistoryView(
                entries: weightStore.entries.sorted { $0.date > $1.date },
                useMetric: weightUnitRaw == "kg",
                onDelete: { entry in weightStore.deleteEntry(entry) }
            )
        }
        .sheet(isPresented: $showAllBodyFat) {
            AllBodyFatHistoryView(
                entries: bodyFatStore.entries.sorted { $0.date > $1.date },
                onDelete: { entry in bodyFatStore.deleteEntry(entry) }
            )
        }
        .sheet(isPresented: $showWorkoutHistory) {
            WorkoutHistoryView(
                sessions: workoutCalorieSessions,
                onDelete: { session in
                    strengthWorkoutStore.deleteSession(session.id)
                }
            )
        }
    }

    private func progressSnapshot(rangeName: String) -> [String: Any] {
        let range = TimeRange(channelValue: rangeName)
        let dateRange = range.dateRange()
        let useMetric = weightUnitRaw == "kg"
        let displayWeight: (Double) -> Double = { kg in
            useMetric ? kg : kg * 2.20462
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dailyCalories: [[String: Any]] = (0..<range.days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let calories = foodStore.calories(for: date)
            guard calories > 0 else { return nil }
            return [
                "timestampMs": Self.milliseconds(date),
                "calories": calories,
            ]
        }.reversed()

        var totalProtein = 0.0
        var totalCarbs = 0.0
        var totalFat = 0.0
        var loggedDayCount = 0
        for offset in 0..<range.days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            let entries = foodStore.entries(for: date)
            guard !entries.isEmpty else { continue }
            totalProtein += entries.reduce(0) { $0 + $1.protein }
            totalCarbs += entries.reduce(0) { $0 + $1.carbs }
            totalFat += entries.reduce(0) { $0 + $1.fat }
            loggedDayCount += 1
        }
        let divisor = Double(max(loggedDayCount, 1))

        var snapshot: [String: Any] = [
            "range": range.channelValue,
            "weightUnit": useMetric ? "kg" : "lbs",
            "weightEntries": weightStore.entries(in: dateRange).map { entry in
                [
                    "timestampMs": Self.milliseconds(entry.date),
                    "value": displayWeight(entry.weightKg),
                ]
            },
            "bodyFatEntries": bodyFatStore.entries(in: dateRange).map { entry in
                [
                    "timestampMs": Self.milliseconds(entry.date),
                    "value": entry.bodyFatFraction * 100,
                ]
            },
            "dailyCalories": dailyCalories,
            "showsBodyFat": !bodyFatStore.entries.isEmpty
                || userProfile.bodyFatPercentage != nil
                || userProfile.goalBodyFatPercentage != nil,
            "weightHistoryCount": weightStore.entries.count,
            "bodyFatHistoryCount": bodyFatStore.entries.count,
            "workoutHistoryCount": workoutCalorieSessions.count,
            "calorieGoal": userProfile.effectiveCalories,
            "averageProtein": loggedDayCount == 0 ? 0 : totalProtein / divisor,
            "averageCarbs": loggedDayCount == 0 ? 0 : totalCarbs / divisor,
            "averageFat": loggedDayCount == 0 ? 0 : totalFat / divisor,
            "proteinGoal": userProfile.effectiveProtein,
            "carbsGoal": userProfile.effectiveCarbs,
            "fatGoal": userProfile.effectiveFat,
            "strings": Self.localizedStrings,
        ]

        if let current = weightStore.latestEntry?.weightKg {
            snapshot["currentWeight"] = displayWeight(current)
        }
        if let goal = userProfile.goalWeightKg {
            snapshot["goalWeight"] = displayWeight(goal)
        }
        if let current = bodyFatStore.latestEntry?.bodyFatFraction ?? userProfile.bodyFatPercentage {
            snapshot["currentBodyFat"] = current * 100
        }
        if let goal = userProfile.goalBodyFatPercentage {
            snapshot["goalBodyFat"] = goal * 100
        }
        return snapshot
    }

    private func handleFlutterAction(_ action: FlutterProgressAction) {
        switch action {
        case .logWeight:
            showLogWeight = true
        case .logBodyFat:
            showLogBodyFat = true
        case .weightHistory:
            showAllWeights = true
        case .bodyFatHistory:
            showAllBodyFat = true
        case .workoutHistory:
            showWorkoutHistory = true
        }
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static let localizedStrings: [String: String] = [
        "eyebrow": String(localized: "Your data").uppercased(),
        "title": String(localized: "Progress").uppercased(),
        "subtitle": String(localized: "Trends, targets, and training history"),
        "weight": String(localized: "Weight").uppercased(),
        "bodyFat": String(localized: "Body Fat").uppercased(),
        "logWeight": String(localized: "Log Weight").uppercased(),
        "logBodyFat": String(localized: "Log Body Fat").uppercased(),
        "current": String(localized: "Current").uppercased(),
        "goal": String(localized: "Goal").uppercased(),
        "netChange": String(localized: "Net Change").uppercased(),
        "average": String(localized: "Average").uppercased(),
        "emptyWeight": String(localized: "Log your first weight to see trends"),
        "emptyBodyFat": String(localized: "Log your first body-fat reading to see trends"),
        "weightHistory": String(localized: "Weight History").uppercased(),
        "bodyFatHistory": String(localized: "Body Fat History").uppercased(),
        "workoutHistory": String(localized: "Workout History").uppercased(),
        "entries": String(localized: "entries"),
        "entry": String(localized: "entry"),
        "tapToView": String(localized: "tap to view or delete"),
        "calories": String(localized: "Calories").uppercased(),
        "averagePrefix": String(localized: "Avg").uppercased(),
        "noFood": String(localized: "No food logged yet"),
        "macroAverages": String(localized: "Macro Averages").uppercased(),
        "protein": String(localized: "Protein").uppercased(),
        "carbs": String(localized: "Carbs").uppercased(),
        "fat": String(localized: "Fat").uppercased(),
    ]
}

enum FlutterProgressAction: String {
    case logWeight
    case logBodyFat
    case weightHistory
    case bodyFatHistory
    case workoutHistory
}

private extension TimeRange {
    init(channelValue: String) {
        switch channelValue {
        case "month": self = .month
        case "threeMonths": self = .threeMonths
        case "sixMonths": self = .sixMonths
        case "year": self = .year
        case "allTime": self = .allTime
        default: self = .week
        }
    }

    var channelValue: String {
        switch self {
        case .week: "week"
        case .month: "month"
        case .threeMonths: "threeMonths"
        case .sixMonths: "sixMonths"
        case .year: "year"
        case .allTime: "allTime"
        }
    }
}

private struct FlutterProgressHost: UIViewControllerRepresentable {
    let snapshotProvider: (String) -> [String: Any]
    let actionHandler: (FlutterProgressAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            snapshotProvider: snapshotProvider,
            actionHandler: actionHandler
        )
    }

    func makeUIViewController(context: Context) -> FlutterViewController {
        context.coordinator.makeViewController()
    }

    func updateUIViewController(_ uiViewController: FlutterViewController, context: Context) {
        context.coordinator.snapshotProvider = snapshotProvider
        context.coordinator.actionHandler = actionHandler
    }

    static func dismantleUIViewController(_ uiViewController: FlutterViewController, coordinator: Coordinator) {
        coordinator.shutDown()
    }

    @MainActor
    final class Coordinator {
        var snapshotProvider: (String) -> [String: Any]
        var actionHandler: (FlutterProgressAction) -> Void
        private var engine: FlutterEngine?
        private var channel: FlutterMethodChannel?

        init(
            snapshotProvider: @escaping (String) -> [String: Any],
            actionHandler: @escaping (FlutterProgressAction) -> Void
        ) {
            self.snapshotProvider = snapshotProvider
            self.actionHandler = actionHandler
        }

        func makeViewController() -> FlutterViewController {
            let engine = FlutterEngine(name: "fud-ai-progress-(UUID().uuidString)")
            engine.run()
            GeneratedPluginRegistrant.register(with: engine)

            let channel = FlutterMethodChannel(
                name: "com.apoorvdarshan.fudai/progress",
                binaryMessenger: engine.binaryMessenger
            )
            channel.setMethodCallHandler { [weak self] call, result in
                guard let self else {
                    result(FlutterError(code: "bridge_gone", message: "Progress bridge was released.", details: nil))
                    return
                }
                switch call.method {
                case "getSnapshot":
                    let arguments = call.arguments as? [String: Any]
                    let range = arguments?["range"] as? String ?? "week"
                    result(self.snapshotProvider(range))
                case "performAction":
                    let arguments = call.arguments as? [String: Any]
                    guard let rawAction = arguments?["action"] as? String,
                          let action = FlutterProgressAction(rawValue: rawAction) else {
                        result(FlutterError(code: "invalid_action", message: "Unknown Progress action.", details: nil))
                        return
                    }
                    self.actionHandler(action)
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

            self.engine = engine
            self.channel = channel
            let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
            controller.view.backgroundColor = .clear
            return controller
        }

        func shutDown() {
            channel?.setMethodCallHandler(nil)
            engine?.destroyContext()
            channel = nil
            engine = nil
        }
    }
}
