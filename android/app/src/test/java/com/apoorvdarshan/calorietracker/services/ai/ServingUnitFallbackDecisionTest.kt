package com.apoorvdarshan.calorietracker.services.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ServingUnitFallbackDecisionTest {
    @Test
    fun validNonemptyObjectArrayDoesNotRequestFallback() {
        val result = parse("""[{"unit":"slice","quantity":2.0,"grams_per_unit":60.0}]""")

        assertFalse(result.shouldRequestFallback)
        assertEquals(1, result.options.size)
        assertEquals("slice", result.options.single().unit)
        assertEquals(2.0, result.options.single().quantity ?: 0.0, 0.0)
        assertEquals(60.0, result.options.single().gramsPerUnit, 0.0)
    }

    @Test
    fun validEmptyArrayDoesNotRequestFallback() {
        val result = parse("[]")

        assertFalse(result.shouldRequestFallback)
        assertTrue(result.options.isEmpty())
    }

    @Test
    fun legacyServingUnitOptionsAliasRemainsValid() {
        val result = FoodJsonParser.parseServingUnitOptionsResult(
            text = """{"serving_unit_options":[{"unit":"slice","quantity":2.0,"grams_per_unit":60.0}]}""",
            servingSizeGrams = 120.0
        )

        assertFalse(result.shouldRequestFallback)
        assertEquals("slice", result.options.single().unit)
    }

    @Test
    fun legacyCamelCaseGramsPerUnitRemainsValid() {
        val result = parse("""[{"unit":"slice","quantity":2.0,"gramsPerUnit":60.0}]""")

        assertFalse(result.shouldRequestFallback)
        assertEquals(60.0, result.options.single().gramsPerUnit, 0.0)
    }

    @Test
    fun stringArrayRequestsFallback() {
        val result = parse("""["slice"]""")

        assertTrue(result.shouldRequestFallback)
        assertTrue(result.options.isEmpty())
    }

    @Test
    fun missingFieldRequestsFallback() {
        val result = FoodJsonParser.parseServingUnitOptionsResult(
            text = """{"name":"Pizza","serving_size_grams":120.0}""",
            servingSizeGrams = 120.0
        )

        assertTrue(result.shouldRequestFallback)
        assertTrue(result.options.isEmpty())
    }

    @Test
    fun objectMissingRequiredFieldRequestsFallback() {
        val result = parse("""[{"unit":"slice","grams_per_unit":60.0}]""")

        assertTrue(result.shouldRequestFallback)
        assertTrue(result.options.isEmpty())
    }

    @Test
    fun objectInconsistentWithServingWeightRequestsFallback() {
        val result = parse("""[{"unit":"slice","quantity":2.0,"grams_per_unit":40.0}]""")

        assertTrue(result.shouldRequestFallback)
        assertTrue(result.options.isEmpty())
    }

    private fun parse(unitOptions: String): ServingUnitOptionsParseResult =
        FoodJsonParser.parseServingUnitOptionsResult(
            text = """{"name":"Pizza","serving_size_grams":120.0,"unit_options":$unitOptions}""",
            servingSizeGrams = 120.0
        )
}
