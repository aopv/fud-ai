import Foundation
import Testing
@testable import calorietracker

/// Tests the exactly-once invariant for Watch voice-log requests: the Watch may
/// re-send the same requestID (it polls when the AI call outlives the WCSession
/// reply timeout), and the iPhone must never log the food twice.
struct VoiceLogDedupCacheTests {

    private let okPayload: [String: VoiceLogValue] = [
        "name": .string("Chicken breast"),
        "calories": .int(165),
        "protein": .double(31.0),
    ]

    // MARK: - Core state machine

    @Test func firstSightOfRequestStartsProcessing() {
        var cache = VoiceLogDedupCache()
        #expect(cache.lookup(requestID: "A") == .startProcessing)
        // And it's now marked in-flight so a concurrent poll won't re-process.
        #expect(cache.inFlightCount == 1)
    }

    @Test func pollWhileInFlightReturnsInFlightNotSecondProcessing() {
        var cache = VoiceLogDedupCache()
        _ = cache.lookup(requestID: "A")          // first delivery → startProcessing
        // The Watch's reply timed out and it re-sent the same requestID:
        #expect(cache.lookup(requestID: "A") == .inFlight)
        #expect(cache.lookup(requestID: "A") == .inFlight)
        // Still only one analysis was ever started.
        #expect(cache.inFlightCount == 1)
    }

    @Test func afterCompletePollsReturnCachedResult() {
        var cache = VoiceLogDedupCache()
        _ = cache.lookup(requestID: "A")
        cache.complete(requestID: "A", payload: okPayload)

        #expect(cache.lookup(requestID: "A") == .cached(okPayload))
        // A late poll gets the same cached payload — still exactly one log.
        #expect(cache.lookup(requestID: "A") == .cached(okPayload))
        #expect(cache.inFlightCount == 0)
    }

    @Test func completeClearsInFlight() {
        var cache = VoiceLogDedupCache()
        _ = cache.lookup(requestID: "A")
        #expect(cache.inFlightCount == 1)
        cache.complete(requestID: "A", payload: okPayload)
        #expect(cache.inFlightCount == 0)
        #expect(cache.cachedCount == 1)
    }

    @Test func distinctRequestsAreIndependent() {
        var cache = VoiceLogDedupCache()
        #expect(cache.lookup(requestID: "A") == .startProcessing)
        #expect(cache.lookup(requestID: "B") == .startProcessing)
        cache.complete(requestID: "A", payload: okPayload)
        // B is still processing; A is cached.
        #expect(cache.lookup(requestID: "B") == .inFlight)
        #expect(cache.lookup(requestID: "A") == .cached(okPayload))
    }

    @Test func errorPayloadIsCachedToo() {
        var cache = VoiceLogDedupCache()
        _ = cache.lookup(requestID: "A")
        let err: [String: VoiceLogValue] = ["error": .string("network down")]
        cache.complete(requestID: "A", payload: err)
        #expect(cache.lookup(requestID: "A") == .cached(err))
    }

    // MARK: - Bounded eviction

    @Test func evictsOldestBeyondCapacity() {
        var cache = VoiceLogDedupCache(maxResults: 2)
        for id in ["A", "B", "C"] {
            _ = cache.lookup(requestID: id)
            cache.complete(requestID: id, payload: okPayload)
        }
        // Capacity 2 → oldest "A" was evicted, so a late poll for A would be
        // treated as a brand-new request rather than served from cache.
        #expect(cache.cachedCount == 2)
        #expect(cache.lookup(requestID: "A") == .startProcessing)
        #expect(cache.lookup(requestID: "B") == .cached(okPayload))
        #expect(cache.lookup(requestID: "C") == .cached(okPayload))
    }

    @Test func completeTwiceDoesNotCorruptOrdering() {
        var cache = VoiceLogDedupCache(maxResults: 2)
        _ = cache.lookup(requestID: "A")
        cache.complete(requestID: "A", payload: okPayload)
        // A duplicate completion (e.g. a stray late callback) must not push A's
        // ordering twice and silently evict a still-valid neighbour.
        cache.complete(requestID: "A", payload: okPayload)
        _ = cache.lookup(requestID: "B")
        cache.complete(requestID: "B", payload: okPayload)
        #expect(cache.lookup(requestID: "A") == .cached(okPayload))
        #expect(cache.lookup(requestID: "B") == .cached(okPayload))
    }

    // MARK: - Payload bridging

    @Test func payloadBridgesToWCSessionMessageShape() {
        let message = okPayload.asMessage
        #expect(message["name"] as? String == "Chicken breast")
        #expect(message["calories"] as? Int == 165)
        #expect(message["protein"] as? Double == 31.0)
    }
}
