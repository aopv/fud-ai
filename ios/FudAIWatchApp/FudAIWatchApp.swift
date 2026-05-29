import SwiftUI
import WatchKit

/// Registers the WatchConnectivity delegate at process launch — including the
/// background launches watchOS makes to deliver `transferCurrentComplicationUserInfo`
/// / `updateApplicationContext` payloads from the iPhone. Without this, the delegate
/// only existed once the SwiftUI scene rendered (i.e. after the user opened the app),
/// so iPhone-side food logs didn't reach the watch-face complication until then.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        // Touching `.shared` instantiates the receiver and activates its WCSession
        // delegate, so background-delivered snapshots trigger reloadAllTimelines().
        WatchSnapshotReceiver.shared.activate()
    }
}

@main
struct FudAIWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var receiver = WatchSnapshotReceiver.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchNutritionView()
                .environmentObject(receiver)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                receiver.activate()
            }
        }
    }
}
