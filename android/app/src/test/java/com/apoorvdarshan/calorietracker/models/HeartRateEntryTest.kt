package com.apoorvdarshan.calorietracker.models

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class HeartRateEntryTest {
    @Test
    fun serializesEveryPersistedFieldWithoutRawSignalData() {
        val original = HeartRateEntry(
            date = Instant.parse("2026-08-31T06:30:00Z"),
            bpm = 72,
            source = HeartRateSource.CAMERA,
            quality = 0.91
        )

        val encoded = Json.encodeToString(original)
        val decoded = Json.decodeFromString<HeartRateEntry>(encoded)

        assertEquals(original, decoded)
        assertEquals(setOf("id", "date", "bpm", "source", "quality"),
            Json.parseToJsonElement(encoded).jsonObject.keys)
    }

    @Test
    fun manualEntryLeavesQualityAbsent() {
        val entry = HeartRateEntry(bpm = 68, source = HeartRateSource.MANUAL)
        assertNull(entry.quality)
    }

    @Test
    fun manualPersistenceBoundsMatchThirtyToTwoHundredFifty() {
        assertTrue(HeartRateEntry(bpm = 30, source = HeartRateSource.MANUAL).isValid)
        assertTrue(HeartRateEntry(bpm = 250, source = HeartRateSource.MANUAL).isValid)
        assertFalse(HeartRateEntry(bpm = 29, source = HeartRateSource.MANUAL).isValid)
        assertFalse(HeartRateEntry(bpm = 251, source = HeartRateSource.MANUAL).isValid)
    }
}
