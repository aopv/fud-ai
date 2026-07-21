import SwiftUI
import Photos
import PhotosUI
import UIKit
import HealthKit
import StoreKit
import WidgetKit
import AVFoundation
import Speech

// MARK: - Camera Mode
enum CameraMode {
    case snapFood
    case snapFoodWithContext
}

private let fudAIAppStoreID = "6758935726"
private let fudAIAppStoreURL = URL(string: "https://apps.apple.com/us/app/fud-ai-calorie-tracker/id6758935726")!

private enum AppUpdateState: Equatable {
    case idle
    case checking
    case upToDate(current: String, latest: String?)
    case available(current: String, latest: String, url: URL)
    case failed(current: String)

    var isUpdateAvailable: Bool {
        if case .available = self {
            return true
        }
        return false
    }

    var hasStartedCheck: Bool {
        if case .idle = self {
            return false
        }
        return true
    }
}

private struct AppStoreLookupResponse: Decodable {
    let results: [AppStoreLookupResult]
}

private struct AppStoreLookupResult: Decodable {
    let version: String
    let trackViewUrl: String?
}

private enum AppUpdateChecker {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    static var currentVersionDisplay: String {
        currentVersion
    }

    static func check() async -> AppUpdateState {
        let current = currentVersion

        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(fudAIAppStoreID)&country=us") else {
            return .failed(current: current)
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                return .failed(current: current)
            }

            let lookup = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
            guard let result = lookup.results.first else {
                return .upToDate(current: current, latest: nil)
            }

            let updateURL = result.trackViewUrl.flatMap(URL.init(string:)) ?? fudAIAppStoreURL
            if isVersion(result.version, newerThan: current) {
                return .available(current: current, latest: result.version, url: updateURL)
            }

            return .upToDate(current: current, latest: result.version)
        } catch {
            return .failed(current: current)
        }
    }

    private static func isVersion(_ latest: String, newerThan current: String) -> Bool {
        let latestParts = latest.split(separator: ".").map { Int($0) ?? 0 }
        let currentParts = current.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(latestParts.count, currentParts.count)

        for index in 0..<count {
            let latestValue = index < latestParts.count ? latestParts[index] : 0
            let currentValue = index < currentParts.count ? currentParts[index] : 0

            if latestValue > currentValue {
                return true
            }
            if latestValue < currentValue {
                return false
            }
        }

        return false
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @Environment(NotificationManager.self) private var notificationManager
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue
    @AppStorage(WorkoutTabMode.storageKey) private var workoutTabModeRaw = WorkoutTabMode.defaultMode.rawValue
    @State private var appUpdateState: AppUpdateState = .idle
    @State private var selectedTab: AppTab = .home

    private var workoutsTabIcon: String {
        WorkoutTabMode.mode(for: workoutTabModeRaw).tabIcon
    }

    var body: some View {
        standardTabView
            .tint(AppThemeColor.color(for: appThemeColorRaw).color)
            .task {
                await refreshAppUpdateState()
            }
    }

    private var standardTabView: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(AppTab.home)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            ProgressTabView()
                .tag(AppTab.progress)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Progress")
                }

            ChatView()
                .tag(AppTab.coach)
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Coach")
                }

            ProfileView(
                updateState: $appUpdateState,
                refreshUpdateState: {
                    await refreshAppUpdateState(force: true)
                }
            )
                .tag(AppTab.settings)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .badge(appUpdateState.isUpdateAvailable ? "!" : nil)

            WorkoutsView()
                .tag(AppTab.workouts)
                .tabItem {
                    Image(systemName: workoutsTabIcon)
                    Text("Workouts")
                }
        }
    }

    private enum AppTab: String, Hashable {
        case home
        case progress
        case coach
        case settings
        case workouts
    }

    @MainActor
    private func refreshAppUpdateState(force: Bool = false) async {
        if !force && appUpdateState.hasStartedCheck {
            return
        }

        appUpdateState = .checking
        appUpdateState = await AppUpdateChecker.check()

        // A newer version is out — fire a one-shot notification (de-duped per version, gated by the
        // "App Updates" toggle) so the user finds out even if they don't scroll to the About section.
        if case let .available(_, latest, url) = appUpdateState {
            await notificationManager.notifyUpdateAvailable(version: latest, url: url)
        }
    }
}

// MARK: - About (embedded as the last Settings section)
private struct AboutSettingsSections: View {
    @Binding private var updateState: AppUpdateState
    private let refreshUpdateState: () async -> Void

    @State private var showShareSheet = false

    init(updateState: Binding<AppUpdateState>, refreshUpdateState: @escaping () async -> Void) {
        self._updateState = updateState
        self.refreshUpdateState = refreshUpdateState
    }

    private var shareMessage: String {
        String(localized: "I've been tracking my meals with Fud AI — snap a photo, speak it, or type it, and the AI logs the calories. It's free, open source, and your data stays on your device.\n\nDownload: https://fud-ai.app")
    }

    var body: some View {
        Group {
            Section("About") {
                updateRow

                // Rate the App
                Button {
                    requestNativeReview()
                } label: {
                    Label {
                        Text("Rate the App")
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Share the App — uses UIActivityViewController so both
                // the personalized message AND the App Store URL get
                // forwarded to every share target (SwiftUI ShareLink
                // drops the message arg for most targets).
                Button {
                    showShareSheet = true
                } label: {
                    Label {
                        Text("Share the App")
                    } icon: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Open Source
                Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai")!) {
                    Label {
                        Text("Open Source (MIT)")
                    } icon: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Star the Repo
                Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai")!) {
                    Label {
                        Text("Star on GitHub")
                    } icon: {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Vote on Product Hunt
                Link(destination: URL(string: "https://www.producthunt.com/products/fud-ai-calorie-tracker")!) {
                    Label {
                        Text("Vote on Product Hunt")
                    } icon: {
                        Image(systemName: "hand.thumbsup.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Report an Issue
                Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai/issues/new?labels=bug&title=Bug:%20")!) {
                    Label {
                        Text("Report an Issue")
                    } icon: {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Request a Feature
                Link(destination: URL(string: "https://github.com/apoorvdarshan/fud-ai/issues/new?labels=enhancement&title=Feature:%20")!) {
                    Label {
                        Text("Request a Feature")
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Contact
                Link(destination: URL(string: "mailto:apoorv@fud-ai.app")!) {
                    Label {
                        Text("Contact Us")
                    } icon: {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Follow on X
                Link(destination: URL(string: "https://x.com/apoorvdarshan")!) {
                    Label {
                        Text("Follow on X")
                    } icon: {
                        Image(systemName: "at")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Instagram
                Link(destination: URL(string: "https://www.instagram.com/fudai.app/")!) {
                    Label {
                        Text("Follow on Instagram")
                    } icon: {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // LinkedIn
                Link(destination: URL(string: "https://www.linkedin.com/company/fud-ai-app")!) {
                    Label {
                        Text("Follow on LinkedIn")
                    } icon: {
                        Image(systemName: "briefcase.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)
            }
            .listRowBackground(AppColors.appCard)

            Section {
                // Privacy Policy
                Link(destination: URL(string: "https://fud-ai.app/privacy.html")!) {
                    Label {
                        Text("Privacy Policy")
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)

                // Terms of Service
                Link(destination: URL(string: "https://fud-ai.app/terms.html")!) {
                    Label {
                        Text("Terms of Service")
                    } icon: {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(AppColors.calorie)
                    }
                }
                .tint(.primary)
            }
            .listRowBackground(AppColors.appCard)

            Section {
                VStack(spacing: 4) {
                    Text("Made by Apoorv Darshan")
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("with care, for everyone")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(activityItems: [shareMessage, fudAIAppStoreURL])
        }
    }

    @ViewBuilder
    private var updateRow: some View {
        switch updateState {
        case .checking:
            HStack {
                Label {
                    Text("Checking for Updates")
                } icon: {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .foregroundStyle(AppColors.calorie)
                }

                Spacer()

                ProgressView()
                    .tint(AppColors.calorie)
            }

        case .available(let current, let latest, let url):
            Button {
                UIApplication.shared.open(url)
            } label: {
                HStack(spacing: 12) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Update Available")
                            Text("Current \(current) -> Latest \(latest)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(AppColors.calorie)

                            Circle()
                                .fill(AppColors.calorie)
                                .frame(width: 8, height: 8)
                                .offset(x: 3, y: -3)
                        }
                    }

                    Spacer()

                    Text("Update")
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.calorie)
                }
            }
            .tint(.primary)

        case .failed:
            Button {
                Task {
                    await refreshUpdateState()
                }
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for Updates")
                            Text("Version \(AppUpdateChecker.currentVersionDisplay)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .foregroundStyle(AppColors.calorie)
                    }

                    Spacer()
                }
            }
            .tint(.primary)

        case .idle, .upToDate:
            Button {
                Task {
                    await refreshUpdateState()
                }
            } label: {
                HStack {
                    Label {
                        Text("App Version")
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(AppColors.calorie)
                    }

                    Spacer()

                    Text(AppUpdateChecker.currentVersionDisplay)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
        }
    }

    private func requestNativeReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }
}

// MARK: - Share Sheet wrapper (UIActivityViewController)
// Used by AboutView so the personalized message AND the App Store URL
// both reach every share target. SwiftUI's ShareLink message arg is
// dropped by most targets; UIActivityViewController forwards every item.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Home View (Main Dashboard)
struct HomeView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WaterStore.self) private var waterStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCamera = false
    @State private var showBarcodeScanner = false
    @State private var capturedImage: UIImage?
    @State private var cameraMode: CameraMode = .snapFood
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    private enum RetryRequest {
        case analysis(images: [UIImage], mode: CameraMode, description: String?)
        case text(String)
        case barcode(String)
    }
    @State private var retryRequest: RetryRequest?
    @State private var selectedDate: Date = .now
    @State private var showVoicePopover = false
    @State private var showTextPopover = false
    @State private var showManualPopover = false
    @State private var showSiriPhrases = false
    @State private var savedMealsMode: SavedMealsMode?
    @State private var showCopyFromDaySheet = false
    @State private var pendingContextImage: UIImage?
    @State private var captureImages: [UIImage] = []
    @State private var isImportingPhotos = false
    @State private var showMultiPhotoCaptureSheet = false
    @State private var contextDescription: String = ""
    @State private var showContextSheet = false

    enum ActiveSheet: String, Identifiable {
        case analyzing, foodResult, analyzingText, lookingUpBarcode, editFood, importSharedMeal
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var editingEntry: FoodEntry?
    @State private var pendingSharedMeals: [FoodEntry] = []

    @State private var currentFoodResult: GeminiService.FoodAnalysis?
    @State private var currentImage: UIImage?
    @State private var currentImages: [UIImage] = []
    @State private var currentEmoji: String?
    @State private var currentFoodSource: FoodSource = .snapFood
    @State private var showNutritionDetail = false
    @State private var showCustomWaterLog = false
    @State private var hasPresentedFoodDestination = false
    @State private var didPrewarmFoodDestinations = false
    // Bumped each time the app is opened (cold launch = 1, then +1 on every
    // return from background). Drives the gauge + macro "fill from zero" reveal.
    // Not bumped on tab switches or data edits, so it only plays on app open.
    @State private var launchFillEpoch = 1
    @State private var wasBackgrounded = false
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @AppStorage(FoodLogSortOrder.storageKey) private var foodLogSortOrderRaw = FoodLogSortOrder.defaultOrder.rawValue
    @AppStorage(HomeTopNutrient.storageKey) private var homeTopNutrientsRaw = HomeTopNutrient.storageValue(for: HomeTopNutrient.defaultSelection)
    @AppStorage(OptionalNutrientGoals.storageKey) private var optionalNutrientGoalsData = Data()
    @AppStorage(WaterSettings.enabledKey) private var waterTrackingEnabled = false
    @AppStorage(WaterSettings.dailyGoalKey) private var waterDailyGoal = WaterSettings.defaultDailyGoalMl
    @AppStorage(WaterSettings.unitKey) private var waterUnitRaw = WaterUnit.defaultUnit.rawValue
    @Environment(ProfileStore.self) private var profileStore

    /// Force a body re-evaluation whenever profileStore.profile changes by reading it
    /// at the top of body. SwiftUI's @Observable tracking sometimes misses the access
    /// when the read is buried in a computed property; explicit access guarantees it.
    private var userProfile: UserProfile { profileStore.profile }
    private var calorieGoal: Int { userProfile.effectiveCalories }
    private var proteinGoal: Int { userProfile.effectiveProtein }
    private var carbsGoal: Int { userProfile.effectiveCarbs }
    private var fatGoal: Int { userProfile.effectiveFat }
    private var selectedCalories: Int { foodStore.calories(for: selectedDate) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    private var foodLogSortOrder: FoodLogSortOrder { FoodLogSortOrder.order(for: foodLogSortOrderRaw) }
    private var homeTopNutrients: [HomeTopNutrient] { HomeTopNutrient.selection(from: homeTopNutrientsRaw) }
    private var optionalNutrientGoals: OptionalNutrientGoals { OptionalNutrientGoals.decoded(from: optionalNutrientGoalsData) }
    private var waterUnit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .defaultUnit }
    private var logDateForSelectedDay: Date { logDate(on: selectedDate) }

    private var navigationTitle: String {
        if isToday { return "Today" }
        return selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// Horizontal swipe → previous/next day. Attached only to the top section (calorie hero +
    /// macros), not the food log below "View More", so it never competes with the food rows'
    /// own swipe actions or vertical scrolling there. `.simultaneousGesture` lets the List still
    /// scroll; we act only on a clearly horizontal flick.
    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                changeDay(by: dx < 0 ? 1 : -1)
            }
    }

    /// Step the selected day by `delta` (−1 previous, +1 next), from the swipe gesture. Won't move
    /// past today, and gives a light haptic on a successful change. Animates with the existing
    /// `.animation(.snappy, value: selectedDate)` on the List.
    private func changeDay(by delta: Int) {
        let calendar = Calendar.current
        guard let newDate = calendar.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        if delta > 0 && calendar.startOfDay(for: newDate) > calendar.startOfDay(for: .now) { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        selectedDate = newDate
    }

    private func logDate(on day: Date, now: Date = .now) -> Date {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return now }

        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: now)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond
        return calendar.date(from: components) ?? day
    }

    private func logWater(_ milliliters: Int) {
        _ = waterStore.add(milliliters: milliliters, on: logDateForSelectedDay)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Lets the native menu finish its selection before presenting the chosen destination.
    /// The first presentation skips animation so cold setup cannot stretch the handoff;
    /// later selections retain the short transition that already feels responsive.
    private func presentFoodDestination(_ updates: @escaping () -> Void) {
        let shouldAnimate = hasPresentedFoodDestination
        hasPresentedFoodDestination = true

        DispatchQueue.main.async {
            var transaction = Transaction(animation: shouldAnimate ? .easeOut(duration: 0.16) : nil)
            transaction.disablesAnimations = !shouldAnimate
            withTransaction(transaction) {
                updates()
            }
        }
    }

    /// Loads the native menu and media authorization code paths while Home is idle.
    /// Reading authorization status never prompts the user or starts camera/microphone capture.
    private func prewarmFoodDestinations() {
        guard !didPrewarmFoodDestinations else { return }
        didPrewarmFoodDestinations = true

        let placeholderAction = UIAction(title: "") { _ in }
        let placeholderSubmenu = UIMenu(title: "", children: [placeholderAction])
        _ = UIMenu(title: "", children: [placeholderSubmenu])

        Task.detached(priority: .utility) {
            _ = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            _ = AVCaptureDevice.authorizationStatus(for: .video)
            _ = SFSpeechRecognizer.authorizationStatus()
        }
    }

    @ViewBuilder
    private var waterQuickMenuItems: some View {
        Button {
            presentFoodDestination {
                showCustomWaterLog = true
            }
        } label: {
            Label("Custom", systemImage: "slider.horizontal.3")
        }
        Button {
            logWater(750)
        } label: {
            Label("3 Glasses (~\(waterUnit.formatted(milliliters: 750)))", systemImage: "drop.fill")
        }
        Button {
            logWater(500)
        } label: {
            Label("2 Glasses (~\(waterUnit.formatted(milliliters: 500)))", systemImage: "drop.fill")
        }
        Button {
            logWater(250)
        } label: {
            Label("1 Glass (~\(waterUnit.formatted(milliliters: 250)))", systemImage: "drop.fill")
        }
    }

    var body: some View {
        // Explicit observation tracking — reads profileStore.profile at body root
        // so SwiftUI invalidates this view on every profile mutation.
        let _ = profileStore.profile
        return NavigationStack {
            List {
                // Week energy strip
                Section {
                    WeekEnergyStrip(
                        selectedDate: $selectedDate,
                        caloriesForDate: { foodStore.calories(for: $0) },
                        calorieGoal: calorieGoal
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }

                // Calorie hero (semicircle gauge)
                Section {
                    CalorieGauge(eaten: selectedCalories, goal: calorieGoal, launchFillEpoch: launchFillEpoch)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .contentShape(Rectangle())
                        .simultaneousGesture(daySwipeGesture)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                // Top nutrient row (vertical bars)
                Section {
                    HStack(alignment: .top, spacing: 4) {
                        ForEach(homeTopNutrients) { nutrient in
                            MacroVerticalBar(
                                label: nutrient.displayName,
                                current: nutrient.value(from: foodStore, on: selectedDate),
                                goal: nutrient.goal(for: userProfile, optionalGoals: optionalNutrientGoals),
                                unit: nutrient.unit,
                                gradient: nutrient.gradientColors,
                                launchFillEpoch: launchFillEpoch
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                    .simultaneousGesture(daySwipeGesture)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if waterTrackingEnabled {
                        WaterProgressRow(
                            current: waterStore.total(on: selectedDate),
                            goal: waterDailyGoal,
                            unit: waterUnit
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 2, leading: 20, bottom: 2, trailing: 20))
                    }

                    Button {
                        showNutritionDetail = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("View More")
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                            Spacer()
                        }
                        .foregroundStyle(AppColors.calorie.opacity(0.6))
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Food list
                let mealGroups = foodStore.entriesByMeal(for: selectedDate, order: foodLogSortOrder)
                if mealGroups.isEmpty {
                    Section(isToday ? "Today's Food" : "Food Log") {
                        Text("No foods logged")
                            .foregroundStyle(.secondary)
                            .listRowBackground(AppColors.appCard)
                    }
                } else {
                    ForEach(mealGroups) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                FoodRow(entry: entry)
                                    .listRowBackground(AppColors.appCard)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        editingEntry = entry
                                        activeSheet = .editFood
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            foodStore.deleteEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                        Button {
                                            foodStore.toggleFavorite(entry)
                                        } label: {
                                            Label(foodStore.isFavorite(entry) ? "Unfavorite" : "Favorite", systemImage: foodStore.isFavorite(entry) ? "heart.slash.fill" : "heart.fill")
                                        }
                                        .tint(AppColors.calorie)
                                    }
                            }
                        } header: {
                            HStack(alignment: .center) {
                                Label(group.meal.displayName, systemImage: group.meal.icon)
                                if group.id == mealGroups.first?.id {
                                    Menu {
                                        Picker("Food Log Order", selection: $foodLogSortOrderRaw) {
                                            ForEach(FoodLogSortOrder.allCases) { order in
                                                Text(order.displayName).tag(order.rawValue)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.up.arrow.down")
                                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                            Text("Sort")
                                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        }
                                    }
                                    .tint(AppColors.calorie)
                                    .textCase(nil)
                                    .padding(.leading, 8)
                                }
                                Spacer()
                                // Share the whole meal as a fudai://add-meal link (issue #107)
                                Button {
                                    MealShare.presentShareSheet(for: group.entries)
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(AppColors.calorie)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, 12)
                                .textCase(nil)
                                // Combined nutrients for this meal (issue #103: chicken + pasta + sauce = one total)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(group.totalCalories) kcal")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(AppColors.calorie)
                                    Text("\(Int(group.totalProtein.rounded()))P · \(Int(group.totalCarbs.rounded()))C · \(Int(group.totalFat.rounded()))F")
                                        .font(.system(.caption2, design: .rounded, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                                .textCase(nil)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .animation(.snappy, value: selectedDate)
            .contentMargins(.bottom, 96, for: .scrollContent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                Menu {
                    if waterTrackingEnabled {
                        Menu {
                            waterQuickMenuItems
                        } label: {
                            Label("Water", systemImage: "drop.fill")
                        }
                    }
                    Menu {
                        Button {
                            presentFoodDestination {
                                showCopyFromDaySheet = true
                            }
                        } label: {
                            Label("Copy from Day", systemImage: "calendar")
                        }
                        Button {
                            presentFoodDestination {
                                savedMealsMode = .favorites
                            }
                        } label: {
                            Label("Favorites", systemImage: "heart.fill")
                        }
                        Button {
                            presentFoodDestination {
                                savedMealsMode = .frequent
                            }
                        } label: {
                            Label("Frequent", systemImage: "repeat")
                        }
                        Button {
                            presentFoodDestination {
                                savedMealsMode = .recent
                            }
                        } label: {
                            Label("Recent", systemImage: "clock.fill")
                        }
                    } label: {
                        Label("Reuse Meal", systemImage: "arrow.clockwise")
                    }

                    Menu {
                        Button {
                            presentFoodDestination {
                                showManualPopover = true
                            }
                        } label: {
                            Label("Manual Entry", systemImage: "square.and.pencil")
                        }
                        Button {
                            presentFoodDestination {
                                showSiriPhrases = true
                            }
                        } label: {
                            Label("Siri Phrases", systemImage: "waveform.circle.fill")
                        }
                        Button {
                            presentFoodDestination {
                                showVoicePopover = true
                            }
                        } label: {
                            Label("Voice", systemImage: "mic.fill")
                        }
                        Button {
                            presentFoodDestination {
                                showTextPopover = true
                            }
                        } label: {
                            Label("Text Input", systemImage: "character.cursor.ibeam")
                        }
                    } label: {
                        Label("Describe Meal", systemImage: "text.bubble.fill")
                    }

                    Menu {
                        Button {
                            presentFoodDestination {
                                showBarcodeScanner = true
                            }
                        } label: {
                            Label("Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button(action: {
                            presentFoodDestination {
                                cameraMode = .snapFoodWithContext
                                isImportingPhotos = true
                                captureImages = []
                                contextDescription = ""
                                selectedPhotoItems = []
                                showPhotoPicker = true
                            }
                        }) {
                            Label("Photos", systemImage: "photo.on.rectangle")
                        }
                        Button(action: {
                            presentFoodDestination {
                                cameraMode = .snapFoodWithContext
                                isImportingPhotos = false
                                captureImages = []
                                contextDescription = ""
                                showCamera = true
                            }
                        }) {
                            Label("Camera", systemImage: "camera.fill")
                        }
                    } label: {
                        Label("Photo & Scan", systemImage: "camera.viewfinder")
                    }
                } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(AppColors.calorie, in: Circle())
                        }
                        .popover(isPresented: $showTextPopover) {
                            TextFoodInputView(
                                onCancel: {
                                    showTextPopover = false
                                },
                                onSubmit: { description in
                                    showTextPopover = false
                                    currentImage = nil
                                    currentImages = []
                                    currentEmoji = nil
                                    currentFoodSource = .textInput
                                    startTextAnalysis(description)
                                }
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                        .popover(isPresented: $showVoicePopover) {
                            VoiceInputView(
                                onCancel: {
                                    showVoicePopover = false
                                },
                                onSubmit: { description in
                                    showVoicePopover = false
                                    currentImage = nil
                                    currentImages = []
                                    currentEmoji = nil
                                    currentFoodSource = .textInput
                                    startTextAnalysis(description)
                                }
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                        .popover(isPresented: $showManualPopover) {
                            ManualEntryView(
                                logDate: logDateForSelectedDay,
                                onCancel: { showManualPopover = false },
                                onSave: { entry in
                                    showManualPopover = false
                                    foodStore.addEntry(entry)
                                }
                            )
                            .presentationCompactAdaptation(.popover)
                        }
                        .padding(24)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    image: $capturedImage,
                    title: captureImages.isEmpty ? nil : "Photo \(captureImages.count + 1)",
                    onCancel: {
                        if !captureImages.isEmpty {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                showMultiPhotoCaptureSheet = true
                            }
                        }
                    }
                )
                    .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(
                    onScan: { barcode in
                        showBarcodeScanner = false
                        startBarcodeLookup(barcode)
                    },
                    onCancel: {
                        showBarcodeScanner = false
                    }
                )
                .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { oldValue, newValue in
                guard let image = newValue else { return }
                capturedImage = nil
                currentEmoji = nil

                captureImages.append(image)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    showMultiPhotoCaptureSheet = true
                }
            }
            .sheet(isPresented: $showMultiPhotoCaptureSheet) {
                MultiPhotoCaptureSheet(
                    images: $captureImages,
                    isImportingPhotos: isImportingPhotos,
                    selectedPhotoItems: $selectedPhotoItems,
                    description: $contextDescription,
                    onAddPhoto: {
                        guard captureImages.count < 10 else { return }
                        showMultiPhotoCaptureSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showCamera = true
                        }
                    },
                    onRemove: { index in
                        guard captureImages.indices.contains(index) else { return }
                        captureImages.remove(at: index)
                        if captureImages.isEmpty {
                            showMultiPhotoCaptureSheet = false
                        }
                    },
                    onAnalyze: {
                        let images = captureImages
                        let description = cameraMode == .snapFoodWithContext ? contextDescription : nil
                        showMultiPhotoCaptureSheet = false
                        captureImages = []
                        currentImages = images
                        currentImage = images.first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            startAnalysis(images: images, mode: cameraMode, description: description)
                        }
                    },
                    onCancel: {
                        showMultiPhotoCaptureSheet = false
                        captureImages = []
                        contextDescription = ""
                    }
                )
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showContextSheet) {
                ContextDescriptionSheet(
                    image: pendingContextImage,
                    description: $contextDescription,
                    onAnalyze: {
                        let desc = contextDescription
                        let image = pendingContextImage
                        showContextSheet = false
                        pendingContextImage = nil
                        
                        if let image {
                            // Delay presenting the next sheet until the current one fully dismisses.
                            // This prevents SwiftUI from silently ignoring the new activeSheet presentation.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                currentImage = image // Ensure currentImage is set so AnalyzingView/FoodResultView shows the image
                                currentImages = [image]
                                startAnalysis(image: image, mode: .snapFoodWithContext, description: desc)
                            }
                        }
                    },
                    onCancel: {
                        showContextSheet = false
                        pendingContextImage = nil
                        currentImage = nil
                        currentImages = []
                    }
                )
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .analyzing:
                    AnalyzingView(image: currentImage)
                case .analyzingText:
                    AnalyzingView(image: nil, message: "Looking up nutrition...")
                case .lookingUpBarcode:
                    AnalyzingView(image: nil, message: "Looking up barcode...")
                case .foodResult:
                    if let result = currentFoodResult {
                        FoodResultView(
                            images: currentImages,
                            emoji: currentEmoji,
                            source: currentFoodSource,
                            name: result.name,
                            calories: result.calories,
                            protein: result.protein,
                            carbs: result.carbs,
                            fat: result.fat,
                            servingSizeGrams: result.servingSizeGrams,
                            sugar: result.sugar,
                            addedSugar: result.addedSugar,
                            fiber: result.fiber,
                            saturatedFat: result.saturatedFat,
                            monounsaturatedFat: result.monounsaturatedFat,
                            polyunsaturatedFat: result.polyunsaturatedFat,
                            cholesterol: result.cholesterol,
                            sodium: result.sodium,
                            potassium: result.potassium,
                            transFat: result.transFat,
                            calcium: result.calcium,
                            iron: result.iron,
                            magnesium: result.magnesium,
                            zinc: result.zinc,
                            vitaminA: result.vitaminA,
                            vitaminC: result.vitaminC,
                            vitaminD: result.vitaminD,
                            vitaminB12: result.vitaminB12,
                            vitaminE: result.vitaminE,
                            vitaminK: result.vitaminK,
                            folate: result.folate,
                            omega3: result.omega3,
                            servingUnitOptions: result.servingUnitOptions,
                            selectedServingUnit: result.selectedServingUnit,
                            selectedServingQuantity: result.selectedServingQuantity,
                            logDate: logDateForSelectedDay,
                            profile: userProfile,
                            dayEntries: foodStore.entries(for: logDateForSelectedDay),
                            weightMetric: weightUnitRaw == "kg",
                            onLog: { entry in
                                foodStore.addEntry(entry)
                            }
                        )
                    }
                case .editFood:
                    if let editingEntry {
                        EditFoodEntryView(entry: editingEntry)
                    }
                case .importSharedMeal:
                    ImportSharedMealView(meals: pendingSharedMeals) { meals in
                        let logDate = logDateForSelectedDay
                        for meal in meals {
                            foodStore.addEntry(meal.duplicatedForLogging(at: logDate, mealType: meal.mealType))
                        }
                        activeSheet = nil
                    } onCancel: {
                        activeSheet = nil
                    }
                }
            }
            .sheet(item: $savedMealsMode, content: { mode in
                RecentsView(mode: mode, logDate: logDateForSelectedDay, onReview: { entry in
                    currentImages = entry.allImageData.compactMap(UIImage.init(data:))
                    currentImage = currentImages.first
                    currentEmoji = entry.emoji
                    currentFoodSource = entry.source
                    currentFoodResult = GeminiService.FoodAnalysis(
                        name: entry.name,
                        calories: entry.calories,
                        protein: entry.protein,
                        carbs: entry.carbs,
                        fat: entry.fat,
                        servingSizeGrams: entry.servingSizeGrams ?? 100,
                        emoji: entry.emoji,
                        sugar: entry.sugar,
                        addedSugar: entry.addedSugar,
                        fiber: entry.fiber,
                        saturatedFat: entry.saturatedFat,
                        monounsaturatedFat: entry.monounsaturatedFat,
                        polyunsaturatedFat: entry.polyunsaturatedFat,
                        cholesterol: entry.cholesterol,
                        sodium: entry.sodium,
                        potassium: entry.potassium,
                        transFat: entry.transFat,
                        calcium: entry.calcium,
                        iron: entry.iron,
                        magnesium: entry.magnesium,
                        zinc: entry.zinc,
                        vitaminA: entry.vitaminA,
                        vitaminC: entry.vitaminC,
                        vitaminD: entry.vitaminD,
                        vitaminB12: entry.vitaminB12,
                        vitaminE: entry.vitaminE,
                        vitaminK: entry.vitaminK,
                        folate: entry.folate,
                        omega3: entry.omega3,
                        servingUnitOptions: entry.servingUnitOptions,
                        selectedServingUnit: entry.selectedServingUnit,
                        selectedServingQuantity: entry.selectedServingQuantity
                    )
                    activeSheet = .foodResult
                })
            })
            .sheet(isPresented: $showCopyFromDaySheet) {
                CopyFromDaySheet(targetDate: selectedDate)
            }
            .sheet(isPresented: $showSiriPhrases) {
                NavigationStack {
                    SiriPhrasesSettingsView()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showSiriPhrases = false
                                }
                            }
                        }
                }
            }
            .interactiveDismissDisabled(activeSheet == .analyzing || activeSheet == .analyzingText || activeSheet == .lookingUpBarcode)
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images)
            .onChange(of: selectedPhotoItems) { oldValue, newValue in
                guard !newValue.isEmpty else { return }
                selectedPhotoItems = []
                Task {
                    var imported: [UIImage] = []
                    for item in newValue.prefix(10 - captureImages.count) {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            imported.append(image)
                        }
                    }
                    if !imported.isEmpty {
                        captureImages = Array((captureImages + imported).prefix(10))
                        currentImage = captureImages.first
                        currentImages = captureImages
                        currentEmoji = nil
                        currentFoodSource = .snapFood
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showMultiPhotoCaptureSheet = true
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("Retry") { retryLastRequest() }
                Button("Cancel", role: .cancel) { retryRequest = nil }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showNutritionDetail) {
                NutritionDetailView(date: selectedDate, homeTopNutrientsRaw: $homeTopNutrientsRaw)
            }
            .sheet(isPresented: $showCustomWaterLog) {
                WaterCustomAmountSheet(unit: waterUnit, onAdd: logWater)
            }
            .onOpenURL { url in
                if url.scheme == "fudai", url.host == "import-share-image" {
                    checkAndConsumeSharedImage()
                } else if MealShare.handles(url) {
                    // Shared meal — custom scheme or https Universal Link (issue #107).
                    // Universal Links open the app directly (no browser). Confirm before adding.
                    guard let meals = MealShare.meals(from: url) else { return }
                    activeSheet = nil
                    pendingSharedMeals = meals
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeSheet = .importSharedMeal
                    }
                }
            }
            .onAppear {
                checkAndConsumeSharedImage()
                prewarmFoodDestinations()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkAndConsumeSharedImage()
                    // Returned to the foreground -> replay the fill-from-zero reveal.
                    // Gated on wasBackgrounded so transient .inactive blips (control
                    // center, app switcher) don't retrigger it.
                    if wasBackgrounded {
                        launchFillEpoch += 1
                        wasBackgrounded = false
                    }
                } else if newPhase == .background {
                    wasBackgrounded = true
                }
            }
        }
    }
    
    private func checkAndConsumeSharedImage() {
        guard let image = ShareImportManager.consumeSharedImage() else { return }
        
        // Force dismiss any currently open sheets to prevent SwiftUI from swallowing the new presentation
        activeSheet = nil
        
        currentImage = image
        currentImages = [image]
        currentEmoji = nil
        currentFoodSource = .snapFood

        // A slight delay ensures the view hierarchy is clear before presenting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pendingContextImage = image
            contextDescription = ""
            showContextSheet = true
        }
    }

    private func startAnalysis(image: UIImage, mode: CameraMode, description: String? = nil) {
        startAnalysis(images: [image], mode: mode, description: description)
    }

    private func startAnalysis(images: [UIImage], mode: CameraMode, description: String? = nil) {
        retryRequest = .analysis(images: images, mode: mode, description: description)
        activeSheet = .analyzing

        Task {
            do {
                switch mode {
                case .snapFood:
                    let result = try await GeminiService.analyzeFood(images: images)
                    currentFoodResult = result
                    currentFoodSource = .snapFood
                    retryRequest = nil
                    activeSheet = .foodResult

                case .snapFoodWithContext:
                    let result = try await GeminiService.analyzeFood(images: images, description: description)
                    currentFoodResult = result
                    currentFoodSource = .snapFood
                    retryRequest = nil
                    activeSheet = .foodResult

                }
            } catch {
                activeSheet = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startBarcodeLookup(_ barcode: String) {
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBarcode.isEmpty else { return }
        retryRequest = .barcode(trimmedBarcode)

        currentImage = nil
        currentImages = []
        currentEmoji = nil
        currentFoodSource = .barcode
        activeSheet = .lookingUpBarcode

        Task {
            do {
                let result = try await OpenFoodFactsService.lookup(barcode: trimmedBarcode)
                currentFoodResult = result
                currentEmoji = result.emoji
                retryRequest = nil
                activeSheet = .foodResult
            } catch {
                activeSheet = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startTextAnalysis(_ description: String) {
        retryRequest = .text(description)
        activeSheet = .analyzingText
        Task {
            do {
                let result = try await GeminiService.analyzeTextInput(description: description)
                currentFoodResult = result
                currentEmoji = result.emoji
                retryRequest = nil
                activeSheet = .foodResult
            } catch {
                activeSheet = nil
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func retryLastRequest() {
        guard let retryRequest else { return }
        switch retryRequest {
        case let .analysis(images, mode, description):
            startAnalysis(images: images, mode: mode, description: description)
        case let .text(description):
            startTextAnalysis(description)
        case let .barcode(barcode):
            startBarcodeLookup(barcode)
        }
    }

}

// MARK: - Siri Phrases
private struct SiriPhrasesSettingsView: View {
    private let groups: [SiriPhraseGroup] = [
        SiriPhraseGroup(
            title: "Log Food",
            icon: "fork.knife",
            phrases: [
                "Log food in Fud AI",
                "Add food in Fud AI",
                "Track food in Fud AI",
            ]
        ),
        SiriPhraseGroup(
            title: "Today's Calories",
            icon: "chart.bar.fill",
            phrases: [
                "Calories today in Fud AI",
                "How many calories in Fud AI",
                "Today's nutrition in Fud AI",
            ]
        ),
        SiriPhraseGroup(
            title: "Log Weight",
            icon: "scalemass.fill",
            phrases: [
                "Log my weight in Fud AI",
                "Record weight in Fud AI",
            ]
        ),
    ]

    var body: some View {
        List {
            Section {
                Label {
                    Text("Say these phrases to Siri to use Fud AI hands-free.")
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundStyle(AppColors.calorie)
                }
            }
            .listRowBackground(AppColors.appCard)

            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.phrases, id: \.self) { phrase in
                        Text("Hey Siri, \(phrase)")
                            .foregroundStyle(.primary)
                    }
                }
                .listRowBackground(AppColors.appCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.appBackground)
        .navigationTitle("Siri Phrases")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SiriPhraseGroup: Identifiable {
    let title: String
    let icon: String
    let phrases: [String]

    var id: String { title }
}

// MARK: - Copy From Day
private struct CopyFromDaySheet: View {
    let targetDate: Date

    @Environment(FoodStore.self) private var foodStore
    @Environment(\.dismiss) private var dismiss
    @State private var sourceDate: Date

    init(targetDate: Date) {
        self.targetDate = targetDate
        let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: targetDate) ?? targetDate
        _sourceDate = State(initialValue: previousDay)
    }

    private var mealGroups: [FoodLogMealGroup] {
        foodStore.entriesByMeal(for: sourceDate)
    }

    private var sourceEntries: [FoodEntry] {
        mealGroups.flatMap(\.entries)
    }

    private var targetDateText: String {
        if Calendar.current.isDateInToday(targetDate) {
            return "today"
        }
        return targetDate.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Copy From", selection: $sourceDate, displayedComponents: .date)
                        .tint(AppColors.calorie)
                } footer: {
                    Text("Foods will be copied to \(targetDateText). The original entries stay unchanged.")
                }
                .listRowBackground(AppColors.appCard)

                if sourceEntries.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundStyle(AppColors.calorie.opacity(0.45))
                            Text("No foods logged on this day")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                    .listRowBackground(AppColors.appCard)
                } else {
                    Section {
                        Button {
                            copy(sourceEntries)
                        } label: {
                            Label("Copy All Foods", systemImage: "plus.circle.fill")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .tint(AppColors.calorie)
                    } footer: {
                        Text("\(sourceEntries.count) food\(sourceEntries.count == 1 ? "" : "s") will be added to \(targetDateText).")
                    }
                    .listRowBackground(AppColors.appCard)

                    ForEach(mealGroups) { group in
                        Section {
                            Button {
                                copy(group.entries)
                            } label: {
                                Label("Copy \(group.meal.displayName)", systemImage: "plus.circle")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .tint(AppColors.calorie)

                            ForEach(group.entries) { entry in
                                Button {
                                    copy([entry])
                                } label: {
                                    FoodRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label(group.meal.displayName, systemImage: group.meal.icon)
                        }
                        .listRowBackground(AppColors.appCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationTitle("Copy from Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func copy(_ entries: [FoodEntry]) {
        guard !entries.isEmpty else { return }
        let copiedTimestamp = timestamp(on: targetDate, usingTimeFrom: .now)
        for entry in entries {
            let copiedEntry = entry.duplicatedForLogging(at: copiedTimestamp)
            foodStore.addEntry(copiedEntry)
        }
        dismiss()
    }

    private func timestamp(on day: Date, usingTimeFrom timeSource: Date) -> Date {
        let calendar = Calendar.current
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: timeSource)
        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond
        return calendar.date(from: components) ?? day
    }
}

// MARK: - Open Food Facts Barcode Lookup
private enum OpenFoodFactsService {
    enum LookupError: LocalizedError {
        case invalidBarcode
        case productNotFound
        case missingNutrition
        case invalidResponse
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                return "That barcode could not be read. Try scanning it again."
            case .productNotFound:
                return "Product not found in Open Food Facts. Scan the nutrition label instead."
            case .missingNutrition:
                return "This barcode was found, but nutrition data is incomplete. Scan the nutrition label instead."
            case .invalidResponse:
                return "Open Food Facts returned an unexpected response."
            case .networkError(let error):
                return "Barcode lookup failed: \(error.localizedDescription)"
            }
        }
    }

    static func lookup(barcode: String) async throws -> GeminiService.FoodAnalysis {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty,
              let encodedCode = code.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              var components = URLComponents(string: "https://world.openfoodfacts.org/api/v2/product/\(encodedCode).json")
        else {
            throw LookupError.invalidBarcode
        }

        components.queryItems = [
            URLQueryItem(
                name: "fields",
                value: "product_name,generic_name,brands,quantity,serving_size,serving_quantity,nutriments"
            )
        ]

        guard let url = components.url else { throw LookupError.invalidBarcode }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw LookupError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            guard decoded.status != 0, let product = decoded.product else {
                throw LookupError.productNotFound
            }

            return try analysis(from: product, barcode: code)
        } catch let error as LookupError {
            throw error
        } catch {
            throw LookupError.networkError(error)
        }
    }

    private static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "FudAI/\(version) (https://fud-ai.app)"
    }

    private static func analysis(from product: OpenFoodFactsProduct, barcode: String) throws -> GeminiService.FoodAnalysis {
        guard let nutriments = product.nutriments else { throw LookupError.missingNutrition }

        let servingGrams = max(
            product.servingQuantity?.value ?? grams(from: product.servingSize) ?? 100,
            1
        )
        let scale = servingGrams / 100

        let calories = servingValue("energy-kcal", in: nutriments, scale: scale)
            ?? servingValue("energy", in: nutriments, scale: scale).map { $0 * 0.23900573614 }
        let protein = servingValue("proteins", in: nutriments, scale: scale)
        let carbs = servingValue("carbohydrates", in: nutriments, scale: scale)
        let fat = servingValue("fat", in: nutriments, scale: scale)

        guard calories != nil || protein != nil || carbs != nil || fat != nil else {
            throw LookupError.missingNutrition
        }

        let name = productName(from: product, barcode: barcode)
        let servingOption = ServingUnitOption(unit: "serving", gramsPerUnit: servingGrams, quantity: 1)

        return GeminiService.FoodAnalysis(
            name: name,
            calories: Int(round(calories ?? 0)),
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0,
            servingSizeGrams: servingGrams,
            emoji: "🏷️",
            sugar: rounded(servingValue("sugars", in: nutriments, scale: scale)),
            addedSugar: rounded(servingValue("added-sugars", in: nutriments, scale: scale)),
            fiber: rounded(servingValue("fiber", in: nutriments, scale: scale)),
            saturatedFat: rounded(servingValue("saturated-fat", in: nutriments, scale: scale)),
            monounsaturatedFat: rounded(servingValue("monounsaturated-fat", in: nutriments, scale: scale)),
            polyunsaturatedFat: rounded(servingValue("polyunsaturated-fat", in: nutriments, scale: scale)),
            cholesterol: milligrams(servingValue("cholesterol", in: nutriments, scale: scale)),
            sodium: milligrams(servingValue("sodium", in: nutriments, scale: scale)),
            potassium: milligrams(servingValue("potassium", in: nutriments, scale: scale)),
            transFat: rounded(servingValue("trans-fat", in: nutriments, scale: scale)),
            calcium: milligrams(servingValue("calcium", in: nutriments, scale: scale)),
            iron: milligrams(servingValue("iron", in: nutriments, scale: scale)),
            magnesium: milligrams(servingValue("magnesium", in: nutriments, scale: scale)),
            zinc: milligrams(servingValue("zinc", in: nutriments, scale: scale)),
            vitaminA: micrograms(servingValue("vitamin-a", in: nutriments, scale: scale)),
            vitaminC: milligrams(servingValue("vitamin-c", in: nutriments, scale: scale)),
            vitaminD: micrograms(servingValue("vitamin-d", in: nutriments, scale: scale)),
            vitaminB12: micrograms(servingValue("vitamin-b12", in: nutriments, scale: scale)),
            vitaminE: milligrams(servingValue("vitamin-e", in: nutriments, scale: scale)),
            vitaminK: micrograms(servingValue("vitamin-k", in: nutriments, scale: scale)),
            folate: micrograms(servingValue("folates", in: nutriments, scale: scale)),
            omega3: rounded(servingValue("omega-3-fat", in: nutriments, scale: scale)),
            servingUnitOptions: [servingOption],
            selectedServingUnit: servingOption.unit,
            selectedServingQuantity: 1
        )
    }

    private static func servingValue(_ key: String, in nutriments: OpenFoodFactsNutriments, scale: Double) -> Double? {
        if let serving = nutriments.value(for: "\(key)_serving") {
            return serving
        }
        if let per100g = nutriments.value(for: "\(key)_100g") {
            return per100g * scale
        }
        return nil
    }

    private static func productName(from product: OpenFoodFactsProduct, barcode: String) -> String {
        let primary = firstNonEmpty(product.productName, product.genericName)
        let brand = product.brands?
            .split(separator: ",")
            .first
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        if let primary, let brand, !primary.localizedCaseInsensitiveContains(brand) {
            return "\(brand) \(primary)"
        }
        return primary ?? brand ?? "Barcode \(barcode)"
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private static func rounded(_ value: Double?) -> Double? {
        value.map { round($0 * 10) / 10 }
    }

    private static func milligrams(_ grams: Double?) -> Double? {
        grams.map { round($0 * 1000 * 10) / 10 }
    }

    private static func micrograms(_ grams: Double?) -> Double? {
        grams.map { round($0 * 1_000_000 * 10) / 10 }
    }

    private static func grams(from servingSize: String?) -> Double? {
        guard var text = servingSize?.lowercased() else { return nil }
        text = text.replacingOccurrences(of: ",", with: ".")
        text = text.replacingOccurrences(of: "fl. oz", with: "fl oz")

        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*(fl oz|kg|mg|g|oz|ml|l)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange])
        else {
            return nil
        }

        switch String(text[unitRange]) {
        case "kg": return value * 1000
        case "mg": return value / 1000
        case "oz": return value * 28.3495
        case "fl oz": return value * 29.5735
        case "ml": return value
        case "l": return value * 1000
        default: return value
        }
    }

    private struct OpenFoodFactsResponse: Decodable {
        let status: Int?
        let product: OpenFoodFactsProduct?
    }

    private struct OpenFoodFactsProduct: Decodable {
        let productName: String?
        let genericName: String?
        let brands: String?
        let servingSize: String?
        let servingQuantity: FlexibleDouble?
        let nutriments: OpenFoodFactsNutriments?

        private enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case genericName = "generic_name"
            case brands
            case servingSize = "serving_size"
            case servingQuantity = "serving_quantity"
            case nutriments
        }
    }

    private struct OpenFoodFactsNutriments: Decodable {
        private let values: [String: Double]

        func value(for key: String) -> Double? {
            values[key]
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            var parsed: [String: Double] = [:]

            for key in container.allKeys {
                if let value = try? container.decode(FlexibleDouble.self, forKey: key) {
                    parsed[key.stringValue] = value.value
                }
            }

            values = parsed
        }
    }

    private struct FlexibleDouble: Decodable {
        let value: Double

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let double = try? container.decode(Double.self) {
                value = double
            } else if let int = try? container.decode(Int.self) {
                value = Double(int)
            } else {
                let string = try container.decode(String.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ",", with: ".")
                guard let parsed = Double(string) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a number")
                }
                value = parsed
            }
        }
    }

    private struct DynamicCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
}


// MARK: - Nutrition Detail View
struct NutritionDetailView: View {
    let date: Date
    @Binding var homeTopNutrientsRaw: String
    @Environment(FoodStore.self) private var foodStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(OptionalNutrientGoals.storageKey) private var optionalNutrientGoalsData = Data()
    @State private var showHomeNutrientPicker = false

    private var userProfile: UserProfile { profileStore.profile }
    private var optionalNutrientGoals: OptionalNutrientGoals { OptionalNutrientGoals.decoded(from: optionalNutrientGoalsData) }
    private var homeTopNutrients: [HomeTopNutrient] { HomeTopNutrient.selection(from: homeTopNutrientsRaw) }
    private var homeTopNutrientNames: String {
        homeTopNutrients
            .map(\.displayName)
            .joined(separator: ", ")
    }

    var body: some View {
        let _ = profileStore.profile
        return NavigationStack {
            List {
                Section {
                    Button {
                        showHomeNutrientPicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Label("Home Nutrient Cards", systemImage: "square.grid.3x1.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(homeTopNutrientNames)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.appCard)

                Section("Macros") {
                    NutritionDetailRow(icon: "flame.fill", label: "Calories", value: "\(foodStore.calories(for: date))", unit: "kcal", goal: "\(userProfile.effectiveCalories)")
                    NutritionDetailRow(icon: "p.circle.fill", label: "Protein", value: MacroValueFormatter.string(foodStore.protein(for: date)), unit: "g", goal: "\(userProfile.effectiveProtein)")
                    NutritionDetailRow(icon: "c.circle.fill", label: "Carbs", value: MacroValueFormatter.string(foodStore.carbs(for: date)), unit: "g", goal: "\(userProfile.effectiveCarbs)")
                    NutritionDetailRow(icon: "f.circle.fill", label: "Fat", value: MacroValueFormatter.string(foodStore.fat(for: date)), unit: "g", goal: "\(userProfile.effectiveFat)")
                }
                .listRowBackground(AppColors.appCard)

                Section("Detailed Nutrition") {
                    optionalNutritionRow(.sugar, value: foodStore.sugar(for: date))
                    optionalNutritionRow(.addedSugar, value: foodStore.addedSugar(for: date))
                    optionalNutritionRow(.fiber, value: foodStore.fiber(for: date))
                    optionalNutritionRow(.saturatedFat, value: foodStore.saturatedFat(for: date))
                    NutritionDetailRow(icon: "drop", label: "Mono Unsat. Fat", value: formatMicro(foodStore.monounsaturatedFat(for: date)), unit: "g")
                    NutritionDetailRow(icon: "drop.halffull", label: "Poly Unsat. Fat", value: formatMicro(foodStore.polyunsaturatedFat(for: date)), unit: "g")
                    optionalNutritionRow(.cholesterol, value: foodStore.cholesterol(for: date))
                    optionalNutritionRow(.sodium, value: foodStore.sodium(for: date))
                    optionalNutritionRow(.potassium, value: foodStore.potassium(for: date))
                    optionalNutritionRow(.transFat, value: foodStore.transFat(for: date))
                    optionalNutritionRow(.calcium, value: foodStore.calcium(for: date))
                    optionalNutritionRow(.iron, value: foodStore.iron(for: date))
                    optionalNutritionRow(.magnesium, value: foodStore.magnesium(for: date))
                    optionalNutritionRow(.zinc, value: foodStore.zinc(for: date))
                    optionalNutritionRow(.vitaminA, value: foodStore.vitaminA(for: date))
                    optionalNutritionRow(.vitaminC, value: foodStore.vitaminC(for: date))
                    optionalNutritionRow(.vitaminD, value: foodStore.vitaminD(for: date))
                    optionalNutritionRow(.vitaminB12, value: foodStore.vitaminB12(for: date))
                    optionalNutritionRow(.vitaminE, value: foodStore.vitaminE(for: date))
                    optionalNutritionRow(.vitaminK, value: foodStore.vitaminK(for: date))
                    optionalNutritionRow(.folate, value: foodStore.folate(for: date))
                    optionalNutritionRow(.omega3, value: foodStore.omega3(for: date))
                }
                .listRowBackground(AppColors.appCard)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationTitle("Nutrition Details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showHomeNutrientPicker) {
                HomeNutrientPickerSheet(selectionRawValue: $homeTopNutrientsRaw)
            }
            .onChange(of: homeTopNutrientsRaw) { _, _ in
                refreshWidgetSnapshot()
            }
            .onChange(of: optionalNutrientGoalsData) { _, _ in
                refreshWidgetSnapshot()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(AppColors.calorie)
                }
            }
        }
    }

    private func refreshWidgetSnapshot() {
        WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: userProfile)
    }

    private func formatMicro(_ value: Double) -> String {
        value == 0 ? "—" : String(format: "%.1f", value)
    }

    private func optionalNutritionRow(_ nutrient: OptionalNutrient, value: Double) -> some View {
        NutritionDetailRow(
            icon: nutrient.iconName,
            label: nutrient.displayName,
            value: formatMicro(value),
            unit: nutrient.unit,
            goal: "\(optionalNutrientGoals.goal(for: nutrient))"
        )
    }
}

struct NutritionDetailRow: View {
    var icon: String? = nil
    let label: String
    let value: String
    let unit: String
    var goal: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: AppColors.calorieGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 24)
            }
            Text(LocalizedDisplayText.text(label))
                .font(.system(.body, design: .rounded))
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppColors.calorie)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let goal {
                Text("/ \(goal)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct NativeSheetToolbarButton: View {
    let title: LocalizedStringKey
    var isEmphasized = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.glass)
        } else {
            button
        }
    }

    private var button: some View {
        Button(action: action) {
            Text(title)
                .fixedSize()
                .foregroundStyle(AppColors.calorie)
        }
        .fontWeight(isEmphasized ? .semibold : .regular)
        .disabled(isDisabled)
    }
}

// MARK: - Multi-photo Capture Review
struct MultiPhotoCaptureSheet: View {
    @Binding var images: [UIImage]
    let isImportingPhotos: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    @Binding var description: String
    let onAddPhoto: () -> Void
    let onRemove: (Int) -> Void
    let onAnalyze: () -> Void
    let onCancel: () -> Void
    @State private var showAdditionalPhotoPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(images.count) of 10 photos")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 240, height: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            onRemove(index)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 30, height: 30)
                                                .background(.black.opacity(0.6), in: Circle())
                                        }
                                        .padding(10)
                                    }
                                    .overlay(alignment: .bottomLeading) {
                                        Text("Photo \(index + 1)")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.black.opacity(0.55), in: Capsule())
                                            .padding(10)
                                    }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)

                    if images.count < 10 {
                        HStack {
                            Spacer()
                            Button {
                                if isImportingPhotos {
                                    showAdditionalPhotoPicker = true
                                } else {
                                    onAddPhoto()
                                }
                            } label: {
                                Label(
                                    isImportingPhotos ? "Add Photos" : "Add Photo",
                                    systemImage: isImportingPhotos ? "photo.on.rectangle" : "camera.fill"
                                )
                            }
                            .buttonStyle(.bordered)
                            .tint(AppColors.calorie)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a note (optional)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField(
                            "e.g. chicken is 180g, rice is 220g, use half the sauce",
                            text: $description,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Meal Photos")
            .navigationBarTitleDisplayMode(.inline)
            .photosPicker(
                isPresented: $showAdditionalPhotoPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: max(1, 10 - images.count),
                matching: .images
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NativeSheetToolbarButton(title: "Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NativeSheetToolbarButton(
                        title: "Analyze",
                        isEmphasized: true,
                        isDisabled: images.isEmpty,
                        action: onAnalyze
                    )
                }
            }
        }
    }
}

// MARK: - Context Description Sheet
struct ContextDescriptionSheet: View {
    let image: UIImage?
    @Binding var description: String
    let onAnalyze: () -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(AppColors.calorie.opacity(0.15), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add context (optional)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ZStack(alignment: .topLeading) {
                            if description.isEmpty {
                                Text("e.g. \"This is a half portion\" or \"Cooked in olive oil\"")
                                    .foregroundStyle(.tertiary)
                                    .font(.body)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 10)
                                    .allowsHitTesting(false)
                            }
                            TextField("", text: $description, axis: .vertical)
                                .font(.body)
                                .lineLimit(3...6)
                                .textFieldStyle(.plain)
                                .focused($isFocused)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 10)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }

                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Description")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NativeSheetToolbarButton(title: "Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NativeSheetToolbarButton(
                        title: "Analyze",
                        isEmphasized: true,
                        action: onAnalyze
                    )
                }
            }
            .onAppear { isFocused = true }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Camera View (UIKit wrapper)
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let title: String?
    let onCancel: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(image: Binding<UIImage?>, title: String? = nil, onCancel: (() -> Void)? = nil) {
        _image = image
        self.title = title
        self.onCancel = onCancel
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        picker.edgesForExtendedLayout = .all
        picker.showsCameraControls = false

        // Keep the complete 4:3 camera frame visible so the preview matches the
        // original image delivered after capture. Tall screens intentionally
        // letterbox instead of enlarging and cropping the preview.
        let screenSize = UIScreen.main.bounds.size
        let previewHeight = screenSize.width * 4.0 / 3.0
        let bottomBarHeight: CGFloat = 140
        let availablePreviewHeight = max(0, screenSize.height - bottomBarHeight)
        let previewOffset = max(0, (availablePreviewHeight - previewHeight) / 2)
        picker.cameraViewTransform = CGAffineTransform(translationX: 0, y: previewOffset)

        // Custom overlay with shutter + cancel buttons
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.isUserInteractionEnabled = true
        overlay.backgroundColor = .clear

        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(bottomBar)

        let shutterOuter = UIView()
        shutterOuter.backgroundColor = .white
        shutterOuter.layer.cornerRadius = 37
        shutterOuter.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(shutterOuter)

        let shutterInner = UIView()
        shutterInner.backgroundColor = .white
        shutterInner.layer.cornerRadius = 32
        shutterInner.layer.borderWidth = 2
        shutterInner.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        shutterInner.translatesAutoresizingMaskIntoConstraints = false
        shutterOuter.addSubview(shutterInner)

        let shutterButton = UIButton(type: .system)
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.addTarget(context.coordinator, action: #selector(Coordinator.capture), for: .touchUpInside)
        shutterOuter.addSubview(shutterButton)

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(context.coordinator, action: #selector(Coordinator.cancel), for: .touchUpInside)
        bottomBar.addSubview(cancelButton)

        var titleLabel: UILabel?
        if let title {
            let label = UILabel()
            label.text = title
            label.textColor = .white
            label.font = .systemFont(ofSize: 17, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            bottomBar.addSubview(label)
            titleLabel = label
        }

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: bottomBarHeight),

            shutterOuter.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            shutterOuter.centerYAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 50),
            shutterOuter.widthAnchor.constraint(equalToConstant: 74),
            shutterOuter.heightAnchor.constraint(equalToConstant: 74),

            shutterInner.centerXAnchor.constraint(equalTo: shutterOuter.centerXAnchor),
            shutterInner.centerYAnchor.constraint(equalTo: shutterOuter.centerYAnchor),
            shutterInner.widthAnchor.constraint(equalToConstant: 64),
            shutterInner.heightAnchor.constraint(equalToConstant: 64),

            shutterButton.leadingAnchor.constraint(equalTo: shutterOuter.leadingAnchor),
            shutterButton.trailingAnchor.constraint(equalTo: shutterOuter.trailingAnchor),
            shutterButton.topAnchor.constraint(equalTo: shutterOuter.topAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: shutterOuter.bottomAnchor),

            cancelButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: shutterOuter.centerYAnchor),
        ])
        if let titleLabel {
            NSLayoutConstraint.activate([
                titleLabel.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
                titleLabel.topAnchor.constraint(equalTo: shutterOuter.bottomAnchor, constant: 14),
            ])
        }

        picker.cameraOverlayView = overlay
        context.coordinator.picker = picker

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        weak var picker: UIImagePickerController?

        init(_ parent: CameraView) {
            self.parent = parent
        }

        @objc func capture() {
            picker?.takePicture()
        }

        @objc func cancel() {
            parent.onCancel?()
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel?()
            parent.dismiss()
        }
    }
}

// MARK: - Barcode Scanner
struct BarcodeScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        BarcodeScannerViewController(onScan: onScan, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

final class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onScan: (String) -> Void
    private let onCancel: () -> Void
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    init(onScan: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.onScan = onScan
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        buildOverlay()
        checkCameraAccess()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
    }

    private func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureSession()
                    } else {
                        self?.showCameraUnavailable("Camera access is needed to scan barcodes.")
                    }
                }
            }
        case .denied, .restricted:
            showCameraUnavailable("Camera access is needed to scan barcodes.")
        @unknown default:
            showCameraUnavailable("Camera is unavailable.")
        }
    }

    private func configureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            showCameraUnavailable("Camera is unavailable.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            showCameraUnavailable("Barcode scanning is unavailable.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)

        let supportedTypes: [AVMetadataObject.ObjectType] = [
            .ean13,
            .ean8,
            .upce,
            .code128,
            .code39,
            .code93,
            .itf14,
            .interleaved2of5
        ]
        let availableTypes = supportedTypes.filter { output.availableMetadataObjectTypes.contains($0) }
        guard !availableTypes.isEmpty else {
            session.commitConfiguration()
            showCameraUnavailable("Barcode scanning is unavailable.")
            return
        }
        output.metadataObjectTypes = availableTypes
        session.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        self.session = session
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func buildOverlay() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        let scanBox = UIView()
        scanBox.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        scanBox.layer.borderWidth = 3
        scanBox.layer.cornerRadius = 22
        scanBox.backgroundColor = UIColor.clear
        scanBox.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanBox)

        let label = UILabel()
        label.text = "Point the camera at the barcode"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let hint = UILabel()
        hint.text = "If the product is not found, scan the nutrition label instead."
        hint.textColor = UIColor.white.withAlphaComponent(0.72)
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.textAlignment = .center
        hint.numberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scanBox.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -34),
            scanBox.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.76),
            scanBox.heightAnchor.constraint(equalToConstant: 190),

            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            label.topAnchor.constraint(equalTo: scanBox.bottomAnchor, constant: 28),

            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            hint.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10)
        ])
    }

    private func showCameraUnavailable(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    @objc private func cancelTapped() {
        onCancel()
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = object.stringValue,
              !code.isEmpty else { return }

        didScan = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session?.stopRunning()
        }
        onScan(code)
    }
}

// MARK: - Food Row
struct FoodRow: View {
    let entry: FoodEntry
    @Environment(FoodStore.self) private var foodStore

    private var servingText: String? {
        guard let grams = entry.servingSizeGrams else { return nil }
        let formatted = grams == grams.rounded() ? "\(Int(grams))" : String(format: "%.1f", grams)
        if let selectedUnit = entry.selectedServingUnit,
           let quantity = entry.selectedServingQuantity,
           quantity > 0 {
            let option = ServingUnitOption.option(matching: selectedUnit, in: entry.servingUnitOptions)
            if !option.isGramUnit {
                let quantityText = ServingUnitEditor.formatQuantity(quantity)
                return "\(quantityText) \(option.displayUnit(for: quantity)) (~\(formatted)g)"
            }
        }
        return "\(formatted)g"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColors.calorie.opacity(0.15), lineWidth: 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if !entry.additionalImageData.isEmpty {
                            Text("+\(entry.additionalImageData.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.65), in: Capsule())
                                .padding(4)
                        }
                    }
            } else if let emoji = entry.emoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(AppColors.calorie)
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    HStack(spacing: 4) {
                        Text(entry.name)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .fixedSize(horizontal: false, vertical: true)
                        if foodStore.isFavorite(entry) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    Spacer()
                    Text(entry.timeString)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 6) {
                    Text("\(entry.calories) kcal")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppColors.calorie)

                    if let serving = servingText {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(serving)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    MacroPill(label: "P", value: entry.protein)
                    MacroPill(label: "C", value: entry.carbs)
                    MacroPill(label: "F", value: entry.fat)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacroPill: View {
    let label: String
    let value: Double

    var body: some View {
        Text("\(label) \(MacroValueFormatter.withUnit(value))")
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.calorie.opacity(0.08), in: Capsule())
    }
}

// MARK: - Progress Tab
struct ProgressTabView: View {
    @Environment(FoodStore.self) private var foodStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(BodyFatStore.self) private var bodyFatStore
    @Environment(ProfileStore.self) private var profileStore
    @Environment(StrengthWorkoutStore.self) private var strengthWorkoutStore
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @State private var timeRange: TimeRange = .week
    @State private var showLogWeight = false
    @State private var showLogBodyFat = false
    @State private var showGoalReached = false
    @State private var showAllWeights = false
    @State private var showAllBodyFat = false
    @State private var showWorkoutHistory = false

    private var userProfile: UserProfile { profileStore.profile }

    private var dateRange: ClosedRange<Date> { timeRange.dateRange() }

    private var filteredWeightEntries: [WeightEntry] {
        weightStore.entries(in: dateRange)
    }

    private var filteredBodyFatEntries: [BodyFatEntry] {
        bodyFatStore.entries(in: dateRange)
    }

    private var workoutCalorieSessions: [StrengthWorkoutSession] {
        strengthWorkoutStore.completedSessions.filter { $0.caloriesBurned != nil }
    }

    /// Show the Body Fat section to anyone who has either logged a reading,
    /// set a current value (legacy users from before BodyFatStore existed —
    /// they won't have any entries yet but we still want to show the tracker
    /// + Log button so they can start), or set a goal. Hidden entirely for
    /// users who skipped the body-fat track in onboarding.
    private var showsBodyFatSection: Bool {
        !bodyFatStore.entries.isEmpty
            || userProfile.bodyFatPercentage != nil
            || userProfile.goalBodyFatPercentage != nil
    }

    private var dailyCalories: [(date: Date, calories: Int)] {
        let calendar = Calendar.current
        let days = timeRange.days
        let today = calendar.startOfDay(for: .now)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let cals = foodStore.calories(for: date)
            if cals == 0 { return nil }
            return (date: date, calories: cals)
        }.reversed()
    }

    private var macroAverages: (protein: Double, carbs: Double, fat: Double) {
        let calendar = Calendar.current
        let days = timeRange.days
        let today = calendar.startOfDay(for: .now)
        var totalP = 0.0, totalC = 0.0, totalF = 0.0
        var count = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayEntries = foodStore.entries(for: date)
            if dayEntries.isEmpty { continue }
            totalP += dayEntries.reduce(0) { $0 + $1.protein }
            totalC += dayEntries.reduce(0) { $0 + $1.carbs }
            totalF += dayEntries.reduce(0) { $0 + $1.fat }
            count += 1
        }
        guard count > 0 else { return (0, 0, 0) }
        return (totalP / Double(count), totalC / Double(count), totalF / Double(count))
    }

    var body: some View {
        let _ = profileStore.profile
        return NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Weight / Body Fat Trend — single card with a segmented
                    // toggle (when the user has opted into body-fat tracking)
                    // or just the bare Weight chart (when they haven't, so the
                    // layout stays identical to v3.1 for those users).
                    BodyMetricsSection(
                        weightEntries: filteredWeightEntries,
                        goalWeightKg: userProfile.goalWeightKg,
                        currentWeightKg: weightStore.latestEntry?.weightKg,
                        onLogWeight: { showLogWeight = true },
                        bodyFatEntries: filteredBodyFatEntries,
                        goalBodyFatFraction: userProfile.goalBodyFatPercentage,
                        currentBodyFatFraction: bodyFatStore.latestEntry?.bodyFatFraction ?? userProfile.bodyFatPercentage,
                        onLogBodyFat: { showLogBodyFat = true },
                        bodyFatAvailable: showsBodyFatSection
                    )
                    .padding(.horizontal)

                    // Weight History — tap to view/delete entries
                    if !weightStore.entries.isEmpty {
                        WeightHistoryLink(
                            totalCount: weightStore.entries.count,
                            onTap: { showAllWeights = true }
                        )
                        .padding(.horizontal)
                    }

                    // Body Fat History — tap to view/delete entries
                    if !bodyFatStore.entries.isEmpty {
                        BodyFatHistoryLink(
                            totalCount: bodyFatStore.entries.count,
                            onTap: { showAllBodyFat = true }
                        )
                        .padding(.horizontal)
                    }

                    // Workout History — calculated burns with exercise/set detail.
                    if !workoutCalorieSessions.isEmpty {
                        WorkoutHistoryLink(
                            sessions: workoutCalorieSessions,
                            onTap: { showWorkoutHistory = true }
                        )
                        .padding(.horizontal)
                    }

                    // Calorie Trend
                    CalorieChartSection(
                        dailyCalories: dailyCalories,
                        calorieGoal: userProfile.effectiveCalories
                    )
                    .padding(.horizontal)

                    // Macro Averages
                    MacroAveragesSection(
                        avgProtein: macroAverages.protein,
                        avgCarbs: macroAverages.carbs,
                        avgFat: macroAverages.fat,
                        proteinGoal: userProfile.effectiveProtein,
                        carbsGoal: userProfile.effectiveCarbs,
                        fatGoal: userProfile.effectiveFat
                    )
                    .padding(.horizontal)

                }
                .padding(.vertical)
            }
            .background(AppColors.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showLogWeight) {
                LogWeightSheet(
                    currentWeightKg: weightStore.latestEntry?.weightKg ?? userProfile.weightKg
                ) { weightKg in
                    weightStore.addEntry(WeightEntry(weightKg: weightKg))
                }
            }
            .sheet(isPresented: $showLogBodyFat) {
                // Seed from latest entry → profile current → sane default,
                // mirroring the LogWeightSheet seeding chain.
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
    }

}


struct ProfileView: View {
    @Environment(ProfileStore.self) private var profileStore
    @Environment(ChatStore.self) private var chatStore
    @Environment(WeightStore.self) private var weightStore
    @Environment(FoodStore.self) private var foodStore
    @Environment(WaterStore.self) private var waterStore
    @Environment(StrengthWorkoutStore.self) private var strengthWorkoutStore
    @Environment(BodyMeasurementStore.self) private var bodyMeasurementStore
    @Environment(NotificationManager.self) private var notificationManager
    @Environment(HealthKitManager.self) private var healthKitManager
    private var profile: UserProfile {
        get { profileStore.profile }
        nonmutating set { profileStore.profile = newValue }
    }
    private var profileBinding: Binding<UserProfile> {
        Binding(get: { profileStore.profile }, set: { profileStore.profile = $0 })
    }
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("heightUnit") private var heightUnitRaw = "ftin"
    @AppStorage("weightUnit") private var weightUnitRaw = "lbs"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("healthKitEnabled") private var healthKitEnabled = false
    @AppStorage(AdaptiveGoalSettings.enabledKey) private var adaptiveGoalsEnabled = false
    @AppStorage(EnergyBurnSettings.enabledKey) private var energyBurnEnabled = false
    @AppStorage("weekStartsOnMonday") private var weekStartsOnMonday = true
    @AppStorage(FoodMeasurementSettings.preferGramsByDefaultKey) private var preferGramsByDefault = false
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue
    @AppStorage(WaterSettings.enabledKey) private var waterTrackingEnabled = false
    @AppStorage(WaterSettings.dailyGoalKey) private var waterDailyGoal = WaterSettings.defaultDailyGoalMl
    @AppStorage(WaterSettings.unitKey) private var waterUnitRaw = WaterUnit.defaultUnit.rawValue

    private var waterUnit: WaterUnit { WaterUnit(rawValue: waterUnitRaw) ?? .defaultUnit }

    // App-update state is owned by ContentView (it also drives the one-shot update
    // notification). It's forwarded here so the About section — now the last section
    // of Settings — can show the update row and the manual re-check.
    @Binding private var updateState: AppUpdateState
    private let refreshUpdateState: () async -> Void

    fileprivate init(updateState: Binding<AppUpdateState>, refreshUpdateState: @escaping () async -> Void) {
        self._updateState = updateState
        self.refreshUpdateState = refreshUpdateState
    }

    enum ActiveSheet: String, Identifiable {
        case editBirthday, editHeight, editWeight, editBodyFat, editGoalBodyFat, editGoalWeight, editCalories, editProtein, editCarbs, editFat
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var showExportDiary = false
    @State private var showDeleteConfirmation = false
    @State private var showClearFoodLogConfirmation = false
    @State private var showCalculationMethods = false
    @State private var showWaterGoalPicker = false
    @State private var showAutoMacroEditAlert = false
    @State private var showMaxPinnedAlert = false
    @State private var showInvalidGoalWeightAlert = false
    @State private var showDefaultGramsInfo = false
    @State private var showAdaptiveGoalsInfo = false
    @State private var showEnergyBurnInfo = false
    @State private var energyBurnToggleReverting = false
    @State private var isRecalculatingGoals = false
    @State private var isApplyingAdaptiveGoals = false
    @State private var showAdaptiveGoalAlert = false
    @State private var adaptiveGoalAlertTitle = ""
    @State private var adaptiveGoalAlertMessage = ""
    @State private var invalidGoalWeightMessage = ""
    @State private var selectedProvider: AIProvider = AIProviderSettings.selectedProvider
    @State private var selectedModel: String = AIProviderSettings.selectedModel
    @State private var apiKeyText: String = AIProviderSettings.apiKey(for: AIProviderSettings.selectedProvider) ?? ""
    @State private var customBaseURL: String = AIProviderSettings.customBaseURL(for: AIProviderSettings.selectedProvider) ?? ""
    @State private var maxResponseTokensText: String = String(AIProviderSettings.maxResponseTokens)
    @State private var requestTimeoutSecondsText: String = String(AIProviderSettings.requestTimeoutSeconds)
    @State private var showAPIKey = false
    @State private var customAIInstructions: String = AIProviderSettings.userContext
    @State private var savedAIInstructions: String = AIProviderSettings.userContext
    @FocusState private var customInstructionsFocused: Bool
    @State private var fallbackEnabled: Bool = AIProviderSettings.fallbackEnabled
    @State private var selectedFallbackProvider: AIProvider = AIProviderSettings.selectedFallbackProvider
    @State private var selectedFallbackModel: String = AIProviderSettings.selectedFallbackModel
    @State private var fallbackApiKeyText: String = AIProviderSettings.apiKey(for: AIProviderSettings.selectedFallbackProvider) ?? ""
    @State private var fallbackBaseURL: String = AIProviderSettings.customBaseURL(for: AIProviderSettings.selectedFallbackProvider) ?? ""
    @State private var showFallbackAPIKey = false
    @State private var selectedSpeechProvider: SpeechProvider = SpeechSettings.selectedProvider
    @State private var selectedSpeechLanguage: SpeechLanguage = SpeechSettings.selectedLanguage(for: SpeechSettings.selectedProvider)
    @State private var speechApiKeyText: String = SpeechSettings.apiKey(for: SpeechSettings.selectedProvider) ?? ""
    @State private var showSpeechAPIKey = false

    private var heightMetric: Bool { heightUnitRaw == "cm" }
    private var weightMetric: Bool { weightUnitRaw == "kg" }

    // Height formatting
    private var heightDisplay: String {
        if heightMetric {
            return "\(Int(profile.heightCm)) cm"
        }
        // Round to the nearest inch — truncating shows 5'6" for a 170 cm / 5'7" pick.
        let totalInches = Int((profile.heightCm / 2.54).rounded())
        let feet = totalInches / 12
        let inches = totalInches % 12
        return "\(feet)'\(inches)\""
    }

    // Weight formatting
    private var weightDisplay: String {
        if weightMetric {
            return String(format: "%.1f kg", profile.weightKg)
        }
        return String(format: "%.1f lbs", profile.weightKg * 2.20462)
    }

    // Birthday formatting
    private var birthdayDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: profile.birthday)) (age \(profile.age))"
    }

    // Goal weight display
    private var goalWeightDisplay: String {
        guard let gw = profile.goalWeightKg else { return "Not set" }
        if weightMetric {
            return String(format: "%.1f kg", gw)
        }
        return String(format: "%.1f lbs", gw * 2.20462)
    }

    /// Glanceable value for the Body Measurements row — the latest waist, or "Not set".
    private var bodyMeasurementsRowValue: String {
        guard let latest = bodyMeasurementStore.latestEntry else { return "Not set" }
        if let waist = latest.waistCm {
            return heightMetric ? String(format: "Waist %.0f cm", waist) : String(format: "Waist %.0f in", waist / 2.54)
        }
        return "Logged"
    }

    // Weekly change display
    private var weeklyChangeDisplay: String {
        let rate = profile.weeklyChangeKg ?? 0.5
        return WeightDisplayFormatter.weeklyChange(kilograms: rate, useMetric: weightMetric)
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: Personal Info
                Section("Personal Info") {
                    Picker(selection: profileBinding.gender) {
                        Text("Male").tag(Gender.male)
                        Text("Female").tag(Gender.female)
                        Text("Other").tag(Gender.other)
                    } label: {
                        Label {
                            Text("Gender")
                        } icon: {
                            Image(systemName: profile.gender.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: profile.gender) { _, _ in saveProfile() }

                    ProfileInfoRow(icon: "birthday.cake", label: "Birthday", value: birthdayDisplay) {
                        activeSheet = .editBirthday
                    }

                    ProfileInfoRow(icon: "ruler", label: "Height", value: heightDisplay) {
                        activeSheet = .editHeight
                    }

                    ProfileInfoRow(icon: "scalemass", label: "Weight", value: weightDisplay) {
                        activeSheet = .editWeight
                    }

                    ProfileInfoRow(
                        icon: "percent",
                        label: "Body Fat",
                        value: profile.bodyFatPercentage != nil ? "\(Int(profile.bodyFatPercentage! * 100))%" : "Not set"
                    ) {
                        activeSheet = .editBodyFat
                    }

                    // Only surface the goal row to users who have a current
                    // body-fat value — feature was scoped to "skippable, no
                    // math impact, only visible if the user opted in to the
                    // body-fat track in onboarding (or set one later here)."
                    if profile.bodyFatPercentage != nil {
                        ProfileInfoRow(
                            icon: "target",
                            label: "Goal Body Fat",
                            value: profile.goalBodyFatPercentage != nil ? "\(Int(profile.goalBodyFatPercentage! * 100))%" : "Not set"
                        ) {
                            activeSheet = .editGoalBodyFat
                        }
                    }

                    // Optional tape-measure circumferences. Extra signal for the AI goal calc +
                    // Coach (waist-to-hip, waist-to-height, Navy body-fat %, frame). Never edits BMR.
                    NavigationLink {
                        BodyMeasurementsDetailView(gender: profile.gender, heightCm: profile.heightCm)
                    } label: {
                        Label {
                            HStack {
                                Text("Body Measurements")
                                Spacer()
                                Text(bodyMeasurementsRowValue)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "ruler")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                }
                .listRowBackground(AppColors.appCard)

                // Section 2: Goals & Nutrition
                Section("Goals & Nutrition") {
                    Picker(selection: profileBinding.goal) {
                        ForEach(WeightGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    } label: {
                        Label {
                            Text("Weight Goal")
                        } icon: {
                            Image(systemName: profile.goal.icon)
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    .onChange(of: profile.goal) { _, newValue in
                        if newValue == .maintain {
                            profile.weeklyChangeKg = nil
                            profile.goalWeightKg = nil
                        } else {
                            if profile.weeklyChangeKg == nil {
                                profile.weeklyChangeKg = 0.5
                            }
                            // Clear goal weight if it no longer matches the new direction
                            // (e.g., switching from Lose to Gain with an old target below current weight).
                            if let gw = profile.goalWeightKg {
                                let losingPastTarget = newValue == WeightGoal.lose && gw >= profile.weightKg
                                let gainingPastTarget = newValue == WeightGoal.gain && gw <= profile.weightKg
                                if losingPastTarget || gainingPastTarget {
                                    profile.goalWeightKg = nil
                                }
                            }
                        }
                        saveProfile()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Picker(selection: profileBinding.activityLevel) {
                            ForEach(ActivityLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        } label: {
                            Label {
                                Text("Activity Level")
                            } icon: {
                                Image(systemName: profile.activityLevel.icon)
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)

                        Text(profile.activityLevel.subtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 34)
                    }
                    .onChange(of: profile.activityLevel) { _, _ in saveProfile() }

                    if profile.goal != .maintain {
                        Picker(selection: Binding(
                            get: { profile.weeklyChangeKg ?? 0.5 },
                            set: { profile.weeklyChangeKg = $0; saveProfile() }
                        )) {
                            Text("Slow (\(WeightDisplayFormatter.weeklyChange(kilograms: 0.25, useMetric: weightMetric, period: "wk")))").tag(0.25)
                            Text("Moderate (\(WeightDisplayFormatter.weeklyChange(kilograms: 0.5, useMetric: weightMetric, period: "wk")))").tag(0.5)
                            Text("Fast (\(WeightDisplayFormatter.weeklyChange(kilograms: 1.0, useMetric: weightMetric, period: "wk")))").tag(1.0)
                        } label: {
                            Label {
                                Text("Weekly Change")
                            } icon: {
                                Image(systemName: "gauge.with.dots.needle.33percent")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)

                        ProfileInfoRow(
                            icon: "flag.checkered",
                            label: "Goal Weight",
                            value: goalWeightDisplay
                        ) {
                            activeSheet = .editGoalWeight
                        }
                    }

                    HStack {
                        Label {
                            Text("Adaptive Goals")
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundStyle(AppColors.calorie)
                        }
                        Spacer()
                        if isApplyingAdaptiveGoals {
                            ProgressView()
                        }
                        Button {
                            showAdaptiveGoalsInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("About Adaptive Goals")

                        Toggle("", isOn: $adaptiveGoalsEnabled)
                            .labelsHidden()
                            .tint(AppColors.calorie)
                            .disabled(isApplyingAdaptiveGoals)
                            .onChange(of: adaptiveGoalsEnabled) { oldValue, enabled in
                                handleAdaptiveGoalsToggle(enabled, wasEnabled: oldValue)
                            }
                    }

                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Energy Burn")
                                if !healthKitEnabled {
                                    Text("Needs Apple Health")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "flame")
                                .foregroundStyle(AppColors.calorie)
                        }
                        Spacer()
                        Button {
                            showEnergyBurnInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("About Energy Burn")

                        Toggle("", isOn: $energyBurnEnabled)
                            .labelsHidden()
                            .tint(AppColors.calorie)
                            .disabled(isRecalculatingGoals)
                            .onChange(of: energyBurnEnabled) { _, enabled in
                                handleEnergyBurnToggle(enabled)
                            }
                    }

                    lockableGoalRow(icon: "flame", label: "Calories", valueText: "\(profile.effectiveCalories) kcal", macro: nil, sheet: .editCalories)

                    lockableGoalRow(icon: "p.circle", label: "Protein", valueText: "\(profile.effectiveProtein)g", macro: .protein, sheet: .editProtein)
                    lockableGoalRow(icon: "c.circle", label: "Carbs", valueText: "\(profile.effectiveCarbs)g", macro: .carbs, sheet: .editCarbs)
                    lockableGoalRow(icon: "f.circle", label: "Fat", valueText: "\(profile.effectiveFat)g", macro: .fat, sheet: .editFat)

                    NavigationLink {
                        OptionalNutrientGoalsSettingsView(profile: profile)
                    } label: {
                        Label {
                            HStack {
                                Text("Other Nutrients")
                                Spacer()
                                Text("Sugar, Fiber, Sodium")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    Button {
                        recalculateGoalsNow()
                    } label: {
                        Label {
                            HStack {
                                Text("Recalculate Goals")
                                Spacer()
                                if isRecalculatingGoals {
                                    ProgressView()
                                } else if goalsNeedRecalc {
                                    // Soft nudge: a goal input changed since the last recalc. A CTA
                                    // on the row's right edge, not a wrapped line below it.
                                    Text("Tap to update")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.calorie)
                                }
                            }
                        } icon: {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                    .disabled(isRecalculatingGoals)

                    Button {
                        showCalculationMethods = true
                    } label: {
                        Label {
                            Text("Calculation Methods")
                        } icon: {
                            Image(systemName: "book")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .tint(.primary)
                }
                .listRowBackground(AppColors.appCard)

                // Section 3: App Settings
                Section("App Settings") {
                    Picker(selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    } label: {
                        Label {
                            Text("Appearance")
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)

                    Picker(selection: $appThemeColorRaw) {
                        ForEach(AppThemeColor.allCases) { themeColor in
                            Label {
                                Text(themeColor.displayName)
                            } icon: {
                                Image(uiImage: themeColor.menuSwatchImage)
                            }
                            .tag(themeColor.rawValue)
                        }
                    } label: {
                        Label {
                            Text("Theme Color")
                        } icon: {
                            Image(systemName: "paintpalette.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)

                    HStack {
                        Label {
                            HStack(spacing: 6) {
                                Text("Default to Grams")
                                Button {
                                    showDefaultGramsInfo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("About Default to Grams")
                            }
                        } icon: {
                            Image(systemName: "scalemass")
                                .foregroundStyle(AppColors.calorie)
                        }
                        Spacer()
                        Toggle("Default to Grams", isOn: $preferGramsByDefault)
                            .labelsHidden()
                            .tint(AppColors.calorie)
                    }

                    Picker(selection: $weekStartsOnMonday) {
                        Text("Sunday").tag(false)
                        Text("Monday").tag(true)
                    } label: {
                        Label {
                            Text("Week Starts On")
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)

                    NavigationLink {
                        MealTimeSettingsView()
                    } label: {
                        Label {
                            HStack {
                                Text("Meal Times")
                                Spacer()
                                Text("Customize")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label {
                            Text("Notifications")
                        } icon: {
                            Image(systemName: "bell")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }

                    HStack {
                        Label {
                            Text("Water Tracking")
                        } icon: {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(AppColors.calorie)
                        }
                        Spacer()
                        Toggle("Water Tracking", isOn: $waterTrackingEnabled)
                            .labelsHidden()
                            .tint(AppColors.calorie)
                            .onChange(of: waterTrackingEnabled) { _, isEnabled in
                                if !isEnabled {
                                    notificationManager.scheduleWaterReminder(enabled: false, hour: 14, minute: 0)
                                    UserDefaults.standard.set(false, forKey: WaterSettings.reminderEnabledKey)
                                }
                                WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
                            }
                    }

                    if waterTrackingEnabled {
                        Button {
                            showWaterGoalPicker = true
                        } label: {
                            HStack {
                                Label {
                                    Text("Daily Water Goal")
                                } icon: {
                                    Image(systemName: "target")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                .foregroundStyle(.primary)
                                Spacer()
                                Text(waterUnit.formatted(milliliters: waterDailyGoal))
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        Picker(selection: $waterUnitRaw) {
                            ForEach(WaterUnit.allCases) { unit in
                                Text("\(unit.title) (\(unit.symbol))").tag(unit.rawValue)
                            }
                        } label: {
                            Label {
                                Text("Water Unit")
                            } icon: {
                                Image(systemName: "ruler")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .onChange(of: waterUnitRaw) { _, _ in
                            WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
                        }
                    }

                }
                .listRowBackground(AppColors.appCard)

                Group {
                    // Section 4: AI Provider
                    Section("AI Provider") {
                        Picker(selection: $selectedProvider) {
                            ForEach(AIProvider.allCases) { provider in
                                Label(provider.rawValue, systemImage: provider.icon).tag(provider)
                            }
                        } label: {
                            Label {
                                Text("Provider")
                            } icon: {
                                Image(systemName: "cpu")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .onChange(of: selectedProvider) { _, newProvider in
                            AIProviderSettings.selectedProvider = newProvider
                            selectedModel = newProvider.defaultModel
                            AIProviderSettings.selectedModel = newProvider.defaultModel
                            apiKeyText = AIProviderSettings.apiKey(for: newProvider) ?? ""
                            customBaseURL = AIProviderSettings.customBaseURL(for: newProvider) ?? ""
                        }

                        if selectedProvider.supportsCustomModelName {
                            // Free-form TextField for any model ID, with optional preset suggestions menu
                            // (e.g., OpenRouter has presets but lets user type any of openrouter.ai/models).
                            HStack {
                                Label {
                                    Text("Model")
                                } icon: {
                                    Image(systemName: "brain")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                TextField(
                                    selectedProvider == .openrouter
                                        ? "e.g. anthropic/claude-sonnet-4"
                                        : "e.g. gpt-4o-mini",
                                    text: $selectedModel
                                )
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onChange(of: selectedModel) { _, newModel in
                                        AIProviderSettings.selectedModel = newModel
                                    }
                                if !selectedProvider.models.isEmpty {
                                    Menu {
                                        ForEach(selectedProvider.models, id: \.self) { model in
                                            Button(model) {
                                                selectedModel = model
                                                AIProviderSettings.selectedModel = model
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "list.bullet.circle")
                                            .foregroundStyle(AppColors.calorie)
                                    }
                                }
                            }
                        } else {
                            Picker(selection: $selectedModel) {
                                ForEach(selectedProvider.models, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            } label: {
                                Label {
                                    Text("Model")
                                } icon: {
                                    Image(systemName: "brain")
                                        .foregroundStyle(AppColors.calorie)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.secondary)
                            .onAppear {
                                if !selectedProvider.models.contains(selectedModel) {
                                    selectedModel = selectedProvider.defaultModel
                                    AIProviderSettings.selectedModel = selectedModel
                                }
                            }
                            .onChange(of: selectedModel) { _, newModel in
                                AIProviderSettings.selectedModel = newModel
                            }
                        }

                        if selectedProvider.requiresAPIKey {
                            HStack {
                                Label {
                                    Text("API Key")
                                } icon: {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                Group {
                                    if showAPIKey {
                                        TextField(selectedProvider.apiKeyPlaceholder, text: $apiKeyText)
                                    } else {
                                        SecureField(selectedProvider.apiKeyPlaceholder, text: $apiKeyText)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: apiKeyText) { _, newValue in
                                    let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    AIProviderSettings.setAPIKey(t.isEmpty ? nil : t, for: selectedProvider)
                                }
                                Button {
                                    showAPIKey.toggle()
                                } label: {
                                    Image(systemName: showAPIKey ? "eye.fill" : "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if selectedProvider == .ollama || selectedProvider.requiresCustomEndpoint {
                            HStack {
                                Label {
                                    Text(selectedProvider.requiresCustomEndpoint ? "Base URL" : "Server URL")
                                } icon: {
                                    Image(systemName: "link")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                TextField(
                                    selectedProvider.requiresCustomEndpoint
                                        ? "https://your-endpoint.com/v1"
                                        : selectedProvider.baseURL,
                                    text: $customBaseURL
                                )
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                    .onChange(of: customBaseURL) { _, newValue in
                                        let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        AIProviderSettings.setCustomBaseURL(t.isEmpty ? nil : t, for: selectedProvider)
                                    }
                            }

                            HStack {
                                Label {
                                    Text("Request Timeout")
                                } icon: {
                                    Image(systemName: "timer")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                TextField("180", text: $requestTimeoutSecondsText)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .frame(maxWidth: 70)
                                    .onChange(of: requestTimeoutSecondsText) { _, newValue in
                                        let digits = newValue.filter(\.isNumber)
                                        if digits != newValue { requestTimeoutSecondsText = digits }
                                        if let seconds = Int(digits), seconds > 0 {
                                            AIProviderSettings.requestTimeoutSeconds = seconds
                                        }
                                    }
                                Text("sec")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Only OpenAI-compatible + Anthropic send a token cap; Gemini is
                        // left uncapped, so hide this for Gemini.
                        if selectedProvider.apiFormat != .gemini {
                            HStack {
                                Label {
                                    Text("Max Response Tokens")
                                } icon: {
                                    Image(systemName: "text.append")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                TextField("1024", text: $maxResponseTokensText)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .keyboardType(.numberPad)
                                    .frame(maxWidth: 90)
                                    .onChange(of: maxResponseTokensText) { _, newValue in
                                        let digits = newValue.filter(\.isNumber)
                                        if digits != newValue { maxResponseTokensText = digits }
                                        if let n = Int(digits), n > 0 {
                                            AIProviderSettings.maxResponseTokens = n
                                        }
                                    }
                            }
                        }
                    }
                        .listRowBackground(AppColors.appCard)
                }

                // Custom AI Instructions (User Context) — prepended to every AI request when non-empty
                Section {
                    TextField(
                        "I live in Germany, assume European portion sizes. I'm on a bodybuilding cut.",
                        text: $customAIInstructions,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .autocorrectionDisabled(false)
                    .focused($customInstructionsFocused)

                    Button {
                        AIProviderSettings.userContext = customAIInstructions
                        let canonical = AIProviderSettings.userContext
                        customAIInstructions = canonical
                        savedAIInstructions = canonical
                        customInstructionsFocused = false
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save", systemImage: "checkmark.circle.fill")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(customAIInstructions == savedAIInstructions ? .secondary : AppColors.calorie)
                            Spacer()
                        }
                    }
                    .disabled(customAIInstructions == savedAIInstructions)
                } header: {
                    Text("Custom AI Instructions")
                } footer: {
                    Text("Optional context sent with every AI request — region, diet, athletic goals, anything you'd otherwise repeat each time. Leave empty to disable.")
                }
                .listRowBackground(AppColors.appCard)

                Group {
                    // Fallback Provider — retry on a second provider when the primary fails
                    Section {
                        Toggle(isOn: $fallbackEnabled) {
                            Label {
                                Text("Enable Fallback")
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .tint(AppColors.calorie)
                        .onChange(of: fallbackEnabled) { _, newValue in
                            AIProviderSettings.fallbackEnabled = newValue
                        }

                        if fallbackEnabled {
                            // Fallback provider list shows all 13 — same provider as primary IS allowed
                            // (so e.g. Gemini Pro primary + Gemini Flash fallback works for capacity diversity).
                            // The collision is handled at the model layer below + at the runtime check in
                            // AIProviderSettings.currentFallbackConfig.
                            Picker(selection: $selectedFallbackProvider) {
                                ForEach(AIProvider.allCases) { provider in
                                    Label(provider.rawValue, systemImage: provider.icon).tag(provider)
                                }
                            } label: {
                                Label {
                                    Text("Provider")
                                } icon: {
                                    Image(systemName: "cpu")
                                        .foregroundStyle(AppColors.calorie)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.secondary)
                            .onChange(of: selectedFallbackProvider) { _, newProvider in
                                AIProviderSettings.selectedFallbackProvider = newProvider
                                if !newProvider.supportsCustomModelName,
                                   !newProvider.models.contains(selectedFallbackModel) {
                                    selectedFallbackModel = newProvider.defaultModel
                                    AIProviderSettings.selectedFallbackModel = selectedFallbackModel
                                }
                                // If switching fallback to same provider as primary AND model collides,
                                // bump to first non-primary model so picker doesn't show identical config.
                                if newProvider == selectedProvider, selectedFallbackModel == selectedModel,
                                   let alt = newProvider.models.first(where: { $0 != selectedModel }) {
                                    selectedFallbackModel = alt
                                    AIProviderSettings.selectedFallbackModel = alt
                                }
                                fallbackApiKeyText = AIProviderSettings.apiKey(for: newProvider) ?? ""
                                fallbackBaseURL = AIProviderSettings.customBaseURL(for: newProvider) ?? ""
                            }

                            if selectedFallbackProvider.supportsCustomModelName {
                                // Free-form TextField + preset Menu, mirrors primary AI Provider section.
                                // When fallback provider == primary, the preset menu hides the primary's model.
                                let presetOptions: [String] = {
                                    if selectedFallbackProvider == selectedProvider {
                                        return selectedFallbackProvider.models.filter { $0 != selectedModel }
                                    }
                                    return selectedFallbackProvider.models
                                }()
                                HStack {
                                    Label {
                                        Text("Model")
                                    } icon: {
                                        Image(systemName: "brain")
                                            .foregroundStyle(AppColors.calorie)
                                    }
                                    Spacer()
                                    TextField(
                                        selectedFallbackProvider == .openrouter
                                            ? "e.g. anthropic/claude-sonnet-4"
                                            : "e.g. gpt-4o-mini",
                                        text: $selectedFallbackModel
                                    )
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onChange(of: selectedFallbackModel) { _, newModel in
                                        AIProviderSettings.selectedFallbackModel = newModel
                                    }
                                    if !presetOptions.isEmpty {
                                        Menu {
                                            ForEach(presetOptions, id: \.self) { model in
                                                Button(model) {
                                                    selectedFallbackModel = model
                                                    AIProviderSettings.selectedFallbackModel = model
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "list.bullet.circle")
                                                .foregroundStyle(AppColors.calorie)
                                        }
                                    }
                                }
                            } else {
                                // Same provider as primary → exclude the primary's model from the picker so
                                // user can't accidentally pick an identical config.
                                let modelOptions: [String] = {
                                    if selectedFallbackProvider == selectedProvider {
                                        return selectedFallbackProvider.models.filter { $0 != selectedModel }
                                    }
                                    return selectedFallbackProvider.models
                                }()
                                if !modelOptions.isEmpty {
                                    Picker(selection: $selectedFallbackModel) {
                                        ForEach(modelOptions, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    } label: {
                                        Label {
                                            Text("Model")
                                        } icon: {
                                            Image(systemName: "brain")
                                                .foregroundStyle(AppColors.calorie)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)
                                    .onChange(of: selectedFallbackModel) { _, newModel in
                                        AIProviderSettings.selectedFallbackModel = newModel
                                    }
                                    .onAppear {
                                        if !modelOptions.contains(selectedFallbackModel),
                                           let first = modelOptions.first {
                                            selectedFallbackModel = first
                                            AIProviderSettings.selectedFallbackModel = first
                                        }
                                    }
                                }
                            }

                            if selectedFallbackProvider.requiresAPIKey {
                                HStack {
                                    Label {
                                        Text("API Key")
                                    } icon: {
                                        Image(systemName: "key.fill")
                                            .foregroundStyle(AppColors.calorie)
                                    }
                                    Spacer()
                                    Group {
                                        if showFallbackAPIKey {
                                            TextField(selectedFallbackProvider.apiKeyPlaceholder, text: $fallbackApiKeyText)
                                        } else {
                                            SecureField(selectedFallbackProvider.apiKeyPlaceholder, text: $fallbackApiKeyText)
                                        }
                                    }
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .onChange(of: fallbackApiKeyText) { _, newValue in
                                        AIProviderSettings.setAPIKey(newValue.isEmpty ? nil : newValue, for: selectedFallbackProvider)
                                    }
                                    Button {
                                        showFallbackAPIKey.toggle()
                                    } label: {
                                        Image(systemName: showFallbackAPIKey ? "eye.fill" : "eye.slash.fill")
                                            .foregroundStyle(.secondary)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            if selectedFallbackProvider == .ollama || selectedFallbackProvider.requiresCustomEndpoint {
                                HStack {
                                    Label {
                                        Text(selectedFallbackProvider.requiresCustomEndpoint ? "Base URL" : "Server URL")
                                    } icon: {
                                        Image(systemName: "link")
                                            .foregroundStyle(AppColors.calorie)
                                    }
                                    Spacer()
                                    TextField(
                                        selectedFallbackProvider.requiresCustomEndpoint
                                            ? "https://your-endpoint.com/v1"
                                            : selectedFallbackProvider.baseURL,
                                        text: $fallbackBaseURL
                                    )
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)
                                    .onChange(of: fallbackBaseURL) { _, newValue in
                                        AIProviderSettings.setCustomBaseURL(newValue.isEmpty ? nil : newValue, for: selectedFallbackProvider)
                                    }
                                }

                                if !selectedProvider.usesConfigurableRequestTimeout {
                                    HStack {
                                        Label {
                                            Text("Request Timeout")
                                        } icon: {
                                            Image(systemName: "timer")
                                                .foregroundStyle(AppColors.calorie)
                                        }
                                        Spacer()
                                        TextField("180", text: $requestTimeoutSecondsText)
                                            .textFieldStyle(.plain)
                                            .multilineTextAlignment(.trailing)
                                            .keyboardType(.numberPad)
                                            .frame(maxWidth: 70)
                                            .onChange(of: requestTimeoutSecondsText) { _, newValue in
                                                let digits = newValue.filter(\.isNumber)
                                                if digits != newValue { requestTimeoutSecondsText = digits }
                                                if let seconds = Int(digits), seconds > 0 {
                                                    AIProviderSettings.requestTimeoutSeconds = seconds
                                                }
                                            }
                                        Text("sec")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Fallback Provider")
                    } footer: {
                        Text("If your primary provider fails (overloaded, no credits, network error), the request automatically retries on this fallback. Same provider as primary is allowed — just pick a different model.")
                    }
                        .listRowBackground(AppColors.appCard)

                        // Speech-to-Text Provider
                        Section {
                        Picker(selection: $selectedSpeechProvider) {
                            ForEach(SpeechProvider.allCases) { provider in
                                Text(provider.rawValue).tag(provider)
                            }
                        } label: {
                            Label {
                                Text("Provider")
                            } icon: {
                                Image(systemName: selectedSpeechProvider.icon)
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .onChange(of: selectedSpeechProvider) { _, newProvider in
                            SpeechSettings.selectedProvider = newProvider
                            speechApiKeyText = SpeechSettings.apiKey(for: newProvider) ?? ""
                            selectedSpeechLanguage = SpeechSettings.selectedLanguage(for: newProvider)
                        }

                        Text(selectedSpeechProvider.description)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Picker(selection: $selectedSpeechLanguage) {
                            ForEach(SpeechLanguage.allCases) { language in
                                Text(language.displayName).tag(language)
                            }
                        } label: {
                            Label {
                                Text("Language")
                            } icon: {
                                Image(systemName: "globe")
                                    .foregroundStyle(AppColors.calorie)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.secondary)
                        .onChange(of: selectedSpeechLanguage) { _, newLanguage in
                            SpeechSettings.setLanguage(newLanguage, for: selectedSpeechProvider)
                        }

                        if selectedSpeechProvider.requiresAPIKey {
                            HStack {
                                Label {
                                    Text("API Key")
                                } icon: {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(AppColors.calorie)
                                }
                                Spacer()
                                Group {
                                    if showSpeechAPIKey {
                                        TextField(selectedSpeechProvider.apiKeyPlaceholder, text: $speechApiKeyText)
                                    } else {
                                        SecureField(selectedSpeechProvider.apiKeyPlaceholder, text: $speechApiKeyText)
                                    }
                                }
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .onChange(of: speechApiKeyText) { _, newValue in
                                    SpeechSettings.setAPIKey(newValue.isEmpty ? nil : newValue, for: selectedSpeechProvider)
                                }
                                Button {
                                    showSpeechAPIKey.toggle()
                                } label: {
                                    Image(systemName: showSpeechAPIKey ? "eye.fill" : "eye.slash.fill")
                                        .foregroundStyle(.secondary)
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } header: {
                        Text("Speech-to-Text")
                    } footer: {
                        Text("Used when you tap the voice icon to log a meal. Each provider remembers its own language. Provider Auto keeps the provider default; Use iPhone Language sends your current iPhone language when supported.")
                    }
                        .listRowBackground(AppColors.appCard)
                }

                WorkoutLoggingSettingsSection()

                // Section 5: Health & Data
                Section("Health & Data") {
                    // Apple Health
                    HStack {
                        Label {
                            Text("Apple Health")
                        } icon: {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                        Spacer()
                        Toggle("", isOn: $healthKitEnabled)
                            .labelsHidden()
                            .onChange(of: healthKitEnabled) { _, enabled in
                                handleHealthKitToggle(enabled)
                            }
                    }

                    // Export Food Diary
                    Button {
                        showExportDiary = true
                    } label: {
                        Label {
                            Text("Export Food Diary")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(AppColors.calorie)
                        }
                    }
                    .buttonStyle(.plain)

                    // Clear Food Log
                    Button(role: .destructive) {
                        showClearFoodLogConfirmation = true
                    } label: {
                        Label {
                            Text("Clear Food Log")
                        } icon: {
                            Image(systemName: "fork.knife")
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)

                    // Delete All Data — always visible
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label {
                            Text("Delete All Data")
                        } icon: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.appCard)

                // Support stays separate and immediately visible before About. App Review
                // treats external developer-donation links as digital payments (guideline
                // 3.1.1), so iOS uses the native consumable purchases here.
                TipJarSettingsSection()

                // About — folded in from the former About tab so it's the last
                // section of Settings (Home / Progress / Coach / Settings = 4 tabs).
                AboutSettingsSections(
                    updateState: $updateState,
                    refreshUpdateState: refreshUpdateState
                )
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.appBackground)
            .navigationBarHidden(true)
            .sheet(isPresented: $showExportDiary) {
                ExportDiaryView()
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .editBirthday:
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("Birthday")
                                .font(.system(.title2, design: .rounded, weight: .bold))

                            DatePicker(
                                "Birthday",
                                selection: profileBinding.birthday,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()

                            Button {
                                saveProfile()
                                activeSheet = nil
                            } label: {
                                Text("Save")
                                    .font(.system(.headline, design: .rounded, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        LinearGradient(colors: AppColors.calorieGradient, startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .padding(.horizontal, 24)

                            Spacer()
                        }
                        .padding(.top, 24)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { activeSheet = nil }
                            }
                        }
                    }
                    .presentationDetents([.medium])

                case .editHeight:
                    HeightPickerSheet(
                        currentHeightCm: profile.heightCm
                    ) { newHeight in
                        profile.heightCm = newHeight
                        saveProfile()
                    }

                case .editWeight:
                    WeightPickerSheet(
                        currentWeightKg: profile.weightKg
                    ) { newWeight in
                        profile.weightKg = newWeight
                        // Invalidate goal weight if the new current weight makes the direction impossible.
                        if let gw = profile.goalWeightKg {
                            let mismatch = (profile.goal == .lose && gw >= newWeight)
                                        || (profile.goal == .gain && gw <= newWeight)
                            if mismatch { profile.goalWeightKg = nil }
                        }
                        saveProfile()
                        weightStore.addEntry(WeightEntry(weightKg: newWeight))
                    }

                case .editBodyFat:
                    BodyFatPickerSheet(
                        currentPercentage: profile.bodyFatPercentage
                    ) { newValue in
                        profile.bodyFatPercentage = newValue
                        // Goal body fat only makes sense alongside a current
                        // value — clear it whenever the current is cleared so
                        // a stale goal doesn't linger on a user who's opted out.
                        if newValue == nil { profile.goalBodyFatPercentage = nil }
                        saveProfile()
                    }

                case .editGoalBodyFat:
                    // Goal body fat is purely cosmetic — does NOT participate
                    // in BMR / TDEE / macro math, so editing it just saves.
                    GoalBodyFatPickerSheet(
                        currentGoal: profile.goalBodyFatPercentage,
                        currentBodyFat: profile.bodyFatPercentage
                    ) { newValue in
                        profile.goalBodyFatPercentage = newValue
                        saveProfile()
                    }

                case .editGoalWeight:
                    WeightPickerSheet(
                        currentWeightKg: profile.goalWeightKg ?? profile.weightKg
                    ) { newGoalWeight in
                        // Validate against current goal direction.
                        let invalid = (profile.goal == .lose && newGoalWeight >= profile.weightKg)
                                   || (profile.goal == .gain && newGoalWeight <= profile.weightKg)
                        if invalid {
                            invalidGoalWeightMessage = profile.goal == .lose
                                ? "A Lose goal needs a target below your current weight."
                                : "A Gain goal needs a target above your current weight."
                            showInvalidGoalWeightAlert = true
                            return
                        }
                        profile.goalWeightKg = newGoalWeight
                        saveProfile()
                    }

                case .editCalories:
                    NutritionPickerSheet(
                        label: "Calories", unit: "kcal",
                        currentValue: profile.effectiveCalories,
                        range: 800...6000, step: 50,
                        onSave: { setCalories(to: $0) },
                        onResetToAuto: profile.isCaloriesLocked ? { resetCaloriesLock() } : nil
                    )

                case .editProtein:
                    NutritionPickerSheet(
                        label: "Protein", unit: "g",
                        currentValue: profile.effectiveProtein,
                        range: 10...500, step: 5,
                        onSave: { setMacro(.protein, to: $0) },
                        onResetToAuto: profile.isMacroLocked(.protein) ? { resetMacroLock(.protein) } : nil
                    )

                case .editCarbs:
                    NutritionPickerSheet(
                        label: "Carbs", unit: "g",
                        currentValue: profile.effectiveCarbs,
                        range: 0...800, step: 5,
                        onSave: { setMacro(.carbs, to: $0) },
                        onResetToAuto: profile.isMacroLocked(.carbs) ? { resetMacroLock(.carbs) } : nil
                    )

                case .editFat:
                    NutritionPickerSheet(
                        label: "Fat", unit: "g",
                        currentValue: profile.effectiveFat,
                        range: 10...300, step: 5,
                        onSave: { setMacro(.fat, to: $0) },
                        onResetToAuto: profile.isMacroLocked(.fat) ? { resetMacroLock(.fat) } : nil
                    )

                }
            }
            .alert("Clear Food Log", isPresented: $showClearFoodLogConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All Logs", role: .destructive) {
                    foodStore.replaceAllEntries([])
                }
            } message: {
                Text("This will permanently delete all your logged food entries. Your profile, weight entries, favorites, and workout history will be kept. This action cannot be undone.")
            }
            .alert("Default to Grams", isPresented: $showDefaultGramsInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("When enabled, new food results open with grams selected even if the AI detects cups, portions, or servings. You can still switch units for each food.")
            }
            .alert("Adaptive Goals", isPresented: $showAdaptiveGoalsInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("About once a week when you open the app, Fud AI automatically re-runs the full goal calculation — the same one the Recalculate button uses — from your profile, recent logged food, and weight trend. If Energy Burn is on, it uses your measured burn as the maintenance anchor. It skips silently if the AI is unavailable. Turning this off restores the targets from before Adaptive Goals first changed them. This is not medical advice.")
            }
            .alert("Energy Burn", isPresented: $showEnergyBurnInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("When on, Fud AI uses your measured calories burned from Apple Health — a 14-day average of Active + Basal energy — as your maintenance (TDEE) anchor when calculating goals, instead of the formula estimate. No AI is used to read your burn. Requires Apple Health. Works with the Recalculate button and with Adaptive Goals.")
            }
            .alert(adaptiveGoalAlertTitle, isPresented: $showAdaptiveGoalAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(adaptiveGoalAlertMessage)
            }
            .sheet(isPresented: $showCalculationMethods) {
                CalculationMethodsView()
            }
            .sheet(isPresented: $showWaterGoalPicker) {
                WaterGoalPickerSheet(currentGoal: waterDailyGoal, unit: waterUnit) {
                    waterDailyGoal = $0
                    WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
                }
            }
            .onAppear {
                // Existing users (and anyone who has never recalculated) start with no baseline.
                // Seed it to the current inputs so the "recalculate suggested" nudge only appears
                // after a genuine change from here on, instead of firing on first launch.
                if UserDefaults.standard.string(forKey: Self.lastRecalcGoalSignatureKey) == nil {
                    markGoalsRecalculated()
                }
            }
            .alert("Can't Rebalance", isPresented: $showAutoMacroEditAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Calories is locked and both other macros are locked, so there's nothing left to absorb this change. Unlock calories or another macro, then try again.")
            }
            .alert("Max 2 Macros Locked", isPresented: $showMaxPinnedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("At most 2 macros can be locked at a time, so one stays free to balance. Unlock another macro first (tap its lock icon).")
            }
            .alert("Invalid Goal Weight", isPresented: $showInvalidGoalWeightAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(invalidGoalWeightMessage)
            }
            .alert("Delete All Data", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    // Delete All Data is local-only. We intentionally do NOT touch Apple
                    // Health samples — that data is personal and belongs to the user, not
                    // this app's storage. If they want HK cleaned up they can do it from
                    // the Health app's Sources → Fud AI screen.
                    foodStore.replaceAllEntries([])
                    weightStore.replaceAllEntries([])
                    waterStore.clear()
                    strengthWorkoutStore.clearAll()
                    // Wipe the food-image folder defensively — replaceAllEntries
                    // already cleans per-entry files, but a belt-and-braces
                    // deleteAll catches any orphans from earlier crash recovery.
                    FoodImageStore.shared.deleteAll()
                    // Cancel all notifications
                    notificationManager.cancelAllNotifications()
                    // Wipe all persisted data
                    let domain = Bundle.main.bundleIdentifier ?? ""
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                    // Wipe Keychain API keys
                    AIProviderSettings.deleteAllData()
                    SpeechSettings.deleteAllData()
                    chatStore.reset()
                    // Wipe the widget snapshot out of the App Group container —
                    // it lives outside UserDefaults.standard and would otherwise
                    // keep showing the previous profile's numbers on the widget.
                    WidgetSnapshot.clear()
                    WidgetCenter.shared.reloadAllTimelines()
                    hasCompletedOnboarding = false
                }
            } message: {
                Text("This will permanently delete all your data including food logs, weight entries, workout history, and profile. This action cannot be undone.")
            }
        }
    }

    private func saveProfile() {
        profile.save()
    }

    private static let lastRecalcGoalSignatureKey = "lastRecalcGoalSignature"

    /// True when a goal-relevant input (weight, activity, goal, pace, …) has changed since the
    /// last Recalculate. Recalculate stays tappable at all times — this only drives a soft
    /// "your profile changed, recalculate to refresh" nudge, never disables the button.
    private var goalsNeedRecalc: Bool {
        guard let stored = UserDefaults.standard.string(forKey: Self.lastRecalcGoalSignatureKey) else { return false }
        return stored != profile.goalInputSignature
    }

    /// Capture the current goal inputs as the "last recalculated" baseline so the nudge clears.
    private func markGoalsRecalculated() {
        UserDefaults.standard.set(profile.goalInputSignature, forKey: Self.lastRecalcGoalSignatureKey)
    }

    /// A goal row (calories or a macro). Tap the row to edit the value; tap the lock icon to lock it.
    /// Locking a macro keeps it fixed during a rebalance; locking calories holds the calorie total
    /// when a macro is edited. Lock controls are disabled while Adaptive Goals is on (it auto-
    /// recalculates and would overwrite). `macro == nil` means the calories row.
    @ViewBuilder
    private func lockableGoalRow(icon: String, label: String, valueText: String, macro: AutoBalanceMacro?, sheet: ActiveSheet) -> some View {
        let locked = macro.map { profile.isMacroLocked($0) } ?? profile.isCaloriesLocked
        // The lock glyph is a read-only indicator. Saving a value locks it; the picker's "Reset to
        // Auto-balance" releases it. Tapping the row opens the picker (or explains, when Adaptive is
        // on and editing would be overwritten weekly).
        Button {
            if adaptiveGoalsEnabled {
                showAdaptiveGoalsLockHint()
            } else {
                activeSheet = sheet
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(AppColors.calorie)
                    .frame(width: 22)
                Text(LocalizedDisplayText.text(label))
                    .foregroundStyle(.primary)
                Spacer()
                Text(valueText)
                    .foregroundStyle(.secondary)
                Image(systemName: locked ? "lock.fill" : "lock.open")
                    .font(.footnote)
                    .foregroundStyle(locked ? AppColors.calorie : .secondary)
                    .opacity(adaptiveGoalsEnabled ? 0.3 : 1)
                    .accessibilityLabel(locked ? "Locked" : "Unlocked")
            }
        }
        .buttonStyle(.plain)
    }

    /// Explain why the goals section is read-only while Adaptive Goals owns the targets.
    private func showAdaptiveGoalsLockHint() {
        showAdaptiveGoalAlert(
            title: "Adaptive Goals Is On",
            message: "Turn off Adaptive Goals to lock or set your own calories and macros. While it's on, Fud AI recalculates them for you each week."
        )
    }

    /// Apply a calorie edit: locked macros stay, unlocked macros rescale to the new total. Saving a
    /// value the user chose locks it (the lock icon then releases it).
    private func setCalories(to value: Int) {
        profile.applyCaloriesEdit(value)
        profile.caloriesLocked = true
        saveProfile()
    }

    /// Apply a macro edit through the rebalance engine, then lock the macro the user just set
    /// (honoring the max-2 cap — silently left unlocked if two macros are already locked). When
    /// calories is locked and neither other macro can absorb the change, the edit is rejected.
    private func setMacro(_ macro: AutoBalanceMacro, to value: Int) {
        guard profile.applyMacroEdit(macro, grams: value) else {
            showAutoMacroEditAlert = true
            return
        }
        if !profile.isMacroLocked(macro) {
            _ = profile.toggleMacroLock(macro)
        }
        saveProfile()
    }

    /// "Reset to Auto-balance" from the picker: release the macro's lock and re-derive it as the
    /// balancing remainder.
    private func resetMacroLock(_ macro: AutoBalanceMacro) {
        profile.resetMacroToBalance(macro)
        saveProfile()
    }

    /// "Reset to Auto-balance" from the calories picker: release the calories lock and snap the
    /// total to the sum of the macros.
    private func resetCaloriesLock() {
        profile.resetCaloriesToBalance()
        saveProfile()
    }

    private func recalculateGoalsNow() {
        Task { await recalculateGoalsWithAI() }
    }

    /// AI-driven goal recalculation. Sends the profile + the app's formulas to the user's
    /// selected provider and applies the returned calorie
    /// and protein/fat targets; carbs auto-balances so totals stay consistent. AI-only — when
    /// the provider is unavailable (no key / offline / bad response) the
    /// existing goals are left unchanged and the user is told to fix their provider/key, with
    /// NO silent formula fallback. Then recomputes the optional "Other Nutrients"
    /// (fiber/sugar/sodium/…) via AI, leaving them untouched if that call fails (no clobbering
    /// of user customizations). The whole recalc is aborted if the user edits a goal input
    /// mid-call. Food calorie estimation is untouched.
    private func recalculateGoalsWithAI() async {
        guard !isRecalculatingGoals else { return }
        isRecalculatingGoals = true
        defer { isRecalculatingGoals = false }

        // Snapshot the inputs the AI computes against. The profile is shared (ProfileStore)
        // and can be reloaded/edited on the main actor during the await, so we apply results
        // only if the calc-relevant inputs are still unchanged — otherwise the concurrent
        // edit (which already reset goals) wins, avoiding a stale/lost-update.
        let snapshot = profile
        // Empirical signal: recent logged intake + observed weight trend, so the AI can estimate
        // true maintenance by hit-and-trial instead of trusting the formula TDEE alone.
        let forecast = WeightAnalysisService.compute(weights: weightStore.entries, foods: foodStore.entries, profile: snapshot)
        // Energy Burn toggle: when on, anchor maintenance to the user's measured Apple Health burn.
        let measuredTdee = await measuredEnergyTdee(for: snapshot)
        do {
            let result = try await GeminiService.calculateGoals(profile: snapshot, forecast: forecast, measuredTdee: measuredTdee, measurement: bodyMeasurementStore.latestEntry, heightMetric: heightMetric, weightMetric: weightMetric)
            guard goalInputsUnchanged(snapshot, profile) else { return }
            // Apply the AI's calorie + protein targets. Protein is the AI's choice within a range
            // near the activity multiplier (it can flex with the goal + history), not a rigid lock.
            // Carbs and fat stay auto-balanced (unlocked) and absorb the remaining calories.
            profile.customCalories = result.calories
            profile.customProtein = result.protein
            profile.customCarbs = result.carbs
            profile.customFat = result.fat
            profile.autoBalanceMacro = nil
            profile.clearLocks()
            saveProfile()
            markGoalsRecalculated()
        } catch {
            guard goalInputsUnchanged(snapshot, profile) else { return }
            // Goals are AI-only now — no formula fallback. Leave the existing goals
            // untouched and tell the user so they can fix their provider/key and retry.
            showAdaptiveGoalAlert(
                title: "Couldn't Recalculate",
                message: "Fud AI couldn't reach your AI provider, so your goals are unchanged. Check your AI provider and API key in Settings, then try Recalculate again."
            )
            return
        }

        // Also recompute the optional "Other Nutrients" (fiber, sugar, sodium, …) via AI,
        // falling back to the standard defaults when AI is unavailable. These live in a
        // separate store from the calorie/macro goals.
        do {
            let suggested = try await GeminiService.suggestOptionalNutrientGoals(
                profile: profile,
                currentGoals: OptionalNutrientGoals.current,
                heightMetric: heightMetric,
                weightMetric: weightMetric
            )
            OptionalNutrientGoals.save(suggested)
        } catch {
            // AI unavailable — leave the existing Other Nutrients goals untouched rather than
            // clobbering any user customizations with defaults.
        }
        // Note: we do NOT chain Adaptive here. Adaptive Goals now *is* this same calculation on a
        // weekly timer, so chaining would fire a second identical AI call.
    }

    /// True when the fields that drive the goal calculation are identical between two profile
    /// snapshots. Used to discard an in-flight AI recalc result if the user changed an input
    /// (weight, activity, goal, etc.) mid-call.
    private func goalInputsUnchanged(_ a: UserProfile, _ b: UserProfile) -> Bool {
        a.gender == b.gender
            && a.birthday == b.birthday
            && a.heightCm == b.heightCm
            && a.weightKg == b.weightKg
            && a.activityLevel == b.activityLevel
            && a.goal == b.goal
            && a.weeklyChangeKg == b.weeklyChangeKg
            && a.goalWeightKg == b.goalWeightKg
            && a.bodyFatPercentage == b.bodyFatPercentage
            && a.useBodyFatInBMR == b.useBodyFatInBMR
    }

    private func handleHealthKitToggle(_ enabled: Bool) {
        if enabled {
            Task {
                let authorized = await healthKitManager.requestAuthorization()
                if authorized {
                    healthKitManager.writeWeight(kg: profile.weightKg, date: .now)
                    healthKitManager.writeHeight(cm: profile.heightCm)
                    if let bf = profile.bodyFatPercentage {
                        healthKitManager.writeBodyFat(fraction: bf)
                    }
                    let measurements = await healthKitManager.fetchLatestBodyMeasurements()
                    if let kg = measurements.weight, abs(profile.weightKg - kg) > 0.01 {
                        profile.weightKg = kg
                    }
                    if let cm = measurements.height, abs(profile.heightCm - cm) > 0.1 {
                        profile.heightCm = cm
                    }
                    if let bf = measurements.bodyFat {
                        profile.bodyFatPercentage = bf
                    }
                    if let dob = measurements.dob {
                        profile.birthday = dob
                    }
                    if let sex = measurements.sex {
                        switch sex {
                        case .male: profile.gender = .male
                        case .female: profile.gender = .female
                        default: break
                        }
                    }
                    saveProfile()
                    healthKitManager.startBodyMeasurementObserver()
                    healthKitManager.backfillNutritionIfNeeded(
                        entries: foodStore.entries,
                        currentEntryIDs: { Set(foodStore.entries.map(\.id)) }
                    )
                    healthKitManager.synchronizeWorkoutBurnsWithHealthKit(
                        existing: { strengthWorkoutStore.workoutBurnSessions },
                        mergeBatch: { sessions in
                            strengthWorkoutStore.importWorkoutBurnSessions(sessions)
                        }
                    )
                } else {
                    healthKitEnabled = false
                }
            }
        } else {
            healthKitManager.stopObserver()
        }
    }

    private func handleAdaptiveGoalsToggle(_ enabled: Bool, wasEnabled: Bool) {
        if enabled {
            // Adaptive owns the targets while on and auto-recalculates — clear any user locks now so
            // the (disabled) lock controls read as unlocked, even before the weekly run lands.
            if profile.isCaloriesLocked || profile.lockedMacroCount > 0 {
                profile.clearLocks()
                saveProfile()
            }
            Task { await applyAdaptiveGoalsIfDue(force: !wasEnabled, showAlert: true) }
        } else {
            if AdaptiveGoalSettings.restorePreviousTargets(to: &profile) {
                saveProfile()
            }
            AdaptiveGoalSettings.clearPreviousTargets()
        }
    }

    /// Energy Burn is an input switch for the goal calc. Enabling requires Apple Health with enough
    /// data (mirrors Android) — otherwise we revert the toggle and tell the user instead of running
    /// an anchorless recalc. On a genuine enable/disable we re-run the calc so the new (or removed)
    /// measured anchor takes effect immediately, exactly like tapping Recalculate.
    private func handleEnergyBurnToggle(_ enabled: Bool) {
        // A programmatic revert (failed enable, below) re-fires this onChange — skip that pass.
        if energyBurnToggleReverting { energyBurnToggleReverting = false; return }
        if enabled {
            guard healthKitEnabled else {
                energyBurnToggleReverting = true
                energyBurnEnabled = false
                showAdaptiveGoalAlert(title: "Apple Health Needed", message: "Energy Burn uses your measured calories burned from Apple Health. Connect Apple Health first, then turn Energy Burn on.")
                return
            }
            Task {
                if await healthKitManager.fetchRecentEnergySummary(days: 14) == nil {
                    energyBurnToggleReverting = true
                    energyBurnEnabled = false
                    showAdaptiveGoalAlert(title: "Not Enough Health Data", message: "Fud AI needs at least 3 recent days of Apple Health energy data before it can use your measured burn.")
                    return
                }
                await recalculateGoalsWithAI()
            }
        } else {
            Task { await recalculateGoalsWithAI() }
        }
    }

    /// Energy Burn toggle resolved to a number: the user's measured maintenance from Apple Health
    /// (14-day Active + Basal average), or nil when Energy Burn is off, Health is disconnected, or
    /// there isn't enough data. Single source used by both manual Recalculate and Adaptive.
    private func measuredEnergyTdee(for profile: UserProfile) async -> Int? {
        guard energyBurnEnabled, healthKitEnabled else { return nil }
        guard let summary = await healthKitManager.fetchRecentEnergySummary(days: 14) else { return nil }
        return summary.totalAverageCalories ?? (Int(profile.bmr.rounded()) + summary.activeAverageCalories)
    }

    /// Adaptive Goals: automatically re-runs the FULL AI goal calculation (the same one the
    /// Recalculate button uses) about once a week, from the latest logged food + weight trend
    /// (hit-and-trial) and — when Energy Burn is on — the measured Health maintenance anchor.
    /// Silent and non-destructive on AI failure (keeps existing goals; marks checked so it doesn't
    /// retry every app open).
    private func applyAdaptiveGoalsIfDue(force: Bool, showAlert: Bool) async {
        guard adaptiveGoalsEnabled, !isApplyingAdaptiveGoals else { return }
        guard force || AdaptiveGoalSettings.shouldCheckThisWeek() else { return }

        isApplyingAdaptiveGoals = true
        defer { isApplyingAdaptiveGoals = false }

        let snapshot = profile
        let measuredTdee = await measuredEnergyTdee(for: snapshot)
        let forecast = WeightAnalysisService.compute(weights: weightStore.entries, foods: foodStore.entries, profile: snapshot)
        do {
            let result = try await GeminiService.calculateGoals(profile: snapshot, forecast: forecast, measuredTdee: measuredTdee, measurement: bodyMeasurementStore.latestEntry, heightMetric: heightMetric, weightMetric: weightMetric)
            guard goalInputsUnchanged(snapshot, profile) else { return }
            AdaptiveGoalSettings.savePreviousTargetsIfNeeded(from: profile)
            profile.customCalories = result.calories
            profile.customProtein = result.protein
            profile.customCarbs = result.carbs
            profile.customFat = result.fat
            profile.autoBalanceMacro = nil
            profile.clearLocks()
            saveProfile()
            markGoalsRecalculated()
            AdaptiveGoalSettings.markCheckedToday()
            if showAlert {
                showAdaptiveGoalAlert(title: "Adaptive Goals", message: "Updated to \(result.calories) kcal from your latest data." + (result.reason.map { " \($0)" } ?? ""))
            }
        } catch {
            // AI unavailable — keep existing goals. Mark checked so the auto-run doesn't hammer a
            // misconfigured provider on every app open; the user can still Recalculate manually.
            AdaptiveGoalSettings.markCheckedToday()
            if showAlert {
                showAdaptiveGoalAlert(title: "Adaptive Goals", message: "Couldn't reach your AI provider — your goals are unchanged. Check your AI provider and API key in Settings.")
            }
        }
    }

    private func showAdaptiveGoalAlert(title: String, message: String) {
        adaptiveGoalAlertTitle = title
        adaptiveGoalAlertMessage = message
        showAdaptiveGoalAlert = true
    }

}

#Preview {
    ContentView()
        .environment(FoodStore())
        .environment(WeightStore())
}
