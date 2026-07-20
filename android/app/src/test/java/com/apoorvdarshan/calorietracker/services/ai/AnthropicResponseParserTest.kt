package com.apoorvdarshan.calorietracker.services.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AnthropicResponseParserTest {
    @Test
    fun findsTextAfterReasoningBlock() {
        val response = AnthropicResponseParser.parse(
            """{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":"Checking nutrients"},{"type":"text","text":"  {\"name\":\"Apple\"}  "}]}"""
        )

        assertEquals("{\"name\":\"Apple\"}", response.text)
        assertFalse(response.wasTruncated)
    }

    @Test
    fun reportsTruncationEvenWhenNoTextBlockExists() {
        val response = AnthropicResponseParser.parse(
            """{"stop_reason":"max_tokens","content":[{"type":"thinking","thinking":"Still working"}]}"""
        )

        assertNull(response.text)
        assertTrue(response.wasTruncated)
    }
}
