import Foundation
import UserNotifications

@Observable
class NotificationManager {
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Meal Reminders (repeating daily)

    func scheduleMealReminders(
        breakfastEnabled: Bool, breakfastHour: Int, breakfastMinute: Int,
        lunchEnabled: Bool, lunchHour: Int, lunchMinute: Int,
        dinnerEnabled: Bool, dinnerHour: Int, dinnerMinute: Int
    ) {
        let center = UNUserNotificationCenter.current()

        // Cancel existing meal reminders
        center.removePendingNotificationRequests(withIdentifiers: [
            "meal.breakfast", "meal.lunch", "meal.dinner"
        ])

        if breakfastEnabled {
            scheduleRepeatingMeal(
                id: "meal.breakfast",
                title: "Breakfast Time",
                body: "Don't forget to log your breakfast!",
                hour: breakfastHour, minute: breakfastMinute
            )
        }

        if lunchEnabled {
            scheduleRepeatingMeal(
                id: "meal.lunch",
                title: "Lunch Time",
                body: "Snap a photo to keep tracking!",
                hour: lunchHour, minute: lunchMinute
            )
        }

        if dinnerEnabled {
            scheduleRepeatingMeal(
                id: "meal.dinner",
                title: "Dinner Time",
                body: "Log your dinner to stay on track!",
                hour: dinnerHour, minute: dinnerMinute
            )
        }
    }

    private func scheduleRepeatingMeal(id: String, title: String, body: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.filterCriteria = FudAIFocusFilterCriteria.mealReminder

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Water Reminder (repeating daily)

    func scheduleWaterReminder(enabled: Bool, hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["water.reminder"])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Hydrate"
        content.body = "Have some water and log it in Fud AI."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        center.add(UNNotificationRequest(identifier: "water.reminder", content: content, trigger: trigger))
    }

    // MARK: - Streak Reminder (one-shot, rescheduled on foreground/log)

    func scheduleStreakReminder(enabled: Bool, hour: Int, minute: Int, hasLoggedToday: Bool, currentStreak: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["smart.streak"])

        guard enabled, !hasLoggedToday, currentStreak > 0 else { return }

        // Only schedule if the time hasn't passed yet today
        let now = Date()
        let calendar = Calendar.current
        guard let fireDate = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        ), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Don't Break Your \(currentStreak)-Day Streak!"
        content.body = "Log something before the day ends."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "smart.streak", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Daily Summary (one-shot, rescheduled on foreground/log)

    func scheduleDailySummary(enabled: Bool, hour: Int, minute: Int, todayCalories: Int, calorieGoal: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["smart.summary"])

        guard enabled else { return }

        let now = Date()
        let calendar = Calendar.current
        guard let fireDate = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        ), fireDate > now else { return }

        let remaining = max(0, calorieGoal - todayCalories)
        let content = UNMutableNotificationContent()
        content.title = "Daily Summary"
        content.body = "You ate \(todayCalories) of \(calorieGoal) kcal today. \(remaining) remaining!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "smart.summary", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Weight Log Reminder (one-shot, rescheduled on foreground/log)

    /// Daily nudge to step on the scale. Skips firing if the user has already
    /// logged a weight today — same "smart" pattern as the streak reminder so
    /// users who weigh in early don't get a redundant evening ping.
    func scheduleWeightLogReminder(enabled: Bool, hour: Int, minute: Int, hasLoggedWeightToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["smart.weight"])

        guard enabled, !hasLoggedWeightToday else { return }

        let now = Date()
        let calendar = Calendar.current
        guard let fireDate = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        ), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time to Weigh In"
        content.body = "Log today's weight to keep your progress chart accurate."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "smart.weight", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Body Fat Log Reminder (one-shot, rescheduled on foreground/log)

    /// Daily nudge to log a body-fat reading. Skips firing if the user has
    /// already logged one today. Most users don't measure body fat daily, so
    /// this defaults OFF — users opt in via Settings → Notifications.
    func scheduleBodyFatLogReminder(enabled: Bool, hour: Int, minute: Int, hasLoggedBodyFatToday: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["smart.bodyfat"])

        guard enabled, !hasLoggedBodyFatToday else { return }

        let now = Date()
        let calendar = Calendar.current
        guard let fireDate = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        ), fireDate > now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Body Fat Check-In"
        content.body = "Log today's body fat % to track your composition trend."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: "smart.bodyfat", content: content, trigger: trigger)
        center.add(request)
    }

    // MARK: - Convenience: Reschedule Data-Dependent Notifications

    func rescheduleDataDependentNotifications(foodStore: FoodStore, weightStore: WeightStore, bodyFatStore: BodyFatStore, profile: UserProfile) {
        let streakEnabled = UserDefaults.standard.object(forKey: "streakReminderEnabled") as? Bool ?? true
        let streakHour = UserDefaults.standard.object(forKey: "streakReminderHour") as? Int ?? 21
        let streakMinute = UserDefaults.standard.object(forKey: "streakReminderMinute") as? Int ?? 0

        let summaryEnabled = UserDefaults.standard.object(forKey: "dailySummaryEnabled") as? Bool ?? true
        let summaryHour = UserDefaults.standard.object(forKey: "dailySummaryHour") as? Int ?? 20
        let summaryMinute = UserDefaults.standard.object(forKey: "dailySummaryMinute") as? Int ?? 0

        let weightLogEnabled = UserDefaults.standard.object(forKey: "weightLogReminderEnabled") as? Bool ?? true
        let weightLogHour = UserDefaults.standard.object(forKey: "weightLogReminderHour") as? Int ?? 8
        let weightLogMinute = UserDefaults.standard.object(forKey: "weightLogReminderMinute") as? Int ?? 0

        // Body-fat opt-in default OFF — most users don't measure daily, so
        // a daily ping would feel noisy. Users with a daily smart-scale
        // routine can flip it on in Settings → Notifications.
        let bodyFatLogEnabled = UserDefaults.standard.object(forKey: "bodyFatLogReminderEnabled") as? Bool ?? false
        let bodyFatLogHour = UserDefaults.standard.object(forKey: "bodyFatLogReminderHour") as? Int ?? 8
        let bodyFatLogMinute = UserDefaults.standard.object(forKey: "bodyFatLogReminderMinute") as? Int ?? 0

        let hasLoggedToday = !foodStore.todayEntries.isEmpty
        let currentStreak = computeCurrentStreak(foodStore: foodStore)

        let calendar = Calendar.current
        let hasLoggedWeightToday = weightStore.entries.contains { calendar.isDateInToday($0.date) }
        let hasLoggedBodyFatToday = bodyFatStore.entries.contains { calendar.isDateInToday($0.date) }

        scheduleStreakReminder(
            enabled: streakEnabled,
            hour: streakHour, minute: streakMinute,
            hasLoggedToday: hasLoggedToday,
            currentStreak: currentStreak
        )

        scheduleDailySummary(
            enabled: summaryEnabled,
            hour: summaryHour, minute: summaryMinute,
            todayCalories: foodStore.todayCalories,
            calorieGoal: profile.effectiveCalories
        )

        scheduleWeightLogReminder(
            enabled: weightLogEnabled,
            hour: weightLogHour, minute: weightLogMinute,
            hasLoggedWeightToday: hasLoggedWeightToday
        )

        scheduleBodyFatLogReminder(
            enabled: bodyFatLogEnabled,
            hour: bodyFatLogHour, minute: bodyFatLogMinute,
            hasLoggedBodyFatToday: hasLoggedBodyFatToday
        )
    }

    // MARK: - App Update Available (one-shot, de-duped per version)

    /// Identifier used so the tap handler can recognize an update notification.
    static let appUpdateNotificationID = "app.update"

    /// Fire a local notification telling the user a new App Store version is out. Tapping it opens
    /// the store (handled in AppDelegate). Gated by the "App Updates" toggle (default on), only when
    /// notifications are authorized, and de-duped so a given version notifies at most once even
    /// though the update check runs on every launch.
    func notifyUpdateAvailable(version: String, url: URL) async {
        let enabled = UserDefaults.standard.object(forKey: "appUpdateNotificationsEnabled") as? Bool ?? true
        guard enabled else { return }
        guard UserDefaults.standard.string(forKey: "lastNotifiedAppUpdateVersion") != version else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "Fud AI \(version) is ready. Tap to update."
        content.sound = .default
        content.userInfo = ["updateURL": url.absoluteString]

        let request = UNNotificationRequest(identifier: Self.appUpdateNotificationID, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(version, forKey: "lastNotifiedAppUpdateVersion")
        } catch {
            // Best-effort; nothing to recover.
        }
    }

    // MARK: - Cancel All

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Streak Computation

    private func computeCurrentStreak(foodStore: FoodStore) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var count = 0
        var day = today
        while true {
            let dayEntries = foodStore.entries(for: day)
            if dayEntries.isEmpty { break }
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }
}
