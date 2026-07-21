package com.apoorvdarshan.calorietracker.services.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenAIResponseParserTest {
    @Test
    fun readsContentWithoutTreatingReasoningAsTheAnswer() {
        val response = OpenAIResponseParser.parse(
            """{"choices":[{"finish_reason":"stop","message":{"reasoning":"private analysis","content":"  {\"calories\":100}  "}}]}"""
        )

        assertEquals("{\"calories\":100}", response.text)
        assertTrue(response.hasReasoning)
        assertFalse(response.wasTruncated)
    }

    @Test
    fun requestsCompactRetryWhenReasoningUsesTheWholeResponse() {
        val response = OpenAIResponseParser.parse(
            """{"choices":[{"finish_reason":"stop","message":{"reasoning_details":[{"type":"reasoning.text","text":"working"}],"content":null}}]}"""
        )

        assertNull(response.text)
        assertTrue(response.needsCompactRetry)
    }

    @Test
    fun reportsLengthFinishAsTruncationEvenWithPartialContent() {
        val response = OpenAIResponseParser.parse(
            """{"choices":[{"finish_reason":"length","message":{"content":"{\"calories\":"}}]}"""
        )

        assertTrue(response.wasTruncated)
        assertTrue(response.needsCompactRetry)
    }
}
