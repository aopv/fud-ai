package com.apoorvdarshan.calorietracker.services

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DailySummaryPolicyTest {
    @Test
    fun `measured total burn wins over active plus bmr fallback`() {
        assertEquals(
            2_400,
            DailySummaryPolicy.resolveBurnedCalories(
                measuredTotalCalories = 2_400,
                externalActiveCalories = 500,
                profileBmrCalories = 1_700
            )
        )
    }

    @Test
    fun `active plus bmr is used when measured total is missing`() {
        assertEquals(
            2_200,
            DailySummaryPolicy.resolveBurnedCalories(
                measuredTotalCalories = null,
                externalActiveCalories = 500,
                profileBmrCalories = 1_700
            )
        )
    }

    @Test
    fun `missing measured and active burn keeps static summary fallback`() {
        assertNull(
            DailySummaryPolicy.resolveBurnedCalories(
                measuredTotalCalories = null,
                externalActiveCalories = 0,
                profileBmrCalories = 1_700
            )
        )
    }

    @Test
    fun `burn above intake is a deficit`() {
        val result = DailySummaryPolicy.balance(eatenCalories = 2_000, burnedCalories = 2_400)
        assertEquals(CalorieBalanceDirection.DEFICIT, result.direction)
        assertEquals(400, result.differenceCalories)
    }

    @Test
    fun `intake above burn is a surplus`() {
        val result = DailySummaryPolicy.balance(eatenCalories = 2_600, burnedCalories = 2_400)
        assertEquals(CalorieBalanceDirection.SURPLUS, result.direction)
        assertEquals(200, result.differenceCalories)
    }

    @Test
    fun `equal intake and burn is balanced`() {
        val result = DailySummaryPolicy.balance(eatenCalories = 2_400, burnedCalories = 2_400)
        assertEquals(CalorieBalanceDirection.BALANCED, result.direction)
        assertEquals(0, result.differenceCalories)
    }
}
