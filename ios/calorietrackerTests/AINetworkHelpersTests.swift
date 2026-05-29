import Foundation
import Testing
@testable import calorietracker

/// Tests the shared HTTP-error parsing now used by ChatService, GeminiService,
/// and SpeechService. A regression here breaks user-facing error messages in
/// all three, so the three supported JSON shapes + the status→message mapping
/// are pinned down.
struct AINetworkHelpersTests {

    private func data(_ s: String) -> Data { Data(s.utf8) }

    // MARK: - parseErrorMessage

    @Test func parsesNestedOpenAIGeminiShape() {
        let d = data(#"{"error": {"message": "Invalid API key", "code": 401}}"#)
        #expect(AINetworkHelpers.parseErrorMessage(from: d) == "Invalid API key")
    }

    @Test func parsesFlatErrorString() {
        let d = data(#"{"error": "Quota exceeded"}"#)
        #expect(AINetworkHelpers.parseErrorMessage(from: d) == "Quota exceeded")
    }

    @Test func parsesAssemblyAIErrMsg() {
        let d = data(#"{"err_msg": "Upload failed"}"#)
        #expect(AINetworkHelpers.parseErrorMessage(from: d) == "Upload failed")
    }

    @Test func returnsNilForUnrecognizedJSON() {
        #expect(AINetworkHelpers.parseErrorMessage(from: data(#"{"foo": "bar"}"#)) == nil)
    }

    @Test func returnsNilForNonJSON() {
        #expect(AINetworkHelpers.parseErrorMessage(from: data("not json at all")) == nil)
    }

    @Test func returnsNilForEmptyData() {
        #expect(AINetworkHelpers.parseErrorMessage(from: Data()) == nil)
    }

    @Test func prefersNestedMessageOverImplausibleShapes() {
        // Nested form is checked first; a present {error:{message}} wins.
        let d = data(#"{"error": {"message": "boom"}, "err_msg": "ignored"}"#)
        #expect(AINetworkHelpers.parseErrorMessage(from: d) == "boom")
    }

    // MARK: - friendlyMessage

    @Test func overloadedStatusesGetRetryGuidance() {
        for status in [503, 529] {
            let msg = AINetworkHelpers.friendlyMessage(for: status, raw: "raw")
            #expect(msg.contains("overloaded"))
        }
    }

    @Test func rateLimitMentionsWaiting() {
        #expect(AINetworkHelpers.friendlyMessage(for: 429, raw: "raw").localizedCaseInsensitiveContains("rate limit"))
    }

    @Test func authErrorsTellUserToRepasteKey() {
        for status in [401, 403] {
            let msg = AINetworkHelpers.friendlyMessage(for: status, raw: "raw")
            #expect(msg.localizedCaseInsensitiveContains("key"))
        }
    }

    @Test func unmappedStatusFallsBackToRawMessage() {
        #expect(AINetworkHelpers.friendlyMessage(for: 418, raw: "I'm a teapot") == "I'm a teapot")
    }
}
