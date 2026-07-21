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

struct OpenAIResponseParsingTests {
    @Test func readsContentWithoutTreatingReasoningAsTheAnswer() throws {
        let data = Data(#"{"choices":[{"finish_reason":"stop","message":{"reasoning":"private analysis","content":"  {\"calories\":100}  "}}]}"#.utf8)

        let response = try GeminiService.parseOpenAITextResponse(from: data)

        #expect(response.text == #"{"calories":100}"#)
        #expect(response.hasReasoning)
        #expect(!response.wasTruncated)
    }

    @Test func requestsCompactRetryWhenReasoningUsesTheWholeResponse() throws {
        let data = Data(#"{"choices":[{"finish_reason":"stop","message":{"reasoning_details":[{"type":"reasoning.text","text":"working"}],"content":null}}]}"#.utf8)

        let response = try GeminiService.parseOpenAITextResponse(from: data)

        #expect(response.text == nil)
        #expect(response.needsCompactRetry)
    }

    @Test func reportsLengthFinishAsTruncationEvenWithPartialContent() throws {
        let data = Data(#"{"choices":[{"finish_reason":"length","message":{"content":"{\"calories\":"}}]}"#.utf8)

        let response = try GeminiService.parseOpenAITextResponse(from: data)

        #expect(response.wasTruncated)
        #expect(response.needsCompactRetry)
    }
}
