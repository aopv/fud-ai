import Foundation
import WatchConnectivity

/// Mirrors the latest nutrition snapshot to Apple Watch. The watch app and its
/// complications live on the watch, so they cannot read the iPhone App Group
/// container directly.
final class WatchSnapshotSync: NSObject, WCSessionDelegate {
    static let shared = WatchSnapshotSync()

    private var pendingSnapshot: WidgetSnapshot?
    private var lastQueuedContent: QueuedSnapshotContent?

    private override init() {
        super.init()
    }

    func send(_ snapshot: WidgetSnapshot) {
        pendingSnapshot = snapshot

        guard let payload = snapshot.payloadData,
              let session = activatedSession()
        else { return }

        deliver(snapshot, payload: payload, through: session)
    }

    private func activatedSession() -> WCSession? {
        guard WCSession.isSupported() else { return nil }

        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState != .activated {
            session.activate()
            return nil
        }

        guard session.activationState == .activated else { return nil }

        // On real devices require a paired watch; simulators always report isPaired = false
        // for directly-installed watch apps so we skip that gate in the simulator.
        #if !targetEnvironment(simulator)
        guard session.isPaired, session.isWatchAppInstalled else { return nil }
        #endif

        return session
    }

    private func deliver(_ snapshot: WidgetSnapshot, payload: Data, through session: WCSession) {
        let context = [WidgetSnapshot.watchPayloadKey: payload]

        // 1. Always update the application context (last-write-wins, survives app kills).
        try? session.updateApplicationContext(context)

        // 2. When the Watch app is in the foreground, send an immediate message.
        //    This is the only path that delivers synchronously while both apps are active.
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil, errorHandler: nil)
            return
        }

        // 3. When not reachable (Watch app in background / not running), queue a
        //    reliable transferUserInfo so the Watch gets it when it next wakes up.
        let content = QueuedSnapshotContent(snapshot)
        guard lastQueuedContent != content else { return }
        lastQueuedContent = content
        session.transferUserInfo(context)
        if session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo(context)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, let pendingSnapshot else { return }
        send(pendingSnapshot)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    private struct QueuedSnapshotContent: Equatable {
        let dayStart: Date
        let calories: Int
        let calorieGoal: Int
        let protein: Double
        let proteinGoal: Int
        let carbs: Double
        let carbsGoal: Int
        let fat: Double
        let fatGoal: Int
        let homeNutrients: [WidgetNutrientValue]?
        let themeStartHex: UInt?
        let themeEndHex: UInt?

        init(_ snapshot: WidgetSnapshot) {
            dayStart = snapshot.dayStart
            calories = snapshot.calories
            calorieGoal = snapshot.calorieGoal
            protein = snapshot.protein
            proteinGoal = snapshot.proteinGoal
            carbs = snapshot.carbs
            carbsGoal = snapshot.carbsGoal
            fat = snapshot.fat
            fatGoal = snapshot.fatGoal
            homeNutrients = snapshot.homeNutrients
            themeStartHex = snapshot.themeStartHex
            themeEndHex = snapshot.themeEndHex
        }
    }
}
