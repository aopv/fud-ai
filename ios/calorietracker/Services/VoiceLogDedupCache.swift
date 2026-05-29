import Foundation

/// Idempotency bookkeeping for Watch voice-log requests.
///
/// The Watch sends a `requestID` with each utterance and may re-send the *same*
/// requestID (the AI call can outlive the WCSession reply timeout, so the Watch
/// polls). This type decides, for a given requestID, whether the iPhone should:
///   - return an already-computed result (`.cached`) — the analysis finished,
///   - tell the Watch to keep waiting (`.inFlight`) — analysis is in progress,
///   - or start the analysis itself (`.startProcessing`) — first time seen.
///
/// This guarantees the food is logged **exactly once** per requestID even under
/// retries/polls. It is *not* internally synchronized — callers must serialize
/// access (WatchSnapshotSync does this on its `voiceQueue`). Keeping it sync-free
/// makes the idempotency invariant unit-testable without threads.
struct VoiceLogDedupCache {
    enum Lookup: Equatable {
        /// Analysis already finished for this requestID — reply with this payload.
        case cached([String: VoiceLogValue])
        /// Analysis is currently running for this requestID — tell the Watch to wait.
        case inFlight
        /// First time we've seen this requestID — caller should run the analysis.
        case startProcessing
    }

    private var inFlight: Set<String> = []
    private var results: [String: [String: VoiceLogValue]] = [:]
    /// FIFO insertion order of completed requestIDs, for bounded eviction.
    private var order: [String] = []
    let maxResults: Int

    init(maxResults: Int = 20) {
        self.maxResults = maxResults
    }

    /// Classify a requestID and, when it's new, atomically mark it in-flight so a
    /// concurrent poll for the same ID gets `.inFlight` rather than starting a
    /// second analysis. Mutating + caller-serialized = no double-log.
    mutating func lookup(requestID: String) -> Lookup {
        if let cached = results[requestID] {
            return .cached(cached)
        }
        if inFlight.contains(requestID) {
            return .inFlight
        }
        inFlight.insert(requestID)
        return .startProcessing
    }

    /// Record the finished result for a requestID and clear its in-flight mark.
    /// Evicts the oldest result once `maxResults` is exceeded so the cache stays bounded.
    mutating func complete(requestID: String, payload: [String: VoiceLogValue]) {
        inFlight.remove(requestID)
        // Don't double-count order if complete() is somehow called twice.
        if results[requestID] == nil {
            order.append(requestID)
        }
        results[requestID] = payload
        if order.count > maxResults {
            let evicted = order.removeFirst()
            results.removeValue(forKey: evicted)
        }
    }

    // Test/introspection helpers (internal — visible via @testable).
    var inFlightCount: Int { inFlight.count }
    var cachedCount: Int { results.count }
}

/// A small Equatable/Sendable wrapper for the reply payload values the Watch
/// round-trip uses (`name`/`error` strings, `calories` int, `protein` double,
/// `status` string). Avoids `[String: Any]`, which isn't Equatable or Sendable
/// and so can't be unit-tested or safely crossed actor boundaries.
enum VoiceLogValue: Equatable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)

    /// Bridge to the `[String: Any]` shape WCSession's replyHandler expects.
    var anyValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        }
    }
}

extension Dictionary where Key == String, Value == VoiceLogValue {
    /// Convert to the `[String: Any]` payload WCSession sends back to the Watch.
    var asMessage: [String: Any] {
        mapValues { $0.anyValue }
    }
}
