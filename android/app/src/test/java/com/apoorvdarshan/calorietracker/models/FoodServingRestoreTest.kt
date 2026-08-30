package com.apoorvdarshan.calorietracker.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class FoodServingRestoreTest {
    @Test
    fun unknownServingUsesOneServingWithoutInventingGrams() {
        val entry = FoodEntry(
            name = "Recovered meal",
            calories = 420,
            protein = 30.0,
            carbs = 45.0,
            fat = 12.0,
            source = FoodSource.MANUAL
        )

        assertFalse(entry.hasKnownServingSize)
        assertEquals(1.0, entry.reviewServingReference, 0.0)
        assertEquals("serving", entry.reviewSelectedServingUnit)
        assertEquals(1.0, entry.reviewSelectedServingQuantity!!, 0.0)
        assertEquals(listOf(ServingUnitOption.loggedServing()), entry.reviewServingUnitOptions)

        val duplicate = entry.duplicatedForLogging(Instant.parse("2026-08-30T12:00:00Z"))
        assertNull(duplicate.servingSizeGrams)
    }

    @Test
    fun knownServingKeepsExactAmountAndUnit() {
        val option = ServingUnitOption(unit = "slice", gramsPerUnit = 60.0, quantity = 2.0)
        val entry = FoodEntry(
            name = "Pizza",
            calories = 480,
            protein = 20.0,
            carbs = 64.0,
            fat = 16.0,
            source = FoodSource.MANUAL,
            servingSizeGrams = 120.0,
            servingUnitOptions = listOf(option),
            selectedServingUnit = "slice",
            selectedServingQuantity = 2.0
        )

        assertTrue(entry.hasKnownServingSize)
        assertEquals(120.0, entry.reviewServingReference, 0.0)
        assertEquals(listOf(option), entry.reviewServingUnitOptions)
        assertEquals("slice", entry.reviewSelectedServingUnit)
        assertEquals(2.0, entry.reviewSelectedServingQuantity!!, 0.0)
    }

}
