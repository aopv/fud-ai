package com.apoorvdarshan.calorietracker.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UserProfileGoalFormulaTest {
    @Test
    fun knownBodyFatAlwaysUsesKatchEvenWithLegacyFalsePreference() {
        val base = UserProfile(weightKg = 80.0, heightCm = 180.0, bodyFatPercentage = 0.20)

        assertTrue(base.copy(useBodyFatInBMR = null).usesBodyFatForBMR)
        assertTrue(base.copy(useBodyFatInBMR = true).usesBodyFatForBMR)
        assertTrue(base.copy(useBodyFatInBMR = false).usesBodyFatForBMR)
        assertEquals(
            370.0 + 21.6 * 0.8 * 80.0,
            base.copy(useBodyFatInBMR = false).bmr,
            0.001
        )
    }

    @Test
    fun proteinActivityRatesAreFullBodyweightEquivalents() {
        val withBodyFat = UserProfile(
            weightKg = 100.0,
            bodyFatPercentage = 0.30,
            activityLevel = ActivityLevel.MODERATE,
            goal = WeightGoal.LOSE
        )
        val withoutBodyFat = withBodyFat.copy(bodyFatPercentage = null)

        assertEquals(180, withBodyFat.proteinGoal)
        assertEquals(withoutBodyFat.proteinGoal, withBodyFat.proteinGoal)
    }

    @Test
    fun weeklyCalorieAdjustmentUses7700KcalPerKilogram() {
        assertEquals(-550, UserProfile(goal = WeightGoal.LOSE, weeklyChangeKg = 0.5).calorieAdjustment)
        assertEquals(550, UserProfile(goal = WeightGoal.GAIN, weeklyChangeKg = 0.5).calorieAdjustment)
    }
}
