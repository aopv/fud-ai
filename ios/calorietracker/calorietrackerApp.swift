//
//  calorietrackerApp.swift
//  calorietracker
//
//  Created by Apoorv Darshan on 05/02/26.
//

import SwiftUI
import HealthKit
import WidgetKit
import CoreSpotlight

@main
struct calorietrackerApp: App {
    @State private var foodStore = FoodStore()
    @State private var weightStore = WeightStore()
    @State private var bodyFatStore = BodyFatStore()
    @State private var notificationManager = NotificationManager()
    @State private var healthKitManager = HealthKitManager()
    @State private var profileStore = ProfileStore()
    @State private var chatStore = ChatStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("useMetric") private var useMetric = false
    @AppStorage(AppThemeColor.storageKey) private var appThemeColorRaw = AppThemeColor.defaultColor.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var isAutoRefreshingHealthEnergyGoals = false
    @State private var isAutoRefreshingAdaptiveGoals = false

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    init() {
        if CommandLine.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "userProfile")
        }
        BackgroundTaskManager.registerAll()
        WatchSnapshotSync.shared.startListening()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .environment(foodStore)
                        .environment(weightStore)
                        .environment(bodyFatStore)
                        .environment(notificationManager)
                        .environment(healthKitManager)
                        .environment(profileStore)
                        .environment(chatStore)
                } else {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .environment(notificationManager)
                        .environment(foodStore)
                        .environment(weightStore)
                        .environment(bodyFatStore)
                        .environment(healthKitManager)
                        .environment(profileStore)
                        .environment(chatStore)
                }
            }
            .tint(AppThemeColor.color(for: appThemeColorRaw).color)
            .preferredColorScheme(colorScheme)
            .onAppear {
                AppThemeColor.applyAppIconIfNeeded(for: AppThemeColor.color(for: appThemeColorRaw))
            }
            .onChange(of: appThemeColorRaw) { _, newValue in
                AppThemeColor.applyAppIconIfNeeded(for: AppThemeColor.color(for: newValue))
            }
            .onReceive(NotificationCenter.default.publisher(for: .userProfileDidChange)) { _ in
                refreshWidgetSnapshot()
            }
            .onContinueUserActivity(CSSearchableItemActionType) { _ in
                // Spotlight result tapped — app opens to the food log automatically
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.scheduleWidgetRefresh()
            }
            if newPhase == .active {
                Task {
                    await notificationManager.refreshAuthorizationStatus()
                }
                if notificationsEnabled, let profile = UserProfile.load() {
                    notificationManager.rescheduleDataDependentNotifications(
                        foodStore: foodStore, weightStore: weightStore, bodyFatStore: bodyFatStore, profile: profile
                    )
                    // Restore meal reminders if a Focus filter just deactivated
                    // (FocusFilterKeys.muteReminders is now false again).
                    notificationManager.rescheduleMealRemindersFromPreferences()
                }
                if hasCompletedOnboarding {
                    wireUpHealthKit()
                    // Re-wire on every scene-active so the widget refresh callback
                    // is connected for users who completed onboarding before this
                    // hook existed (the .onChange(hasCompletedOnboarding) branch
                    // only fires on the false→true transition, never on cold launch).
                    wireUpFoodStoreCallback()
                    if !refreshHealthEnergyGoalsIfNeeded() {
                        refreshAdaptiveGoalsIfNeeded()
                    }
                }
                // Refresh on scene-active so widgets roll over at midnight even
                // without an explicit food change.
                refreshWidgetSnapshot()
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if completed {
                wireUpFoodStoreCallback()
                wireUpHealthKit()
                // Seed the user's first WeightEntry from their onboarding-entered profile
                // weight. Used to be seeded in WeightStore.init with .default fallback,
                // which produced a 70 kg phantom entry for every fresh user.
                if let profile = UserProfile.load() {
                    weightStore.seedInitialWeightFromProfileIfEmpty(profile.weightKg)
                    // Same idea for body fat — only when the user actually
                    // entered a value during the onboarding body-fat step.
                    // Skipped when bodyFatPercentage is nil (the "No" branch).
                    if let bf = profile.bodyFatPercentage {
                        bodyFatStore.seedInitialBodyFatFromProfileIfEmpty(bf)
                    }
                }
                refreshWidgetSnapshot()
            }
        }
    }

    private func wireUpHealthKit() {
        guard UserDefaults.standard.bool(forKey: "healthKitEnabled") else { return }

        // Re-request authorization if new HealthKit types were added since last auth.
        // Backfill is idempotent (per-entry HealthKit existence check), so it's safe to call
        // in both branches without duplicating already-synced history.
        if healthKitManager.needsReauthorization {
            Task { [healthKitManager, foodStore] in
                _ = await healthKitManager.requestAuthorization()
                healthKitManager.backfillNutritionIfNeeded(
                    entries: foodStore.entries,
                    currentEntryIDs: { Set(foodStore.entries.map(\.id)) }
                )
                runBodyMeasurementBackfills()
            }
        } else {
            healthKitManager.backfillNutritionIfNeeded(
                entries: foodStore.entries,
                currentEntryIDs: { Set(foodStore.entries.map(\.id)) }
            )
            runBodyMeasurementBackfills()
        }

        healthKitManager.onBodyMeasurementsChanged = { [weightStore, bodyFatStore] weightKg, weightDate, weightFudaiID, heightCm, bodyFat, bodyFatDate, bodyFatFudaiID, dob, sex in
            // HealthKit fires this on its own background thread; stores are @MainActor.
            Task { @MainActor in
            guard var profile = UserProfile.load() else { return }
            var changed = false

            if let kg = weightKg, let date = weightDate {
                // If the HK sample was written by our app (has fudai_weight_id), never re-add
                // from the observer: either the entry still exists in the store (duplicate) or the
                // user just deleted it and the HK delete hasn't propagated yet (would resurrect it).
                // External HK samples (Apple Watch, scale, Health app) have no fudai_weight_id;
                // those we dedup by same-day + same-value.
                let shouldAdd: Bool
                if weightFudaiID != nil {
                    shouldAdd = false
                } else {
                    let calendar = Calendar.current
                    let alreadyLogged = weightStore.entries.contains {
                        calendar.isDate($0.date, inSameDayAs: date) && abs($0.weightKg - kg) < 0.01
                    }
                    shouldAdd = !alreadyLogged
                }
                if shouldAdd {
                    weightStore.addEntry(WeightEntry(date: date, weightKg: kg))
                }
                // Only sync profile.weightKg from the HK observer when the latest sample came
                // from OUTSIDE our app. For our own samples, WeightStore.addEntry / deleteEntry
                // already syncs profile — updating it here again can revert a just-made edit if
                // HK hasn't indexed the write yet and returns an older sample of ours.
                if weightFudaiID == nil, abs(profile.weightKg - kg) > 0.01 {
                    profile.weightKg = kg
                    changed = true
                }
            }
            if let cm = heightCm, abs(profile.heightCm - cm) > 0.1 {
                profile.heightCm = cm
                changed = true
            }
            if let bf = bodyFat, let date = bodyFatDate {
                // Same dedup discipline as weight: skip our own writes
                // (fudai_bodyfat_id present), and dedup external samples by
                // same-day + same-fraction so re-firing the observer can't
                // duplicate a smart-scale reading we already imported once.
                let shouldAdd: Bool
                if bodyFatFudaiID != nil {
                    shouldAdd = false
                } else {
                    let calendar = Calendar.current
                    let alreadyLogged = bodyFatStore.entries.contains {
                        calendar.isDate($0.date, inSameDayAs: date) && abs($0.bodyFatFraction - bf) < 0.001
                    }
                    shouldAdd = !alreadyLogged
                }
                if shouldAdd {
                    bodyFatStore.addEntry(BodyFatEntry(date: date, bodyFatFraction: bf))
                    // BodyFatStore.addEntry already syncs profile.bodyFatPercentage
                    // for any new entry, so no extra profile.save() needed here.
                } else if bodyFatFudaiID == nil,
                          profile.bodyFatPercentage == nil || abs((profile.bodyFatPercentage ?? 0) - bf) > 0.001 {
                    // External sample we already had (dedup hit) — but the
                    // profile cache somehow drifted. Realign without creating
                    // a duplicate entry. Skip when it's our own sample (HK
                    // may briefly return a stale write of ours during indexing).
                    profile.bodyFatPercentage = bf
                    changed = true
                }
            }
            if let d = dob {
                let calendar = Calendar.current
                if !calendar.isDate(profile.birthday, inSameDayAs: d) {
                    profile.birthday = d
                    changed = true
                }
            }
            if let s = sex {
                // Only sync when HealthKit gave us an actual male/female reading.
                // HKBiologicalSex.notSet (sim default + users who never set it
                // in Health) and .other should NOT overwrite the user's
                // onboarding-chosen gender — without this guard, the observer
                // silently flipped gender to "Other" right after onboarding
                // finished on the simulator since HK returns .notSet there.
                let mapped: Gender?
                switch s {
                case .male: mapped = .male
                case .female: mapped = .female
                default: mapped = nil
                }
                if let mapped, profile.gender != mapped {
                    profile.gender = mapped
                    changed = true
                }
            }
            if changed { profile.save() }
            } // Task @MainActor
        }

        healthKitManager.startBodyMeasurementObserver()

        weightStore.onEntryAdded = { [healthKitManager] entry in
            healthKitManager.writeWeight(for: entry)
        }

        weightStore.onEntryDeleted = { [healthKitManager] entryID in
            healthKitManager.deleteWeight(entryID: entryID)
        }

        bodyFatStore.onEntryAdded = { [healthKitManager] entry in
            healthKitManager.writeBodyFat(for: entry)
        }

        bodyFatStore.onEntryDeleted = { [healthKitManager] entryID in
            healthKitManager.deleteBodyFat(entryID: entryID)
        }

        foodStore.onEntryAdded = { [healthKitManager] entry in
            healthKitManager.writeNutrition(for: entry)
        }

        foodStore.onEntryDeleted = { [healthKitManager] entryID in
            healthKitManager.deleteNutrition(entryID: entryID)
        }

        foodStore.onEntryUpdated = { [healthKitManager] entry in
            healthKitManager.updateNutrition(for: entry)
        }
    }

    /// Pulls historical weight + body-fat samples out of HealthKit on first
    /// HK enable so the Progress chart starts populated for users who already
    /// have years of scale data in Apple Health (Withings, Renpho, Apple
    /// Watch, manual entries, etc.). One-shot per typesVersion — see
    /// HealthKitManager.{weight,bodyFat}BackfillVersionKey.
    private func runBodyMeasurementBackfills() {
        healthKitManager.backfillWeightFromHealthKitIfNeeded(
            existing: { [weightStore] in weightStore.entries },
            importBatch: { [weightStore] entries in weightStore.importExternalEntries(entries) }
        )
        healthKitManager.backfillBodyFatFromHealthKitIfNeeded(
            existing: { [bodyFatStore] in bodyFatStore.entries },
            importBatch: { [bodyFatStore] entries in bodyFatStore.importExternalEntries(entries) }
        )
    }

    private func wireUpFoodStoreCallback() {
        foodStore.onEntriesChanged = { [notificationManager, foodStore, weightStore, bodyFatStore] in
            if UserDefaults.standard.bool(forKey: "notificationsEnabled"),
               let profile = UserProfile.load() {
                notificationManager.rescheduleDataDependentNotifications(
                    foodStore: foodStore, weightStore: weightStore, bodyFatStore: bodyFatStore, profile: profile
                )
            }
            if let profile = UserProfile.load() {
                WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
            }
        }
    }

    private func refreshWidgetSnapshot() {
        guard let profile = UserProfile.load() else {
            // No profile — onboarding not complete OR data was wiped. Clear the
            // shared snapshot so the widget shows an empty day instead of stale
            // numbers from a previous profile.
            WidgetSnapshot.clear()
            WidgetCenter.shared.reloadAllTimelines()
            return
        }
        WidgetSnapshotWriter.publish(foods: foodStore.entries, profile: profile)
    }

    @MainActor
    private func refreshHealthEnergyGoalsIfNeeded() -> Bool {
        guard !isAutoRefreshingHealthEnergyGoals else { return false }
        guard UserDefaults.standard.bool(forKey: HealthEnergyGoalSettings.enabledKey) else { return false }
        guard UserDefaults.standard.bool(forKey: "healthKitEnabled") else { return false }
        guard HealthEnergyGoalSettings.shouldAutoRefreshToday() else { return false }
        guard UserProfile.load() != nil else { return false }
        let usesMetricUnits = useMetric

        isAutoRefreshingHealthEnergyGoals = true
        HealthEnergyGoalSettings.markAutoRefreshAttemptedToday()

        Task {
            defer {
                Task { @MainActor in
                    isAutoRefreshingHealthEnergyGoals = false
                    refreshAdaptiveGoalsIfNeeded()
                }
            }

            guard var profile = UserProfile.load() else { return }
            guard let summary = await healthKitManager.fetchRecentEnergySummary(days: 14) else { return }

            do {
                let suggestion = try await GeminiService.suggestHealthEnergyGoals(
                    profile: profile,
                    energy: summary,
                    useMetric: usesMetricUnits
                )
                profile.customCalories = suggestion.calories
                profile.customProtein = nil
                profile.customCarbs = nil
                profile.customFat = nil
                profile.autoBalanceMacro = nil
                profile.save()
            } catch {
                // Daily auto-refresh is opportunistic. Manual Refresh in Settings
                // remains available for visible errors and retries.
            }
        }
        return true
    }

    @MainActor
    private func refreshAdaptiveGoalsIfNeeded() {
        guard !isAutoRefreshingAdaptiveGoals else { return }
        guard UserDefaults.standard.bool(forKey: AdaptiveGoalSettings.enabledKey) else { return }
        guard AdaptiveGoalSettings.shouldCheckThisWeek() else { return }
        guard let profile = UserProfile.load() else { return }

        isAutoRefreshingAdaptiveGoals = true
        defer { isAutoRefreshingAdaptiveGoals = false }

        let result = AdaptiveGoalService.apply(
            profile: profile,
            weights: weightStore.entries,
            foods: foodStore.entries
        )
        AdaptiveGoalSettings.markCheckedToday()
        if result.changed {
            AdaptiveGoalSettings.savePreviousTargetsIfNeeded(from: profile)
            result.profile.save()
        }
    }
}
