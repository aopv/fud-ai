import Foundation
import Testing
@testable import calorietracker

struct AnthropicResponseParsingTests {
    @Test func findsTextAfterReasoningBlock() throws {
        let data = Data(#"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":"Checking nutrients"},{"type":"text","text":"  {\"name\":\"Apple\"}  "}]}"#.utf8)

        let response = try GeminiService.parseAnthropicTextResponse(from: data)

        #expect(response.text == #"{"name":"Apple"}"#)
        #expect(!response.wasTruncated)
    }

    @Test func reportsTruncationEvenWhenNoTextBlockExists() throws {
        let data = Data(#"{"stop_reason":"max_tokens","content":[{"type":"thinking","thinking":"Still working"}]}"#.utf8)

        let response = try GeminiService.parseAnthropicTextResponse(from: data)

        #expect(response.text == nil)
        #expect(response.wasTruncated)
    }
}
