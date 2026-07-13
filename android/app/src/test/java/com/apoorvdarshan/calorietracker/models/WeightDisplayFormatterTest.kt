package com.apoorvdarshan.calorietracker.models

import org.junit.Assert.assertEquals
import org.junit.Test

class WeightDisplayFormatterTest {
    @Test
    fun metricWeeklyChangesUseStoredKilogramValuesWithoutTrailingZeros() {
        assertEquals("0.25", WeightDisplayFormatter.weeklyChangeValue(0.25, useMetric = true))
        assertEquals("0.5", WeightDisplayFormatter.weeklyChangeValue(0.5, useMetric = true))
        assertEquals("1", WeightDisplayFormatter.weeklyChangeValue(1.0, useMetric = true))
    }

    @Test
    fun imperialWeeklyChangesConvertAndRoundToTwoDecimalPlaces() {
        assertEquals("0.55", WeightDisplayFormatter.weeklyChangeValue(0.25, useMetric = false))
        assertEquals("1.1", WeightDisplayFormatter.weeklyChangeValue(0.5, useMetric = false))
        assertEquals("2.2", WeightDisplayFormatter.weeklyChangeValue(1.0, useMetric = false))
    }
}
