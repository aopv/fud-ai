import Foundation
import WatchConnectivity

/// Mirrors the latest nutrition snapshot to Apple Watch. The watch app and its
/// complications live on the watch, so they cannot read the iPhone App Group
/// container directly.
final class WatchSnapshotSync: NSObject, WCSessionDelegate {
    static let shared = WatchSnapshotSync()

    private var pendingSnapshot: WidgetSnapshot?
    private var lastQueuedContent: QueuedSnapshotContent?

    // Voice-log dedup state. Touched only on `voiceQueue` so the read-check-insert
    // inside `dedup.lookup` can't race when the Watch polls concurrently.
    private let voiceQueue = DispatchQueue(label: "ai.fud.watchVoiceLog")
    private var dedup = VoiceLogDedupCache()

    private override init() {
        super.init()
    }

    /// Called at app launch so the WCSession delegate is registered before any message arrives.
    func startListening() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.delegate == nil {
            session.delegate = self
        }
        if session.activationState == .notActivated {
            session.activate()
        }
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
        guard activationState == .activated else { return }
        // WCSession delegate fires on a background thread; pendingSnapshot is only
        // mutated from the main thread via send(), so dispatch there to avoid a race.
        DispatchQueue.main.async { [weak self] in
            guard let self, let pendingSnapshot = self.pendingSnapshot else { return }
            self.send(pendingSnapshot)
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let transcript = message["watchVoiceLog"] as? String,
              let requestID = message["requestID"] as? String else {
            replyHandler(["error": "Invalid request"])
            return
        }

        voiceQueue.async { [weak self] in
            guard let self else {
                replyHandler(["error": "Unavailable"])
                return
            }

            switch self.dedup.lookup(requestID: requestID) {
            case .cached(let payload):
                // Already finished — return the cached result (idempotent poll).
                replyHandler(payload.asMessage)
            case .inFlight:
                // Still analyzing this exact utterance — tell the Watch to keep
                // waiting instead of starting a second analysis (double-log).
                replyHandler(["status": "processing"])
            case .startProcessing:
                Task {
                    let payload = await self.process(transcript: transcript)
                    self.voiceQueue.async {
                        self.dedup.complete(requestID: requestID, payload: payload)
                        // May be a no-op if the original reply already timed out;
                        // the Watch picks up the result via a subsequent poll.
                        replyHandler(payload.asMessage)
                    }
                }
            }
        }
    }

    /// Analyzes the transcript and logs the food exactly once. Returns the reply payload.
    private func process(transcript: String) async -> [String: VoiceLogValue] {
        do {
            let analysis = try await GeminiService.analyzeTextInput(description: transcript)
            let entry = FoodEntry(
                name: analysis.name,
                calories: analysis.calories,
                protein: analysis.protein,
                carbs: analysis.carbs,
                fat: analysis.fat,
                timestamp: .now,
                emoji: analysis.emoji,
                source: .textInput,
                mealType: .currentMeal,
                sugar: analysis.sugar,
                fiber: analysis.fiber,
                saturatedFat: analysis.saturatedFat,
                sodium: analysis.sodium,
                servingSizeGrams: analysis.servingSizeGrams,
                servingUnitOptions: analysis.servingUnitOptions,
                selectedServingUnit: analysis.selectedServingUnit,
                selectedServingQuantity: analysis.selectedServingQuantity
            )
            // Append on the main actor so we serialize with FoodStore's own
            // read-modify-write of the foodEntries UserDefaults blob, then push a
            // fresh widget/complication snapshot straight back to the Watch.
            //
            // We publish here directly rather than relying on the Darwin-notification
            // → FoodStore.reloadFromExternalChange → publish hop: that hop only fires
            // when a FoodStore instance is alive and observing, which isn't guaranteed
            // during the brief background WCSession wake that handles this message. Not
            // publishing here is what made the Watch complication lag after voice logs.
            await MainActor.run {
                FoodEntryStorage.append(entry)
                if let profile = UserProfile.load() {
                    WidgetSnapshotWriter.publish(foods: FoodEntryStorage.loadAll(), profile: profile)
                }
            }
            return [
                "name": .string(analysis.name),
                "calories": .int(analysis.calories),
                "protein": .double(analysis.protein)
            ]
        } catch {
            return ["error": .string(error.localizedDescription)]
        }
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
        }
    }
}
