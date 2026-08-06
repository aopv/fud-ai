package com.apoorvdarshan.calorietracker.ui.home

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ManualEntryInputTest {
    @Test
    fun blankValueRemainsUnknown() {
        assertNull(parseOptionalManualNutritionValue(""))
    }

    @Test
    fun decimalValueIsParsed() {
        assertEquals(7.5, parseOptionalManualNutritionValue("7.5")!!, 0.0)
        assertEquals(7.5, parseOptionalManualNutritionValue("7,5")!!, 0.0)
    }

    @Test
    fun negativeAndInvalidValuesAreRejected() {
        assertNull(parseOptionalManualNutritionValue("-1"))
        assertNull(parseOptionalManualNutritionValue("fiber"))
    }
}
