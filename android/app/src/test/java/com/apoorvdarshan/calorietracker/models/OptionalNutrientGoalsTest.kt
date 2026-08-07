package com.apoorvdarshan.calorietracker.models

import org.junit.Assert.assertEquals
import org.junit.Test

class OptionalNutrientGoalsTest {
    @Test
    fun customValueIsNotSnappedToPresetWheel() {
        val goals = OptionalNutrientGoals.Default.withValue(OptionalNutrient.VITAMIN_C, 17)

        assertEquals(17, goals.vitaminC)
    }

    @Test
    fun customValueUsesTechnicalBounds() {
        val tooHigh = OptionalNutrientGoals.Default.withValue(OptionalNutrient.VITAMIN_D, 1_000_000)
        val negative = OptionalNutrientGoals.Default.withValue(OptionalNutrient.IRON, -1)

        assertEquals(OptionalNutrientGoals.MaximumCustomGoal, tooHigh.vitaminD)
        assertEquals(0, negative.iron)
    }
}
