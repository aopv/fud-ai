import Combine
import Foundation
import WatchConnectivity
import WatchKit

enum VoiceLogState: Equatable {
    case idle
    case processing
    case success(name: String, calories: Int, protein: Double)
    case error(String)
}

/// Sends a dictated food description to the iPhone for AI analysis + logging.
/// watchOS has no Speech framework, so transcription is handled by the system
/// dictation input controller in the view; this type only owns the iPhone round-trip.
@MainActor
final class WatchVoiceLogger: NSObject, ObservableObject {
    @Published var state: VoiceLogState = .idle

    // Identifies the current utterance so the iPhone can log it exactly once even
    // if the reply times out and we have to poll for the result. reset() abandons it.
    private var pendingRequestID: String?
    private var pendingTranscript: String?
    private var pollAttempts = 0
    private let maxPollAttempts = 8

    func submit(transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        state = .processing
        sendToiPhone(transcript: trimmed)
    }

    func reset() {
        clearPending()
        state = .idle
    }

    // MARK: - iPhone round-trip

    private func sendToiPhone(transcript: String) {
        let requestID = UUID().uuidString
        pendingRequestID = requestID
        pendingTranscript = transcript
        pollAttempts = 0
        deliver(requestID: requestID, transcript: transcript)
    }

    private func deliver(requestID: String, transcript: String) {
        guard WCSession.isSupported() else {
            state = .error("Watch Connectivity not supported")
            clearPending()
            return
        }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else {
            state = .error("iPhone not reachable. Open the Fud AI app on your iPhone.")
            clearPending()
            return
        }

        session.sendMessage(["watchVoiceLog": transcript, "requestID": requestID]) { [weak self] reply in
            Task { @MainActor in
                self?.handleReply(reply, for: requestID)
            }
        } errorHandler: { [weak self] error in
            Task { @MainActor in
                self?.handleSendError(error, for: requestID)
            }
        }
    }

    private func handleReply(_ reply: [String: Any], for requestID: String) {
        // Ignore replies for an utterance the user has already abandoned.
        guard requestID == pendingRequestID else { return }

        if let status = reply["status"] as? String, status == "processing" {
            schedulePoll()
            return
        }
        if let errorMsg = reply["error"] as? String {
            state = .error(errorMsg)
            clearPending()
            return
        }
        if let name = reply["name"] as? String,
           let calories = reply["calories"] as? Int,
           let protein = reply["protein"] as? Double {
            WKInterfaceDevice.current().play(.success)
            state = .success(name: name, calories: calories, protein: protein)
            clearPending()
            return
        }
        state = .error("Unexpected response from iPhone")
        clearPending()
    }

    private func handleSendError(_ error: Error, for requestID: String) {
        guard requestID == pendingRequestID else { return }
        // The reply likely timed out while the iPhone is still analyzing. Poll for
        // the result instead of erroring — the iPhone dedupes by requestID so this
        // never logs the food twice.
        if pollAttempts < maxPollAttempts {
            schedulePoll()
        } else {
            state = .error(error.localizedDescription)
            clearPending()
        }
    }

    private func schedulePoll() {
        guard let requestID = pendingRequestID, let transcript = pendingTranscript else { return }
        guard pollAttempts < maxPollAttempts else {
            state = .error("Timed out waiting for iPhone")
            clearPending()
            return
        }
        pollAttempts += 1
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard let self, self.pendingRequestID == requestID else { return }
            self.deliver(requestID: requestID, transcript: transcript)
        }
    }

    private func clearPending() {
        pendingRequestID = nil
        pendingTranscript = nil
        pollAttempts = 0
    }
}
