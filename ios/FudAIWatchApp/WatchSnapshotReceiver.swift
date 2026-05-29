import Combine
import Foundation
import WatchConnectivity
import WidgetKit

final class WatchSnapshotReceiver: NSObject, ObservableObject, WCSessionDelegate {
    /// Single shared instance so the WCSession delegate set up at app launch (by
    /// WatchAppDelegate) and the one the UI observes are the *same* object —
    /// WCSession.default has only one delegate slot, so two instances would fight.
    static let shared = WatchSnapshotReceiver()

    @Published private(set) var snapshot: WidgetSnapshot = WidgetSnapshot.read() ?? .empty

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        receive(context: session.receivedApplicationContext)
    }

    func refreshFromDisk() {
        snapshot = WidgetSnapshot.read() ?? .empty
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        receive(context: session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        receive(context: applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        receive(context: userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receive(context: message)
    }

    private func receive(context: [String: Any]) {
        guard let data = context[WidgetSnapshot.watchPayloadKey] as? Data,
              let incomingSnapshot = WidgetSnapshot.decodePayload(data)
        else { return }

        let normalizedSnapshot = incomingSnapshot.normalizedForToday()

        DispatchQueue.main.async {
            WidgetSnapshot.write(normalizedSnapshot)
            self.snapshot = normalizedSnapshot
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
