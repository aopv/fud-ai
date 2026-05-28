import BackgroundTasks
import Foundation
import WidgetKit

/// Manages BGTask registration and scheduling.
/// Background widget refresh keeps the widget current even when the app hasn't been opened.
enum BackgroundTaskManager {
    static let widgetRefreshTaskID = "ai.fud.widget-refresh"

    /// Call once in `application(_:didFinishLaunchingWithOptions:)` / App.init
    /// — must be called before the app finishes launching.
    static func registerAll() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: widgetRefreshTaskID, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleWidgetRefresh(task: refreshTask)
        }
    }

    /// Schedule the next background widget refresh.
    /// Call this on every scene-background transition so the chain never breaks.
    static func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: widgetRefreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("[BGTask] scheduleWidgetRefresh failed: \(error)")
        }
    }

    // MARK: - Private

    private static func handleWidgetRefresh(task: BGAppRefreshTask) {
        scheduleWidgetRefresh()

        task.expirationHandler = { [weak task] in task?.setTaskCompleted(success: false) }

        if let profile = UserProfile.load() {
            let foods = FoodEntryStorage.loadAll()
            WidgetSnapshotWriter.publish(foods: foods, profile: profile)
        }
        WidgetCenter.shared.reloadAllTimelines()
        task.setTaskCompleted(success: true)
    }
}
